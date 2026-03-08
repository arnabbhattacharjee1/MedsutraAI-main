# Database Schema Documentation

## Overview

This directory contains the database schema, migration scripts, and deployment tools for the AI Cancer Detection and Clinical Summarization Platform. The database uses PostgreSQL 15 on Amazon RDS with encryption at rest and automated backups.

## Requirements Addressed

- **Requirement 2.6**: Patient identification and data storage
- **Requirement 12.6**: Audit logging for DPDP Act compliance
- **Requirement 14.1**: ABDM-compliant patient identification (ABHA number support)
- **Requirement 27.6**: 7-year audit log retention

## Database Schema

### Tables

#### 1. `patients`
Stores patient demographic and identification information with ABDM ABHA number support.

**Key Fields:**
- `patient_id` (UUID, Primary Key)
- `abha_number` (VARCHAR, UNIQUE) - ABDM-compliant format: XX-XXXX-XXXX-XXXX
- `patient_name`, `date_of_birth`, `gender`, `phone_number`, `email`
- `created_at`, `updated_at`, `is_active`

**Indexes:**
- `idx_patients_abha_number` - Fast lookup by ABHA number
- `idx_patients_phone`, `idx_patients_email` - Contact information lookup
- `idx_patients_created_at` - Temporal queries

#### 2. `reports`
Stores medical report metadata with S3 references for encrypted document storage.

**Key Fields:**
- `report_id` (UUID, Primary Key)
- `patient_id` (UUID, Foreign Key)
- `report_type` - lab, radiology, prescription, clinical_note, dicom, other
- `s3_bucket`, `s3_key`, `s3_version_id` - S3 storage references
- `file_format`, `file_size_bytes`
- `upload_date`, `report_date`
- `ocr_processed`, `ocr_text`, `ocr_confidence` - OCR extraction results
- `metadata` (JSONB) - Additional structured data

**Indexes:**
- `idx_reports_patient_id` - Patient's reports
- `idx_reports_upload_date`, `idx_reports_report_date` - Temporal queries
- `idx_reports_patient_upload` - Composite index for common queries
- `idx_reports_metadata_gin` - JSONB queries

#### 3. `clinical_summaries`
Stores AI-generated clinical summaries with multilingual and persona-based content.

**Key Fields:**
- `summary_id` (UUID, Primary Key)
- `patient_id` (UUID, Foreign Key)
- `summary_text` - Full summary content
- `language` - en, hi, ta, bn, mr, te (6 supported languages)
- `persona` - healthcare_provider or patient
- `chief_complaints`, `medical_history`, `current_medications`, `abnormal_findings`, `pending_actions`
- `ai_model_version`, `ai_model_name`
- `input_report_ids` (UUID[]) - Source reports
- `confidence_score`
- `review_status` - pending, approved, rejected, needs_revision

**Indexes:**
- `idx_summaries_patient_id` - Patient's summaries
- `idx_summaries_generation_timestamp` - Recent summaries
- `idx_summaries_language`, `idx_summaries_persona` - Filtering
- `idx_summaries_review_status` - Review workflow

#### 4. `cancer_risk_assessments`
Stores AI-generated cancer risk assessments with NLP classification results.

**Key Fields:**
- `assessment_id` (UUID, Primary Key)
- `patient_id` (UUID, Foreign Key)
- `summary_id` (UUID, Foreign Key, nullable)
- `overall_risk_level` - low, medium, high, critical
- `risk_score` (0-100)
- `cancer_types` (JSONB) - Potential cancer types with probabilities
- `red_flag_indicators` (JSONB) - Detected risk indicators
- `lab_abnormalities`, `imaging_findings` (JSONB)
- `ai_model_version`, `ai_model_name`
- `confidence_level`, `confidence_percentage`
- `requires_human_review`
- `review_status` - pending, confirmed, disputed, needs_further_testing

