-- Rollback Migration: 001_initial_schema
-- Description: Rollback initial database schema
-- Author: System
-- Date: 2024

BEGIN;

-- Drop views first (dependent objects)
DROP VIEW IF EXISTS recent_patient_audit_events;
DROP VIEW IF EXISTS high_risk_patients;
DROP VIEW IF EXISTS active_patients_summary;

-- Drop triggers
DROP TRIGGER IF EXISTS audit_log_immutable ON audit_logs;
DROP TRIGGER IF EXISTS update_patients_updated_at ON patients;

-- Drop functions
DROP FUNCTION IF EXISTS prevent_audit_log_modification();
DROP FUNCTION IF EXISTS update_updated_at_column();
DROP FUNCTION IF EXISTS cleanup_expired_audit_logs();

-- Drop tables in reverse order of dependencies
DROP TABLE IF EXISTS audit_logs CASCADE;
DROP TABLE IF EXISTS cancer_risk_assessments CASCADE;
DROP TABLE IF EXISTS clinical_summaries CASCADE;
DROP TABLE IF EXISTS reports CASCADE;
DROP TABLE IF EXISTS patients CASCADE;

-- Drop extensions (only if not used by other schemas)
-- DROP EXTENSION IF EXISTS "pgcrypto";
-- DROP EXTENSION IF EXISTS "uuid-ossp";

-- Verify tables were dropped
DO $$
DECLARE
    table_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO table_count
    FROM information_schema.tables
    WHERE table_schema = 'public'
    AND table_name IN ('patients', 'reports', 'clinical_summaries', 'cancer_risk_assessments', 'audit_logs');
    
    IF table_count <> 0 THEN
        RAISE EXCEPTION 'Rollback failed: Expected 0 tables, found %', table_count;
    END IF;
    
    RAISE NOTICE 'Rollback 001_initial_schema completed successfully. Dropped all tables.';
END $$;

COMMIT;
