-- Migration: 001_initial_schema
-- Description: Initial database schema for AI Cancer Detection Platform
-- Author: System
-- Date: 2024
-- Requirements: 2.6, 12.6, 14.1, 27.6

-- This migration creates the initial database schema including:
-- - patients table with ABHA number support
-- - reports table with S3 key references
-- - clinical_summaries table
-- - cancer_risk_assessments table
-- - audit_logs table with 7-year retention
-- - Indexes for performance optimization
-- - Views for common queries
-- - Triggers for data integrity

BEGIN;

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Execute the main schema
\i ../schema.sql

-- Verify tables were created
DO $$
DECLARE
    table_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO table_count
    FROM information_schema.tables
    WHERE table_schema = 'public'
    AND table_name IN ('patients', 'reports', 'clinical_summaries', 'cancer_risk_assessments', 'audit_logs');
    
    IF table_count <> 5 THEN
        RAISE EXCEPTION 'Migration failed: Expected 5 tables, found %', table_count;
    END IF;
    
    RAISE NOTICE 'Migration 001_initial_schema completed successfully. Created % tables.', table_count;
END $$;

COMMIT;
