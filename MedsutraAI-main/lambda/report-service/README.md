# ReportService Lambda Function

## Overview

The ReportService Lambda function handles medical report file uploads, validation, S3 storage with KMS encryption, and OCR processing using Amazon Textract for scanned images and PDFs.

## Features

- ✅ File upload with validation (format and size)
- ✅ Support for PDF, DOCX, DICOM, JPG, PNG formats
- ✅ Maximum file size: 50 MB
- ✅ S3 storage with KMS encryption
- ✅ Amazon Textract OCR for images and PDFs
- ✅ Report metadata storage in RDS PostgreSQL
- ✅ VPC-enabled for secure RDS access
- ✅ Comprehensive error handling and logging
- ✅ JWT authentication via API Gateway authorizer

## Requirements

- **Requirements**: 4.1, 4.2, 4.3, 4.4, 4.6, 18.1, 18.2, 18.3, 18.4, 22.2
- **Runtime**: Python 3.11
- **Timeout**: 5 minutes (300 seconds)
- **Memory**: 1024 MB
- **VPC**: Enabled (private subnets)

## API Endpoints

### POST /reports/upload

Upload a medical report file for a patient.

**Request Body:**
```json
{
  "patientId": "uuid or ABHA number",
  "fileName": "blood_test_results.pdf",
  "fileContent": "base64-encoded-file-content",
  "contentType": "application/pdf",
  "reportType": "lab",
  "reportTitle": "Blood Test Results",
  "reportDescription": "Complete blood count analysis",
  "reportDate": "2024-01-15"
}
```

**Request Fields:**
- `patientId` (string, required): Patient UUID or ABHA number
- `fileName` (string, required): Original file name with extension
- `fileContent` (string, required): Base64-encoded file content
- `contentType` (string, optional): MIME type of the file
- `reportType` (string, optional): Type of report (lab, radiology, prescription, clinical_note, dicom, other)
- `reportTitle` (string, optional): Human-readable title (defaults to fileName)
- `reportDescription` (string, optional): Description of the report
- `reportDate` (string, optional): Actual date of the medical report (ISO 8601 format)

**Response (200 OK):**
```json
{
  "message": "Report uploaded successfully",
  "reportId": "uuid",
  "patientId": "uuid",
  "fileName": "blood_test_results.pdf",
  "fileSize": 1048576,
  "fileFormat": "pdf",
  "s3Key": "medical-reports/patient-id/2024/01/15/uuid_filename.pdf",
  "ocrProcessed": true,
  "ocrConfidence": 95.5
}
```

**Error Responses:**
- `400 Bad Request`: Missing required fields, invalid file format, or file too large
- `500 Internal Server Error`: S3 upload error, database error, or OCR processing error

## Supported File Formats

| Format | Extension | MIME Type | OCR Support |
|--------|-----------|-----------|-------------|
| PDF | .pdf | application/pdf | ✅ Yes |
| DOCX | .docx | application/vnd.openxmlformats-officedocument.wordprocessingml.document | ❌ No |
| JPEG | .jpg, .jpeg | image/jpeg | ✅ Yes |
| PNG | .png | image/png | ✅ Yes |
| DICOM | .dicom | application/dicom | ❌ No |

**Maximum File Size**: 50 MB

## File Validation

The function performs the following validations:

1. **File Size**: Must be > 0 and ≤ 50 MB
2. **File Format**: Must be one of the supported formats
3. **File Extension**: Must match the content type (warning if mismatch)

## S3 Storage

Files are stored in S3 with the following structure:

```
s3://bucket-name/medical-reports/{patient-id}/{YYYY}/{MM}/{DD}/{uuid}_{filename}
```

**Security Features:**
- Server-side encryption with AWS KMS
- Versioning enabled
- Private bucket (no public access)
- Metadata includes patient ID, upload timestamp, and original filename

## OCR Processing

For supported formats (PDF, JPG, PNG), the function automatically:

1. Calls Amazon Textract `detect_document_text` API
2. Extracts text from all detected lines
3. Calculates average confidence score
4. Stores extracted text and confidence in database

