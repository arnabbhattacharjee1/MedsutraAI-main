# PatientService Lambda Function

## Overview

The PatientService Lambda function fetches patient records from RDS PostgreSQL database. It supports both UUID-based patient IDs and ABDM-compliant ABHA numbers for patient identification.

## Features

- ✅ Fetch patient records by UUID or ABHA number
- ✅ ABHA number validation (format: XX-XXXX-XXXX-XXXX)
- ✅ Patient statistics (report count, latest summary, latest assessment)
- ✅ VPC-enabled for secure RDS access
- ✅ Comprehensive error handling and logging
- ✅ JWT authentication via API Gateway authorizer

## Requirements

- **Requirements**: 2.6, 14.1, 14.4, 22.1
- **Runtime**: Node.js 20.x
- **Timeout**: 30 seconds
- **Memory**: 512 MB
- **VPC**: Enabled (private subnets)

## API Endpoints

### GET /patients/{patientId}

Fetch patient details by patient ID (UUID) or ABHA number.

**Path Parameters:**
- `patientId` (string, required): Patient UUID or ABHA number

**Response (200 OK):**
```json
{
  "patient": {
    "patientId": "uuid",
    "abhaNumber": "12-3456-7890-1234",
    "name": "John Doe",
    "dateOfBirth": "1980-01-15",
    "gender": "Male",
    "phoneNumber": "+91-9876543210",
    "email": "john.doe@example.com",
    "address": "123 Main St, Mumbai",
    "emergencyContact": {
      "name": "Jane Doe",
      "phone": "+91-9876543211"
    },
    "createdAt": "2024-01-01T00:00:00Z",
    "updatedAt": "2024-01-01T00:00:00Z"
  },
  "statistics": {
    "reportCount": 5,
    "hasLatestSummary": true,
    "hasLatestAssessment": true
  },
  "latestSummary": {
    "summary_id": "uuid",
    "language": "en",
    "persona": "healthcare_provider",
    "generation_timestamp": "2024-01-10T00:00:00Z",
    "confidence_score": 85.5,
    "review_status": "pending"
  },
  "latestAssessment": {
    "assessment_id": "uuid",
    "overall_risk_level": "medium",
    "risk_score": 45.2,
    "assessment_timestamp": "2024-01-10T00:00:00Z",
    "confidence_level": "high",
    "review_status": "pending"
  }
}
```

**Error Responses:**
- `400 Bad Request`: Invalid ABHA number format
- `404 Not Found`: Patient not found
- `500 Internal Server Error`: Database error

## ABHA Number Validation

The function validates ABHA numbers according to ABDM standards:

**Valid Format**: `XX-XXXX-XXXX-XXXX`
- 14 digits total
- Separated by hyphens at positions 2, 6, and 10
- Only numeric characters

**Examples:**
- ✅ Valid: `12-3456-7890-1234`
- ❌ Invalid: `1234567890123` (no hyphens)
- ❌ Invalid: `AB-1234-5678-9012` (contains letters)

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `DB_HOST` | RDS PostgreSQL hostname | Yes |
| `DB_PORT` | Database port (default: 5432) | No |
| `DB_NAME` | Database name | Yes |
| `DB_USER` | Database username | Yes |
| `DB_PASSWORD` | Database password | Yes |
| `DB_SSL_ENABLED` | Enable SSL for database connection | No |
| `NODE_ENV` | Environment (development/production) | No |

## Development

### Install Dependencies

```bash
cd infrastructure/lambda/patient-service
npm install
```

### Run Tests

```bash
# Run all tests
npm test

# Run tests in watch mode
npm run test:watch

# Run tests with coverage
npm run test:coverage
```

### Package for Deployment

```bash
npm run package
```

This creates `patient-service.zip` ready for Lambda deployment.

## Deployment

The Lambda function is deployed via Terraform:

```bash
cd infrastructure/terraform
terraform apply
```

## Security

- **VPC**: Function runs in private subnets with no direct internet access
- **IAM**: Least privilege IAM role with RDS and CloudWatch permissions
- **Authentication**: JWT token validation via API Gateway authorizer
- **Encryption**: Database credentials encrypted at rest
- **SSL/TLS**: Encrypted database connections

## Performance

- **Target**: Retrieve patient records within 3 seconds (Requirement 22.1)
- **Timeout**: 30 seconds
- **Memory**: 512 MB
- **Connection Pooling**: Single connection per invocation (Lambda handles concurrency)

## Monitoring

- **CloudWatch Logs**: `/aws/lambda/{function-name}`
- **Metrics**: Invocations, errors, duration, throttles
- **Alarms**: Configure CloudWatch alarms for error rates and latency

## Testing

The function includes comprehensive unit tests covering:

- ✅ Valid patient UUID retrieval
- ✅ Valid ABHA number retrieval
- ✅ Invalid patient ID handling
- ✅ ABHA number format validation
- ✅ Database connection errors
- ✅ Database query errors
- ✅ Route handling

Run tests with: `npm test`

## Troubleshooting

### Database Connection Timeout

- Verify Lambda is in correct VPC subnets
- Check security group allows Lambda → RDS traffic
- Verify RDS endpoint is correct

### ABHA Number Not Found

- Ensure ABHA number is in correct format: `XX-XXXX-XXXX-XXXX`
- Check patient exists in database with `is_active = true`

### 500 Internal Server Error

- Check CloudWatch Logs for detailed error messages
- Verify database credentials are correct
- Ensure RDS instance is running and accessible

## Related Documentation

- [Database Schema](../../database/SCHEMA_REFERENCE.md)
- [API Gateway Configuration](../../terraform/api_gateway.tf)
- [JWT Authorizer](../authorizer/README.md)
