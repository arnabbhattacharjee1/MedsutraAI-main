# Database Schema Quick Reference

## Table Relationships

```
patients (1) ──< (N) reports
    │
    ├──< (N) clinical_summaries
    │
    ├──< (N) cancer_risk_assessments
    │
    └──< (N) audit_logs

clinical_summaries (1) ──< (N) cancer_risk_assessments
```

## Table Sizes (Estimated)

| Table | Columns | Indexes | Estimated Row Size | Notes |
|-------|---------|---------|-------------------|-------|
| patients | 15 | 5 | ~500 bytes | Low volume, high importance |
| reports | 20 | 8 | ~1-2 KB | Medium volume, JSONB metadata |
| clinical_summaries | 19 | 7 | ~2-5 KB | Medium volume, text-heavy |
| cancer_risk_assessments | 24 | 9 | ~2-5 KB | Medium volume, JSONB data |
| audit_logs | 26 | 11 | ~1-2 KB | High volume, immutable |

## Common Queries

### Patient Queries

```sql
-- Get patient by ABHA number
SELECT * FROM patients WHERE abha_number = '12-3456-7890-1234';

-- Get patient with all reports
SELECT p.*, r.report_id, r.report_type, r.report_title, r.upload_date
FROM patients p
LEFT JOIN reports r ON p.patient_id = r.patient_id
WHERE p.patient_id = 'uuid-here' AND r.is_deleted = FALSE
ORDER BY r.upload_date DESC;

-- Get active patients summary
SELECT * FROM active_patients_summary
ORDER BY last_report_date DESC;
```

### Report Queries

```sql
-- Get recent reports for patient
SELECT * FROM reports
WHERE patient_id = 'uuid-here' AND is_deleted = FALSE
ORDER BY upload_date DESC
LIMIT 10;

-- Get reports by type
SELECT * FROM reports
WHERE patient_id = 'uuid-here' 
  AND report_type = 'lab'
  AND is_deleted = FALSE
ORDER BY report_date DESC;

-- Search reports by metadata
SELECT * FROM reports
WHERE patient_id = 'uuid-here'
  AND metadata @> '{"test_type": "blood_work"}'::jsonb;
```

### Clinical Summary Queries

```sql
-- Get latest summary for patient in specific language
SELECT * FROM clinical_summaries
WHERE patient_id = 'uuid-here'
  AND language = 'en'
  AND persona = 'healthcare_provider'
  AND is_active = TRUE
ORDER BY generation_timestamp DESC
LIMIT 1;

-- Get all summaries pending review
SELECT * FROM clinical_summaries
WHERE review_status = 'pending'
ORDER BY generation_timestamp ASC;
```

### Cancer Risk Assessment Queries

```sql
-- Get high-risk patients
SELECT * FROM high_risk_patients
ORDER BY risk_score DESC;

-- Get latest assessment for patient
SELECT * FROM cancer_risk_assessments
WHERE patient_id = 'uuid-here' AND is_active = TRUE
ORDER BY assessment_timestamp DESC
LIMIT 1;

-- Find patients with specific cancer type risk
SELECT DISTINCT patient_id, cancer_types
FROM cancer_risk_assessments
WHERE cancer_types ? 'lung'  -- Check if 'lung' key exists
  AND is_active = TRUE;

-- Get assessments requiring review
SELECT * FROM cancer_risk_assessments
WHERE requires_human_review = TRUE
  AND review_status = 'pending'
ORDER BY risk_score DESC;
```

### Audit Log Queries

```sql
-- Get user activity
SELECT * FROM audit_logs
WHERE user_id = 'user@example.com'
ORDER BY event_timestamp DESC
LIMIT 50;

-- Get patient access history
SELECT * FROM audit_logs
WHERE patient_id = 'uuid-here'
  AND event_category = 'data_access'
ORDER BY event_timestamp DESC;

-- Get failed authentication attempts
SELECT * FROM audit_logs
WHERE event_category = 'authentication'
  AND action_status = 'failure'
  AND event_timestamp >= NOW() - INTERVAL '24 hours'
ORDER BY event_timestamp DESC;

-- Get AI generation events
SELECT * FROM audit_logs
WHERE event_category = 'ai_generation'
  AND event_timestamp >= NOW() - INTERVAL '7 days'
ORDER BY event_timestamp DESC;

-- Compliance report: All access to specific patient
SELECT 
    event_timestamp,
    user_id,
    user_role,
    action,
    resource_type,
    action_status
FROM audit_logs
WHERE patient_id = 'uuid-here'
ORDER BY event_timestamp DESC;
```