**OCR Confidence Levels:**
- High: > 90%
- Medium: 70-90%
- Low: < 70%

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `DB_HOST` | RDS PostgreSQL hostname | Yes |
| `DB_PORT` | Database port (default: 5432) | No |
| `DB_NAME` | Database name | Yes |
| `DB_USER` | Database username | Yes |
| `DB_PASSWORD` | Database password | Yes |
| `DB_SSL_ENABLED` | Enable SSL for database connection | No |
| `S3_BUCKET` | S3 bucket name for medical documents | Yes |
| `KMS_KEY_ID` | KMS key ID for S3 encryption | Yes |
| `NODE_ENV` | Environment (development/production) | No |

## Development

### Install Dependencies

```bash
cd infrastructure/lambda/report-service
pip install -r requirements.txt
```

### Run Tests

```bash
# Run all tests
pytest

# Run tests with coverage
pytest --cov=lambda_function --cov-report=html

# Run specific test
pytest test_lambda_function.py::TestFileValidation::test_valid_pdf_file -v
```

### Package for Deployment

```bash
# Install dependencies in package directory
pip install -r requirements.txt -t package/

# Copy Lambda function
cp lambda_function.py package/

# Create deployment package
cd package
zip -r ../report-service.zip .
cd ..
```

## Deployment

The Lambda function is deployed via Terraform:

```bash
cd infrastructure/terraform
terraform apply
```

## Security

- **VPC**: Function runs in private subnets with no direct internet access
- **IAM**: Least privilege IAM role with S3, KMS, Textract, RDS, and CloudWatch permissions
- **Authentication**: JWT token validation via API Gateway authorizer
- **Encryption at Rest**: S3 objects encrypted with KMS
- **Encryption in Transit**: SSL/TLS for database and AWS API calls
- **Access Control**: S3 bucket policy restricts access to Lambda role only

## Performance

- **Target**: Process files within 5 seconds for <10MB files (Requirement 22.2)
- **Timeout**: 5 minutes (for large files and OCR processing)
- **Memory**: 1024 MB (sufficient for file processing and OCR)
- **OCR Processing Time**: Typically 2-10 seconds depending on document complexity

## Monitoring

- **CloudWatch Logs**: `/aws/lambda/{function-name}`
- **Metrics**: Invocations, errors, duration, throttles, memory usage
- **Alarms**: Configure CloudWatch alarms for:
  - Error rate > 5%
  - Duration > 30 seconds (for <10MB files)
  - Throttles > 0

## Testing

The function includes comprehensive unit tests covering:

- ✅ File validation (format, size, extension)
- ✅ S3 upload with KMS encryption
- ✅ OCR processing with Textract
- ✅ Database metadata creation
- ✅ End-to-end upload flow
- ✅ Error handling (missing fields, invalid formats, oversized files)

Run tests with: `pytest`

## Troubleshooting

### File Upload Fails with 400 Error

- Verify file is base64 encoded
- Check file size is ≤ 50 MB
- Ensure file extension is supported
- Validate patientId is provided

### OCR Not Processing

- Verify file format is PDF, JPG, or PNG
- Check Textract service limits and quotas
- Review CloudWatch Logs for Textract errors
- Ensure Lambda has Textract IAM permissions

### S3 Upload Fails

- Verify S3 bucket exists and is accessible
- Check KMS key permissions
- Ensure Lambda has S3 PutObject permissions
- Review CloudWatch Logs for detailed error

### Database Connection Timeout

- Verify Lambda is in correct VPC subnets
- Check security group allows Lambda → RDS traffic
- Verify RDS endpoint is correct
- Ensure database credentials are valid

## Related Documentation

- [Database Schema](../../database/SCHEMA_REFERENCE.md)
- [API Gateway Configuration](../../terraform/api_gateway.tf)
- [S3 Configuration](../../terraform/s3.tf)
- [KMS Configuration](../../terraform/kms.tf)
- [JWT Authorizer](../authorizer/README.md)