**Indexes:**
- `idx_assessments_patient_id` - Patient's assessments
- `idx_assessments_risk_level` - Risk-based queries
- `idx_assessments_requires_review` - Review workflow
- `idx_assessments_cancer_types_gin`, `idx_assessments_red_flags_gin` - JSONB queries

#### 5. `audit_logs`
Immutable audit trail for compliance with 7-year retention (DPDP Act, HIPAA-ready).

**Key Fields:**
- `log_id` (UUID, Primary Key)
- `event_timestamp` - When the event occurred
- `event_type`, `event_category` - Event classification
- `user_id`, `user_role`, `user_ip_address`, `session_id` - User context
- `patient_id` - Associated patient (if applicable)
- `resource_type`, `resource_id` - Affected resource
- `action`, `action_status` - What was done and outcome
- `before_state`, `after_state`, `changes` (JSONB) - State tracking
- `ai_model_used`, `ai_model_version` - AI operations
- `retention_until` - Automatic 7-year retention

**Special Features:**
- **Immutable**: Trigger prevents UPDATE and DELETE operations
- **Automatic retention**: `retention_until` set to 7 years from creation
- **Cleanup function**: `cleanup_expired_audit_logs()` for archival

**Indexes:**
- `idx_audit_event_timestamp` - Temporal queries
- `idx_audit_user_id`, `idx_audit_patient_id` - User/patient activity
- `idx_audit_event_category`, `idx_audit_action` - Event filtering
- `idx_audit_retention_until` - Retention management

### Views

#### 1. `active_patients_summary`
Aggregated view of active patients with report/summary/assessment counts.

#### 2. `high_risk_patients`
Patients with high or critical risk assessments requiring review.

#### 3. `recent_patient_audit_events`
Recent audit events (last 30 days) with patient context.

### Functions and Triggers

#### 1. `update_updated_at_column()`
Automatically updates `updated_at` timestamp on row modifications.

#### 2. `prevent_audit_log_modification()`
Enforces immutability of audit logs (prevents UPDATE/DELETE).

#### 3. `cleanup_expired_audit_logs()`
Archives/deletes audit logs past retention period (should be scheduled).

## Directory Structure

```
infrastructure/database/
├── README.md                           # This file
├── schema.sql                          # Complete database schema
├── deploy_schema.sh                    # Deployment script (Linux/Mac)
├── deploy_schema.ps1                   # Deployment script (Windows)
├── migrations/
│   ├── 001_initial_schema.sql         # Initial schema migration
│   └── 001_initial_schema_rollback.sql # Rollback script
└── seeds/
    └── test_data.sql                   # Test data for development
```

## Deployment

### Prerequisites

