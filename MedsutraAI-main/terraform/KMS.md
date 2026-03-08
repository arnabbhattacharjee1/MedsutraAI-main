# AWS KMS Encryption Configuration

## Overview

This document describes the AWS Key Management Service (KMS) configuration for the AI Cancer Detection and Clinical Summarization platform. The KMS setup implements customer-managed encryption keys for protecting Protected Health Information (PHI) at rest across multiple AWS services.

## Architecture

### Encryption Keys

The platform uses three separate customer-managed KMS keys, each dedicated to a specific service and data classification:

1. **S3 Encryption Key** - Medical documents and reports
2. **RDS Encryption Key** - Patient records and metadata
3. **DynamoDB Encryption Key** - Session state and real-time agent status

### Key Separation Rationale

Separate keys provide:
- **Granular access control**: Different services and roles can access only the keys they need
- **Compliance**: Meets HIPAA and DPDP Act requirements for data segregation
- **Audit trail**: Separate CloudTrail logs for each key enable precise tracking
- **Blast radius limitation**: Compromise of one key doesn't affect other data stores

## Key Configuration

### Common Settings

All KMS keys share these security configurations:

- **Automatic Key Rotation**: Enabled (annual rotation)
- **Deletion Window**: 30 days (prevents accidental deletion)
- **Key Type**: Symmetric (AES-256-GCM)
- **Key Usage**: Encrypt and Decrypt
- **Multi-Region**: No (single region deployment in ap-south-1)

### S3 Encryption Key

**Purpose**: Encrypts medical documents, lab reports, radiology images, and uploaded files stored in S3 buckets.

**Data Classification**: PHI (Protected Health Information)

**Authorized Services**:
- Amazon S3 (primary service)
- Amazon CloudFront (for serving encrypted content)

**Key Policy Highlights**:
- Restricts key usage to S3 service in the deployment region
- Allows CloudFront to decrypt objects for content delivery
- Grants root account full administrative access
- Supports S3 bucket key for cost optimization

**Use Cases**:
- Medical document storage
- DICOM image encryption
- PDF/DOCX report encryption
- OCR-processed scanned images

### RDS Encryption Key

**Purpose**: Encrypts PostgreSQL database containing patient records, clinical summaries, and structured medical data.

**Data Classification**: PHI (Protected Health Information)

**Authorized Services**:
- Amazon RDS (primary service)
- RDS Enhanced Monitoring

**Key Policy Highlights**:
- Restricts key usage to RDS service in the deployment region
- Allows RDS to create grants for automated operations
- Supports RDS Enhanced Monitoring for performance metrics
- Enables encryption of automated backups and snapshots

**Use Cases**:
- Patient metadata encryption
- Clinical summary storage
- User authentication data
- Audit log encryption
- Database snapshots and backups

### DynamoDB Encryption Key

**Purpose**: Encrypts DynamoDB tables storing session state, agent status, and real-time application data.

**Data Classification**: Session-Data (contains user session information)

**Authorized Services**:
- Amazon DynamoDB (primary service)
- DynamoDB Streams

**Key Policy Highlights**:
- Restricts key usage to DynamoDB service in the deployment region
- Allows DynamoDB to create grants for table operations
- Supports DynamoDB Streams for change data capture
- Enables encryption of point-in-time recovery backups

**Use Cases**:
- User session state
- AI agent status tracking
- Real-time dashboard updates
- WebSocket connection state
- Temporary cache data

## Key Policies

### Policy Structure

Each KMS key has a resource-based policy with three main statement types:

1. **Root Account Permissions**: Full administrative access for key management
2. **Service Permissions**: Specific permissions for authorized AWS services
3. **Conditional Access**: Region-based restrictions using `kms:ViaService` condition

### Security Principles

- **Least Privilege**: Services receive only the minimum required permissions
- **Service Isolation**: Keys are accessible only via specific AWS services
- **Regional Restriction**: Keys can only be used within the deployment region
- **No Cross-Account Access**: Keys are restricted to the current AWS account

## Key Rotation

### Automatic Rotation

All KMS keys have automatic rotation enabled:

- **Rotation Frequency**: Annual (365 days)
- **Rotation Method**: AWS-managed (transparent to applications)
- **Key Material**: New cryptographic material generated automatically
- **Backward Compatibility**: Old key material retained for decryption

### Rotation Impact

- **Zero Downtime**: Rotation occurs without service interruption
- **Transparent**: Applications continue using the same key ID/ARN
- **Automatic Re-encryption**: Not required (AWS handles key versioning)
- **Audit Trail**: Rotation events logged in CloudTrail

### Manual Rotation

Manual rotation is not required but can be performed if needed:

1. Create a new KMS key
2. Update application configurations to use the new key
3. Re-encrypt existing data with the new key
4. Schedule deletion of the old key after verification

## Key Aliases

Each KMS key has a human-readable alias for easier reference:

- `alias/ai-cancer-detection-s3-encryption`
- `alias/ai-cancer-detection-rds-encryption`
- `alias/ai-cancer-detection-dynamodb-encryption`

**Benefits**:
- Easier to reference in IAM policies and application code
- Can be updated to point to different keys without changing references
- Improves readability in CloudTrail logs

## Compliance

### DPDP Act (India)

The KMS configuration supports DPDP Act compliance:

- **Encryption at Rest**: All PHI is encrypted using customer-managed keys
- **Access Control**: Key policies restrict access to authorized services only
- **Audit Trail**: All key usage is logged in CloudTrail
- **Data Residency**: Keys and data remain in ap-south-1 (Mumbai) region

### HIPAA Readiness

The KMS configuration aligns with HIPAA requirements:

- **Encryption**: Meets HIPAA encryption standards (AES-256)
- **Key Management**: Customer-managed keys provide control over encryption
- **Access Logging**: CloudTrail logs all key access for audit purposes
- **Key Rotation**: Annual rotation meets HIPAA best practices

### ABDM Alignment

The KMS setup supports ABDM (Ayushman Bharat Digital Mission) guidelines:

- **Data Security**: Encryption protects patient data in the national health ecosystem
- **Regional Deployment**: Keys in ap-south-1 support India-based data storage
- **Interoperability**: Keys can be used with ABDM-compliant services

## Monitoring and Auditing

### CloudTrail Integration

All KMS key operations are logged in AWS CloudTrail:

- Key creation and deletion
- Key policy changes
- Encryption and decryption operations
- Grant creation and revocation
- Key rotation events

### CloudWatch Metrics

Monitor KMS key usage with CloudWatch:

- `NumberOfDecryptOperations`: Track decryption requests
- `NumberOfEncryptOperations`: Track encryption requests
- `KeyAge`: Monitor key age for rotation planning
- `KeyState`: Alert on key state changes

### Recommended Alarms

Set up CloudWatch alarms for:

- Unusual spike in decryption operations (potential breach)
- Key deletion attempts (security incident)
- Key policy modifications (unauthorized changes)
- Failed decryption attempts (access issues)

## Cost Optimization

### Key Pricing

- **Key Storage**: $1/month per customer-managed key
- **API Requests**: $0.03 per 10,000 requests
- **Total Monthly Cost**: ~$3 for three keys (plus API usage)

### Cost Reduction Strategies

1. **S3 Bucket Keys**: Reduce S3 encryption costs by 99%
2. **Caching**: Cache decrypted data in application layer
3. **Batch Operations**: Combine multiple operations where possible
4. **Data Key Reuse**: Reuse data keys for multiple objects

## Deployment

### Prerequisites

- AWS account with KMS permissions
- Terraform >= 1.5.0
- AWS provider >= 5.0

### Deployment Steps

1. **Initialize Terraform**:
   ```bash
   terraform init
   ```

2. **Validate Configuration**:
   ```bash
   terraform validate
   ./test_kms.sh
   ```

3. **Plan Deployment**:
   ```bash
   terraform plan
   ```

4. **Apply Configuration**:
   ```bash
   terraform apply
   ```

5. **Verify Key Creation**:
   ```bash
   aws kms list-keys --region ap-south-1
   aws kms describe-key --key-id <key-id>
   ```

### Outputs

After deployment, the following outputs are available:

- `kms_s3_key_id`: KMS key ID for S3 encryption
- `kms_s3_key_arn`: KMS key ARN for S3 encryption
- `kms_rds_key_id`: KMS key ID for RDS encryption
- `kms_rds_key_arn`: KMS key ARN for RDS encryption
- `kms_dynamodb_key_id`: KMS key ID for DynamoDB encryption
- `kms_dynamodb_key_arn`: KMS key ARN for DynamoDB encryption

## Usage Examples

### S3 Bucket Encryption

```hcl
resource "aws_s3_bucket" "medical_documents" {
  bucket = "ai-cancer-detection-medical-docs"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "medical_documents" {
  bucket = aws_s3_bucket.medical_documents.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3_encryption.arn
    }
    bucket_key_enabled = true
  }
}
```

### RDS Instance Encryption

```hcl
resource "aws_db_instance" "patient_records" {
  identifier     = "ai-cancer-detection-db"
  engine         = "postgres"
  engine_version = "15.4"
  
  storage_encrypted = true
  kms_key_id       = aws_kms_key.rds_encryption.arn
  
  # Other configuration...
}
```

### DynamoDB Table Encryption

```hcl
resource "aws_dynamodb_table" "session_state" {
  name         = "ai-cancer-detection-sessions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "session_id"
  
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb_encryption.arn
  }
  
  # Other configuration...
}
```

## Troubleshooting

### Common Issues

**Issue**: "Access Denied" when encrypting/decrypting data

**Solution**: Verify the service has permissions in the key policy and is accessing via the correct region.

**Issue**: Key rotation not occurring

**Solution**: Check that `enable_key_rotation = true` is set and the key is at least 365 days old.

**Issue**: High KMS API costs

**Solution**: Enable S3 bucket keys and implement application-level caching.

### Validation Commands

```bash
# Check key rotation status
aws kms get-key-rotation-status --key-id <key-id>

# View key policy
aws kms get-key-policy --key-id <key-id> --policy-name default

# List key aliases
aws kms list-aliases --region ap-south-1

# Describe key
aws kms describe-key --key-id <key-id>
```

## Security Best Practices

1. **Never Disable Encryption**: Always use KMS keys for sensitive data
2. **Monitor Key Usage**: Set up CloudWatch alarms for unusual activity
3. **Regular Audits**: Review key policies and access patterns quarterly
4. **Least Privilege**: Grant minimum required permissions in key policies
5. **Enable Rotation**: Always enable automatic key rotation
6. **Backup Key Policies**: Store key policy backups in version control
7. **Test Disaster Recovery**: Regularly test key recovery procedures

## References

- [AWS KMS Best Practices](https://docs.aws.amazon.com/kms/latest/developerguide/best-practices.html)
- [HIPAA Compliance on AWS](https://aws.amazon.com/compliance/hipaa-compliance/)
- [DPDP Act Guidelines](https://www.meity.gov.in/writereaddata/files/Digital%20Personal%20Data%20Protection%20Act%202023.pdf)
- [ABDM Technical Standards](https://abdm.gov.in/)
