/**
 * PatientService Lambda Function
 * Task 4.3: Implement PatientService Lambda (Node.js 20)
 * 
 * Fetches patient records from RDS PostgreSQL
 * Validates ABHA numbers (ABDM compliance)
 * 
 * Requirements:
 * - 2.6: Patient ID entry and retrieval
 * - 14.1: ABDM-compliant patient identification
 * - 14.4: ABHA number support
 * - 22.1: Retrieve patient records within 3 seconds
 */

const { Client } = require('pg');

// Environment variables
const DB_HOST = process.env.DB_HOST;
const DB_PORT = process.env.DB_PORT || 5432;
const DB_NAME = process.env.DB_NAME;
const DB_USER = process.env.DB_USER;
const DB_PASSWORD = process.env.DB_PASSWORD;
const DB_SSL_ENABLED = process.env.DB_SSL_ENABLED === 'true';

/**
 * Validate ABHA number format
 * Format: XX-XXXX-XXXX-XXXX (14 digits with hyphens)
 */
function validateAbhaNumber(abhaNumber) {
  if (!abhaNumber) {
    return { valid: false, error: 'ABHA number is required' };
  }

  const abhaRegex = /^\d{2}-\d{4}-\d{4}-\d{4}$/;
  if (!abhaRegex.test(abhaNumber)) {
    return {
      valid: false,
      error: 'Invalid ABHA number format. Expected: XX-XXXX-XXXX-XXXX'
    };
  }

  return { valid: true };
}

/**
 * Validate UUID format
 */
function validateUuid(uuid) {
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  return uuidRegex.test(uuid);
}

/**
 * Create database client
 */
function createDbClient() {
  return new Client({
    host: DB_HOST,
    port: DB_PORT,
    database: DB_NAME,
    user: DB_USER,
    password: DB_PASSWORD,
    ssl: DB_SSL_ENABLED ? { rejectUnauthorized: true } : false,
    connectionTimeoutMillis: 5000,
    query_timeout: 10000,
  });
}

/**
 * Get patient by ID (UUID or ABHA number)
 */
async function getPatientById(patientId) {
  const client = createDbClient();

  try {
    await client.connect();
    console.log('Database connected successfully');

    let query;
    let params;

    // Check if patientId is UUID or ABHA number
    if (validateUuid(patientId)) {
      // Query by patient_id (UUID)
      query = `
        SELECT 
          patient_id,
          abha_number,
          patient_name,
          date_of_birth,
          gender,
          phone_number,
          email,
          address,
          emergency_contact_name,
          emergency_contact_phone,
          created_at,
          updated_at,
          is_active
        FROM patients
        WHERE patient_id = $1 AND is_active = true
      `;
      params = [patientId];
    } else {
      // Validate ABHA number format
      const validation = validateAbhaNumber(patientId);
      if (!validation.valid) {
        return {
          statusCode: 400,
          body: JSON.stringify({
            error: 'Invalid patient identifier',
            message: validation.error
          })
        };
      }

      // Query by ABHA number
      query = `
        SELECT 
          patient_id,
          abha_number,
          patient_name,
          date_of_birth,
          gender,
          phone_number,
          email,
          address,
          emergency_contact_name,
          emergency_contact_phone,
          created_at,
          updated_at,
          is_active
        FROM patients
        WHERE abha_number = $1 AND is_active = true
      `;
      params = [patientId];
    }

    const result = await client.query(query, params);

    if (result.rows.length === 0) {
      return {
        statusCode: 404,
        body: JSON.stringify({
          error: 'Patient not found',
          message: `No patient found with identifier: ${patientId}`
        })
      };
    }

    const patient = result.rows[0];

    // Get patient's reports count
    const reportsQuery = `
      SELECT COUNT(*) as report_count
      FROM reports
      WHERE patient_id = $1 AND is_deleted = false
    `;
    const reportsResult = await client.query(reportsQuery, [patient.patient_id]);
    const reportCount = parseInt(reportsResult.rows[0].report_count, 10);

    // Get latest clinical summary
    const summaryQuery = `
      SELECT 
        summary_id,
        language,
        persona,
        generation_timestamp,
        confidence_score,
        review_status
      FROM clinical_summaries
      WHERE patient_id = $1 AND is_active = true
      ORDER BY generation_timestamp DESC
      LIMIT 1
    `;
    const summaryResult = await client.query(summaryQuery, [patient.patient_id]);
    const latestSummary = summaryResult.rows.length > 0 ? summaryResult.rows[0] : null;

    // Get latest cancer risk assessment
    const assessmentQuery = `
      SELECT 
        assessment_id,
        overall_risk_level,
        risk_score,
        assessment_timestamp,
        confidence_level,
        review_status
      FROM cancer_risk_assessments
      WHERE patient_id = $1 AND is_active = true
      ORDER BY assessment_timestamp DESC
      LIMIT 1
    `;
    const assessmentResult = await client.query(assessmentQuery, [patient.patient_id]);
    const latestAssessment = assessmentResult.rows.length > 0 ? assessmentResult.rows[0] : null;

    console.log(`Patient retrieved successfully: ${patient.patient_id}`);

    return {
      statusCode: 200,
      body: JSON.stringify({
        patient: {
          patientId: patient.patient_id,
          abhaNumber: patient.abha_number,
          name: patient.patient_name,
          dateOfBirth: patient.date_of_birth,
          gender: patient.gender,
          phoneNumber: patient.phone_number,
          email: patient.email,
          address: patient.address,
          emergencyContact: {
            name: patient.emergency_contact_name,
            phone: patient.emergency_contact_phone
          },
          createdAt: patient.created_at,
          updatedAt: patient.updated_at
        },
        statistics: {
          reportCount,
          hasLatestSummary: latestSummary !== null,
          hasLatestAssessment: latestAssessment !== null
        },
        latestSummary,
        latestAssessment
      })
    };

  } catch (error) {
    console.error('Database error:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({
        error: 'Internal server error',
        message: 'Failed to retrieve patient data',
        details: process.env.NODE_ENV === 'development' ? error.message : undefined
      })
    };
  } finally {
    await client.end();
    console.log('Database connection closed');
  }
}