1. **PostgreSQL Client**: Install `psql` command-line tool
   - Ubuntu/Debian: `sudo apt-get install postgresql-client`
   - macOS: `brew install postgresql`
   - Windows: Download from [PostgreSQL website](https://www.postgresql.org/download/windows/)

2. **Terraform**: Ensure RDS instance is provisioned
   ```bash
   cd ../terraform
   terraform apply
   ```

3. **Network Access**: Ensure your IP is allowed in RDS security group

### Deployment Steps

#### Linux/Mac

```bash
cd infrastructure/database

# Deploy schema only
./deploy_schema.sh mvp

# Deploy schema with test data
./deploy_schema.sh mvp --with-seed-data
```

#### Windows (PowerShell)

```powershell
cd infrastructure\database

# Deploy schema only
.\deploy_schema.ps1 -Environment mvp

# Deploy schema with test data
.\deploy_schema.ps1 -Environment mvp -WithSeedData
```

### Manual Deployment

If you prefer manual deployment:

```bash
# Set environment variables
export PGHOST=your-rds-endpoint.rds.amazonaws.com
export PGPORT=5432
export PGDATABASE=cancer_detection_db
export PGUSER=postgres
export PGPASSWORD=your-password

# Deploy schema
psql -f schema.sql

# (Optional) Load test data
psql -f seeds/test_data.sql
```

## Rollback

To rollback the schema (WARNING: This will delete all data):

```bash
# Linux/Mac
psql -f migrations/001_initial_schema_rollback.sql

# Windows
psql -f migrations\001_initial_schema_rollback.sql
```

## Verification

After deployment, verify the schema:

```sql
-- Check tables
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;

-- Check indexes
SELECT schemaname, tablename, indexname 
FROM pg_indexes 
WHERE schemaname = 'public' 
ORDER BY tablename, indexname;

-- Check views
SELECT table_name 
FROM information_schema.views 
WHERE table_schema = 'public';

-- Check triggers
SELECT trigger_name, event_object_table, action_statement 
FROM information_schema.triggers 
WHERE trigger_schema = 'public';
```

## Security Considerations

1. **Encryption at Rest**: All data encrypted using AWS KMS (configured in Terraform)
2. **Encryption in Transit**: SSL/TLS enforced for all connections
3. **Least Privilege**: Create separate application users with limited permissions
4. **Audit Logs**: Immutable audit trail with 7-year retention
5. **Password Management**: Use AWS Secrets Manager for production credentials

## Application User Setup

For production, create a separate application user with limited permissions:

```sql
-- Create application user
CREATE USER app_user WITH PASSWORD 'secure_password_here';

-- Grant appropriate permissions
GRANT SELECT, INSERT, UPDATE ON patients, reports, clinical_summaries, cancer_risk_assessments TO app_user;
GRANT SELECT, INSERT ON audit_logs TO app_user;
GRANT SELECT ON active_patients_summary, high_risk_patients, recent_patient_audit_events TO app_user;

-- Grant sequence usage
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO app_user;
```

## Maintenance

### Regular Tasks

1. **Monitor Storage**: Check RDS storage usage and adjust if needed
2. **Review Indexes**: Analyze query performance and add indexes as needed
3. **Archive Audit Logs**: Run `cleanup_expired_audit_logs()` periodically
4. **Backup Verification**: Test backup restoration regularly

### Performance Tuning

The schema includes optimized indexes for common query patterns:
- Patient lookups by ID, ABHA number, phone, email
- Report queries by patient and date
- Summary and assessment queries by patient and timestamp
- Audit log queries by user, patient, and event type

Monitor query performance using:
```sql
-- Enable query logging
ALTER DATABASE cancer_detection_db SET log_statement = 'all';

-- Check slow queries
SELECT * FROM pg_stat_statements ORDER BY total_time DESC LIMIT 10;
```

## Troubleshooting

### Connection Issues

1. **Check RDS endpoint**: Verify endpoint from Terraform outputs
2. **Security groups**: Ensure your IP is whitelisted
3. **VPC configuration**: Verify RDS is in correct subnet
4. **Credentials**: Verify username and password

### Schema Issues

1. **Partial deployment**: Use rollback script and redeploy
2. **Permission errors**: Ensure master user has sufficient privileges
3. **Extension errors**: Verify PostgreSQL version supports required extensions

### Performance Issues

1. **Missing indexes**: Check query plans with `EXPLAIN ANALYZE`
2. **Table bloat**: Run `VACUUM ANALYZE` regularly
3. **Connection pooling**: Implement connection pooling in application

## Support

For issues or questions:
1. Check Terraform outputs for RDS connection details
2. Review CloudWatch logs for RDS errors
3. Consult AWS RDS documentation
4. Review PostgreSQL documentation for specific errors

## Next Steps

After deploying the database schema:

1. **Configure Application**: Update application configuration with database connection details
2. **Create Application User**: Set up dedicated user with limited permissions
3. **Test Connectivity**: Verify application can connect to database
4. **Implement Migrations**: Set up migration tool (Flyway, Alembic) for future schema changes
5. **Monitor Performance**: Set up CloudWatch alarms for database metrics
