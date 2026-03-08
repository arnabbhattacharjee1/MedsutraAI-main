/**
 * Unit Tests for PatientService Lambda
 * Task 4.7: Write unit tests for Lambda functions
 */

// Mock pg module before importing the handler
const mockQuery = jest.fn();
const mockConnect = jest.fn();
const mockEnd = jest.fn();

jest.mock('pg', () => ({
  Client: jest.fn(() => ({
    connect: mockConnect,
    query: mockQuery,
    end: mockEnd
  }))
}));

const { handler } = require('./index');

describe('PatientService Lambda', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    
    // Set environment variables
    process.env.DB_HOST = 'test-db-host';
    process.env.DB_PORT = '5432';
    process.env.DB_NAME = 'test_db';
    process.env.DB_USER = 'test_user';
    process.env.DB_PASSWORD = 'test_password';
    process.env.DB_SSL_ENABLED = 'false';
    process.env.NODE_ENV = 'test';
  });

  afterEach(() => {
    jest.resetAllMocks();
  });

  describe('GET /patients/{patientId} - Valid UUID', () => {
    it('should return patient data for valid patient UUID', async () => {
      const patientId = '123e4567-e89b-12d3-a456-426614174000';
      
      // Mock database responses
      mockConnect.mockResolvedValue();
      mockQuery
        .mockResolvedValueOnce({
          // Patient query
          rows: [{
            patient_id: patientId,
            abha_number: '12-3456-7890-1234',
            patient_name: 'John Doe',
            date_of_birth: '1980-01-15',
            gender: 'Male',
            phone_number: '+91-9876543210',
            email: 'john.doe@example.com',
            address: '123 Main St, Mumbai',
            emergency_contact_name: 'Jane Doe',
            emergency_contact_phone: '+91-9876543211',
            created_at: '2024-01-01T00:00:00Z',
            updated_at: '2024-01-01T00:00:00Z',
            is_active: true
          }]
        })
        .mockResolvedValueOnce({
          // Reports count query
          rows: [{ report_count: '5' }]
        })
        .mockResolvedValueOnce({
          // Latest summary query
          rows: [{
            summary_id: '456e7890-e89b-12d3-a456-426614174001',
            language: 'en',
            persona: 'healthcare_provider',
            generation_timestamp: '2024-01-10T00:00:00Z',
            confidence_score: 85.5,
            review_status: 'pending'
          }]
        })
        .mockResolvedValueOnce({
          // Latest assessment query
          rows: [{
            assessment_id: '789e0123-e89b-12d3-a456-426614174002',
            overall_risk_level: 'medium',
            risk_score: 45.2,
            assessment_timestamp: '2024-01-10T00:00:00Z',
            confidence_level: 'high',
            review_status: 'pending'
          }]
        });
      mockEnd.mockResolvedValue();

      const event = {
        httpMethod: 'GET',
        path: `/patients/${patientId}`,
        pathParameters: { patientId },
        requestContext: {
          authorizer: {
            userId: 'user-123',
            groups: '["Doctor"]'
          }
        }
      };

      const response = await handler(event);

      expect(response.statusCode).toBe(200);
      const body = JSON.parse(response.body);
      expect(body.patient.patientId).toBe(patientId);
      expect(body.patient.name).toBe('John Doe');
      expect(body.patient.abhaNumber).toBe('12-3456-7890-1234');
      expect(body.statistics.reportCount).toBe(5);
      expect(body.latestSummary).toBeDefined();
      expect(body.latestAssessment).toBeDefined();
      
      expect(mockConnect).toHaveBeenCalledTimes(1);
      expect(mockQuery).toHaveBeenCalledTimes(4);
      expect(mockEnd).toHaveBeenCalledTimes(1);
    });

    it('should return 404 for non-existent patient UUID', async () => {
      const patientId = '123e4567-e89b-12d3-a456-426614174999';
      
      mockConnect.mockResolvedValue();
      mockQuery.mockResolvedValueOnce({
        rows: [] // No patient found
      });
      mockEnd.mockResolvedValue();

      const event = {
        httpMethod: 'GET',
        path: `/patients/${patientId}`,
        pathParameters: { patientId },
        requestContext: {
          authorizer: {
            userId: 'user-123',
            groups: '["Doctor"]'
          }
        }
      };

      const response = await handler(event);

      expect(response.statusCode).toBe(404);
      const body = JSON.parse(response.body);
      expect(body.error).toBe('Patient not found');
      expect(mockConnect).toHaveBeenCalledTimes(1);
      expect(mockEnd).toHaveBeenCalledTimes(1);
    });
  });

  describe('GET /patients/{patientId} - Valid ABHA Number', () => {
    it('should return patient data for valid ABHA number', async () => {
      const abhaNumber = '12-3456-7890-1234';
      const patientId = '123e4567-e89b-12d3-a456-426614174000';
      
      mockConnect.mockResolvedValue();
      mockQuery
        .mockResolvedValueOnce({
          // Patient query by ABHA
          rows: [{
            patient_id: patientId,
            abha_number: abhaNumber,
            patient_name: 'John Doe',
            date_of_birth: '1980-01-15',
            gender: 'Male',
            phone_number: '+91-9876543210',
            email: 'john.doe@example.com',
            address: '123 Main St, Mumbai',
            emergency_contact_name: 'Jane Doe',
            emergency_contact_phone: '+91-9876543211',
            created_at: '2024-01-01T00:00:00Z',
            updated_at: '2024-01-01T00:00:00Z',
            is_active: true
          }]
        })
        .mockResolvedValueOnce({
          rows: [{ report_count: '3' }]
        })
        .mockResolvedValueOnce({
          rows: []
        })
        .mockResolvedValueOnce({
          rows: []
        });
      mockEnd.mockResolvedValue();

      const event = {
        httpMethod: 'GET',
        path: `/patients/${abhaNumber}`,
        pathParameters: { patientId: abhaNumber },
        requestContext: {
          authorizer: {
            userId: 'user-123',
            groups: '["Doctor"]'
          }
        }
      };

      const response = await handler(event);

      expect(response.statusCode).toBe(200);
      const body = JSON.parse(response.body);
      expect(body.patient.abhaNumber).toBe(abhaNumber);
      expect(body.patient.name).toBe('John Doe');
      expect(body.statistics.reportCount).toBe(3);
    });

    it('should return 400 for invalid ABHA number format', async () => {
      const invalidAbha = '12345678901234'; // Missing hyphens
      
      const event = {
        httpMethod: 'GET',
        path: `/patients/${invalidAbha}`,
        pathParameters: { patientId: invalidAbha },
        requestContext: {
          authorizer: {
            userId: 'user-123',
            groups: '["Doctor"]'
          }
        }
      };

      const response = await handler(event);

      expect(response.statusCode).toBe(400);
      const body = JSON.parse(response.body);
      expect(body.error).toBe('Invalid patient identifier');
      expect(body.message).toContain('Invalid ABHA number format');
    });
  });

  describe('Database Error Handling', () => {
    it('should return 500 on database connection error', async () => {
      const patientId = '123e4567-e89b-12d3-a456-426614174000';
      
      mockConnect.mockRejectedValue(new Error('Connection timeout'));
      mockEnd.mockResolvedValue();

      const event = {
        httpMethod: 'GET',
        path: `/patients/${patientId}`,
        pathParameters: { patientId },
        requestContext: {
          authorizer: {
            userId: 'user-123',
            groups: '["Doctor"]'
          }
        }
      };

      const response = await handler(event);

      expect(response.statusCode).toBe(500);
      const body = JSON.parse(response.body);
      expect(body.error).toBe('Internal server error');
      expect(mockEnd).toHaveBeenCalledTimes(1);
    });

    it('should return 500 on database query error', async () => {
      const patientId = '123e4567-e89b-12d3-a456-426614174000';
      
      mockConnect.mockResolvedValue();
      mockQuery.mockRejectedValue(new Error('Query failed'));
      mockEnd.mockResolvedValue();

      const event = {
        httpMethod: 'GET',
        path: `/patients/${patientId}`,
        pathParameters: { patientId },
        requestContext: {
          authorizer: {
            userId: 'user-123',
            groups: '["Doctor"]'
          }
        }
      };

      const response = await handler(event);

      expect(response.statusCode).toBe(500);
      const body = JSON.parse(response.body);
      expect(body.error).toBe('Internal server error');
      expect(mockEnd).toHaveBeenCalledTimes(1);
    });
  });

  describe('Route Handling', () => {
    it('should return 404 for unknown route', async () => {
      const event = {
        httpMethod: 'GET',
        path: '/unknown/route',
        pathParameters: {},
        requestContext: {
          authorizer: {
            userId: 'user-123',
            groups: '["Doctor"]'
          }
        }
      };

      const response = await handler(event);

      expect(response.statusCode).toBe(404);
      const body = JSON.parse(response.body);
      expect(body.error).toBe('Not found');
    });
  });

  describe('ABHA Number Validation', () => {
    it('should accept valid ABHA number formats', async () => {
      const validAbhaNumbers = [
        '12-3456-7890-1234',
        '00-0000-0000-0000',
        '99-9999-9999-9999'
      ];

      for (const abha of validAbhaNumbers) {
        mockConnect.mockResolvedValue();
        mockQuery.mockResolvedValueOnce({
          rows: [{
            patient_id: '123e4567-e89b-12d3-a456-426614174000',
            abha_number: abha,
            patient_name: 'Test Patient',
            is_active: true
          }]
        })
        .mockResolvedValueOnce({ rows: [{ report_count: '0' }] })
        .mockResolvedValueOnce({ rows: [] })
        .mockResolvedValueOnce({ rows: [] });
        mockEnd.mockResolvedValue();

        const event = {
          httpMethod: 'GET',
          path: `/patients/${abha}`,
          pathParameters: { patientId: abha },
          requestContext: {
            authorizer: { userId: 'user-123', groups: '["Doctor"]' }
          }
        };

        const response = await handler(event);
        expect(response.statusCode).toBe(200);
        
        jest.clearAllMocks();
      }
    });

    it('should reject invalid ABHA number formats', async () => {
      const invalidAbhaNumbers = [
        '1234567890123',      // No hyphens
        '12-34-5678-901234',  // Wrong hyphen positions
        'AB-1234-5678-9012',  // Contains letters
        '12-3456-7890-123',   // Too short
        '12-3456-7890-12345', // Too long
        ''                    // Empty
      ];

      for (const abha of invalidAbhaNumbers) {
        const event = {
          httpMethod: 'GET',
          path: `/patients/${abha}`,
          pathParameters: { patientId: abha },
          requestContext: {
            authorizer: { userId: 'user-123', groups: '["Doctor"]' }
          }
        };

        const response = await handler(event);
        expect(response.statusCode).toBe(400);
        const body = JSON.parse(response.body);
        expect(body.error).toBe('Invalid patient identifier');
      }
    });
  });
});