/**
 * Get patient reports
 */
async function getPatientReports(patientId, limit = 50, offset = 0) {
  const client = createDbClient();

  try {
    await client.connect();

    // Validate patient exists
    const patientCheck = await client.query(
      'SELECT patient_id FROM patients WHERE patient_id = $1 AND is_active = true',
      [patientId]
    );

    if (patientCheck.rows.length === 0) {
      return {
        statusCode: 404,
        body: JSON.stringify({
          error: 'Patient not found',
          message: `No patient found with ID: ${patientId}`
        })
      };
    }

    // Get reports
    const query = `
      SELECT 
        report_id,
        report_type,
        report_title,
        report_description,
        file_format,
        file_size_bytes,
        upload_date,
        report_date,
        uploaded_by,
        ocr_processed,
        ocr_confidence,
        metadata
      FROM reports
      WHERE patient_id = $1 AND is_deleted = false
      ORDER BY report_date DESC, upload_date DESC
      LIMIT $2 OFFSET $3
    `;

    const result = await client.query(query, [patientId, limit, offset]);

    // Get total count
    const countQuery = `
      SELECT COUNT(*) as total
      FROM reports
      WHERE patient_id = $1 AND is_deleted = false
    `;
    const countResult = await client.query(countQuery, [patientId]);
    const total = parseInt(countResult.rows[0].total, 10);

    console.log(`Retrieved ${result.rows.length} reports for patient: ${patientId}`);

    return {
      statusCode: 200,
      body: JSON.stringify({
        reports: result.rows.map(report => ({
          reportId: report.report_id,
          type: report.report_type,
          title: report.report_title,
          description: report.report_description,
          fileFormat: report.file_format,
          fileSizeBytes: report.file_size_bytes,
          uploadDate: report.upload_date,
          reportDate: report.report_date,
          uploadedBy: report.uploaded_by,
          ocrProcessed: report.ocr_processed,
          ocrConfidence: report.ocr_confidence,
          metadata: report.metadata
        })),
        pagination: {
          total,
          limit,
          offset,
          hasMore: offset + result.rows.length < total
        }
      })
    };

  } catch (error) {
    console.error('Database error:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({
        error: 'Internal server error',
        message: 'Failed to retrieve patient reports',
        details: process.env.NODE_ENV === 'development' ? error.message : undefined
      })
    };
  } finally {
    await client.end();
  }
}

/**
 * Lambda handler
 */
exports.handler = async (event) => {
  console.log('Event:', JSON.stringify(event, null, 2));

  // Extract user context from authorizer
  const userId = event.requestContext?.authorizer?.userId;
  const userGroups = event.requestContext?.authorizer?.groups 
    ? JSON.parse(event.requestContext.authorizer.groups) 
    : [];

  console.log('User context:', { userId, userGroups });

  // Parse path and method
  const path = event.path || event.resource;
  const method = event.httpMethod;
  const pathParameters = event.pathParameters || {};
  const queryParameters = event.queryStringParameters || {};

  try {
    // Route: GET /patients/{patientId}
    if (method === 'GET' && path.includes('/patients/') && pathParameters.patientId) {
      const patientId = pathParameters.patientId;
      return await getPatientById(patientId);
    }

    // Route: GET /patients/{patientId}/reports
    if (method === 'GET' && path.includes('/patients/') && path.includes('/reports')) {
      const patientId = pathParameters.patientId;
      const limit = parseInt(queryParameters.limit || '50', 10);
      const offset = parseInt(queryParameters.offset || '0', 10);
      return await getPatientReports(patientId, limit, offset);
    }

    // Route not found
    return {
      statusCode: 404,
      body: JSON.stringify({
        error: 'Not found',
        message: `Route not found: ${method} ${path}`
      })
    };

  } catch (error) {
    console.error('Handler error:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({
        error: 'Internal server error',
        message: 'An unexpected error occurred',
        details: process.env.NODE_ENV === 'development' ? error.message : undefined
      })
    };
  }
};