## JSONB Query Examples

### Reports Metadata

```sql
-- Query specific metadata field
SELECT * FROM reports
WHERE metadata->>'test_type' = 'blood_work';

-- Query nested JSONB
SELECT * FROM reports
WHERE metadata->'lab_values'->>'hemoglobin' IS NOT NULL;

-- Query array in JSONB
SELECT * FROM reports
WHERE metadata @> '{"abnormal_flags": ["high_glucose"]}'::jsonb;
```

### Cancer Risk Assessments

```sql
-- Get assessments with specific cancer type probability > 0.5
SELECT patient_id, cancer_types
FROM cancer_risk_assessments
WHERE (cancer_types->>'breast')::float > 0.5;

-- Get all red flag indicators
SELECT 
    patient_id,
    jsonb_array_elements(red_flag_indicators) as red_flag
FROM cancer_risk_assessments
WHERE is_active = TRUE;

-- Count assessments by cancer type
SELECT 
    cancer_type,
    COUNT(*) as count
FROM cancer_risk_assessments,
     jsonb_object_keys(cancer_types) as cancer_type
WHERE is_active = TRUE
GROUP BY cancer_type
ORDER BY count DESC;
```

## Index Usage

### Check Index Usage

```sql
-- See which indexes are being used
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan as index_scans,
    idx_tup_read as tuples_read,
    idx_tup_fetch as tuples_fetched
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan DESC;

-- Find unused indexes
SELECT 
    schemaname,
    tablename,
    indexname
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
  AND idx_scan = 0
  AND indexname NOT LIKE '%_pkey';
```

## Performance Tips

### 1. Use Appropriate Indexes

```sql
-- Patient lookup by ABHA number (indexed)
SELECT * FROM patients WHERE abha_number = '12-3456-7890-1234';

-- Report queries with composite index
SELECT * FROM reports 
WHERE patient_id = 'uuid-here' 
ORDER BY upload_date DESC;
```

### 2. Limit Result Sets

```sql
-- Always use LIMIT for large tables
SELECT * FROM audit_logs 
WHERE user_id = 'user@example.com'
ORDER BY event_timestamp DESC
LIMIT 100;
```

### 3. Use Views for Complex Queries

```sql
-- Use pre-defined views instead of complex joins
SELECT * FROM active_patients_summary;
SELECT * FROM high_risk_patients;
```

### 4. JSONB Indexing

```sql
-- GIN indexes are already created for JSONB columns
-- Use containment operators for best performance
SELECT * FROM reports 
WHERE metadata @> '{"test_type": "blood_work"}'::jsonb;
```

## Data Integrity

### Constraints

1. **Foreign Keys**: Enforce referential integrity
   - `reports.patient_id` → `patients.patient_id` (CASCADE DELETE)
   - `clinical_summaries.patient_id` → `patients.patient_id` (CASCADE DELETE)
   - `cancer_risk_assessments.patient_id` → `patients.patient_id` (CASCADE DELETE)

2. **Check Constraints**: Validate data values
   - ABHA number format: `XX-XXXX-XXXX-XXXX`
   - Gender values: Male, Female, Other, Prefer not to say
   - Risk levels: low, medium, high, critical
   - Confidence scores: 0-100

3. **Unique Constraints**:
   - `patients.abha_number` (UNIQUE)

### Triggers

1. **Auto-update timestamps**: `update_patients_updated_at`
2. **Audit log immutability**: `audit_log_immutable`

## Maintenance Queries

### Database Statistics

```sql
-- Table sizes
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Index sizes
SELECT 
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY pg_relation_size(indexrelid) DESC;

-- Row counts
SELECT 
    schemaname,
    tablename,
    n_live_tup as row_count
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY n_live_tup DESC;
```

### Vacuum and Analyze

```sql
-- Analyze all tables
ANALYZE;

-- Vacuum specific table
VACUUM ANALYZE patients;

-- Check last vacuum/analyze times
SELECT 
    schemaname,
    relname,
    last_vacuum,
    last_autovacuum,
    last_analyze,
    last_autoanalyze
FROM pg_stat_user_tables
WHERE schemaname = 'public';
```

### Audit Log Cleanup

```sql
-- Check audit logs past retention
SELECT COUNT(*) 
FROM audit_logs 
WHERE retention_until < CURRENT_DATE;

-- Run cleanup function
SELECT cleanup_expired_audit_logs();
```

## Security Queries

### User Permissions

```sql
-- Check table permissions
SELECT 
    grantee,
    table_schema,
    table_name,
    privilege_type
FROM information_schema.table_privileges
WHERE table_schema = 'public'
ORDER BY grantee, table_name;

-- Check current user
SELECT current_user, session_user;
```

### Connection Information

```sql
-- Active connections
SELECT 
    pid,
    usename,
    application_name,
    client_addr,
    state,
    query_start,
    state_change
FROM pg_stat_activity
WHERE datname = current_database()
ORDER BY query_start DESC;

-- Connection count by user
SELECT 
    usename,
    COUNT(*) as connection_count
FROM pg_stat_activity
WHERE datname = current_database()
GROUP BY usename;
```

## Backup and Recovery

### Manual Backup

```bash
# Full database backup
pg_dump -h hostname -U username -d cancer_detection_db -F c -f backup.dump

# Schema only
pg_dump -h hostname -U username -d cancer_detection_db --schema-only -f schema.sql

# Data only
pg_dump -h hostname -U username -d cancer_detection_db --data-only -f data.sql

# Specific table
pg_dump -h hostname -U username -d cancer_detection_db -t patients -f patients.sql
```

### Restore

```bash
# Restore from custom format
pg_restore -h hostname -U username -d cancer_detection_db backup.dump

# Restore from SQL file
psql -h hostname -U username -d cancer_detection_db -f backup.sql
```

## Monitoring Queries

### Query Performance

```sql
-- Slow queries (requires pg_stat_statements extension)
SELECT 
    query,
    calls,
    total_time,
    mean_time,
    max_time
FROM pg_stat_statements
ORDER BY mean_time DESC
LIMIT 10;

-- Long-running queries
SELECT 
    pid,
    now() - query_start as duration,
    query,
    state
FROM pg_stat_activity
WHERE state != 'idle'
  AND query_start < now() - interval '5 minutes'
ORDER BY duration DESC;
```

### Lock Monitoring

```sql
-- Current locks
SELECT 
    l.pid,
    l.mode,
    l.granted,
    a.query
FROM pg_locks l
JOIN pg_stat_activity a ON l.pid = a.pid
WHERE l.database = (SELECT oid FROM pg_database WHERE datname = current_database());
```

## Data Types Reference

| Column Type | PostgreSQL Type | Size | Notes |
|-------------|----------------|------|-------|
| UUID | UUID | 16 bytes | Primary keys, foreign keys |
| ABHA Number | VARCHAR(17) | ~20 bytes | Format: XX-XXXX-XXXX-XXXX |
| Text | TEXT | Variable | Unlimited length |
| Short Text | VARCHAR(255) | Variable | Limited length |
| Date | DATE | 4 bytes | Date only |
| Timestamp | TIMESTAMP WITH TIME ZONE | 8 bytes | Includes timezone |
| Boolean | BOOLEAN | 1 byte | TRUE/FALSE |
| Decimal | DECIMAL(5,2) | Variable | Precision 5, scale 2 |
| Integer | INTEGER | 4 bytes | -2B to +2B |
| Big Integer | BIGINT | 8 bytes | File sizes |
| JSON | JSONB | Variable | Binary JSON, indexed |
| Array | UUID[] | Variable | Array of UUIDs |
| IP Address | INET | 7-19 bytes | IPv4/IPv6 |

## Best Practices

1. **Always use prepared statements** to prevent SQL injection
2. **Use transactions** for multi-table operations
3. **Index foreign keys** (already done in schema)
4. **Monitor query performance** regularly
5. **Use connection pooling** in application
6. **Implement retry logic** for transient errors
7. **Log all audit events** for compliance
8. **Regular backups** and test restoration
9. **Use read replicas** for read-heavy workloads
10. **Monitor storage usage** and plan for growth
