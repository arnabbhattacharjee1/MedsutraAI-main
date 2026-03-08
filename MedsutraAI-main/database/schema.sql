-- Database Schema for AI Cancer Detection and Clinical Summarization Platform
-- PostgreSQL 15
-- Requirements: 2.6, 12.6, 14.1, 27.6

-- Enable UUID extension for generating unique identifiers
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enable pgcrypto for encryption functions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =============================================================================
-- PATIENTS TABLE
-- Stores patient demographic and identification information
-- Supports ABDM-compliant ABHA (Ayushman Bharat Health Account) numbers
-- =============================================================================

CREATE TABLE patients (
    patient_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    abha_number VARCHAR(17) UNIQUE, -- ABDM ABHA number format: XX-XXXX-XXXX-XXXX
    patient_name VARCHAR(255) NOT NULL,
    date_of_birth DATE,
    gender VARCHAR(20),
    phone_number VARCHAR(20),
    email VARCHAR(255),
    address TEXT,
    emergency_contact_name VARCHAR(255),
    emergency_contact_phone VARCHAR(20),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(255),
    updated_by VARCHAR(255),
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Constraints
    CONSTRAINT valid_abha_format CHECK (abha_number IS NULL OR abha_number ~ '^\d{2}-\d{4}-\d{4}-\d{4}$'),
    CONSTRAINT valid_gender CHECK (gender IN ('Male', 'Female', 'Other', 'Prefer not to say'))
);

-- Indexes for patients table
CREATE INDEX idx_patients_abha_number ON patients(abha_number) WHERE abha_number IS NOT NULL;
CREATE INDEX idx_patients_phone ON patients(phone_number);
CREATE INDEX idx_patients_email ON patients(email);
CREATE INDEX idx_patients_created_at ON patients(created_at);
CREATE INDEX idx_patients_is_active ON patients(is_active);

-- =============================================================================
-- REPORTS TABLE
-- Stores medical report metadata with S3 references
-- Supports multiple report types: lab, radiology, prescription, clinical notes
-- =============================================================================

CREATE TABLE reports (
    report_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID NOT NULL REFERENCES patients(patient_id) ON DELETE CASCADE,
    report_type VARCHAR(50) NOT NULL,
    report_title VARCHAR(500) NOT NULL,
    report_description TEXT,
    s3_bucket VARCHAR(255) NOT NULL,
    s3_key VARCHAR(1024) NOT NULL,
    s3_version_id VARCHAR(255),
    file_format VARCHAR(20) NOT NULL,
    file_size_bytes BIGINT,
    upload_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    report_date DATE, -- Actual date of the medical report/test
    uploaded_by VARCHAR(255) NOT NULL,
    ocr_processed BOOLEAN DEFAULT FALSE,
    ocr_text TEXT,
    ocr_confidence DECIMAL(5,2),
    metadata JSONB, -- Additional metadata (e.g., lab values, imaging findings)
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMP WITH TIME ZONE,
    deleted_by VARCHAR(255),
    
    -- Constraints
    CONSTRAINT valid_report_type CHECK (report_type IN ('lab', 'radiology', 'prescription', 'clinical_note', 'dicom', 'other')),
    CONSTRAINT valid_file_format CHECK (file_format IN ('pdf', 'docx', 'dicom', 'jpg', 'png', 'txt')),
    CONSTRAINT valid_file_size CHECK (file_size_bytes > 0 AND file_size_bytes <= 52428800), -- Max 50MB
    CONSTRAINT valid_ocr_confidence CHECK (ocr_confidence IS NULL OR (ocr_confidence >= 0 AND ocr_confidence <= 100))
);

-- Indexes for reports table
CREATE INDEX idx_reports_patient_id ON reports(patient_id);
CREATE INDEX idx_reports_upload_date ON reports(upload_date DESC);
CREATE INDEX idx_reports_report_date ON reports(report_date DESC);
CREATE INDEX idx_reports_report_type ON reports(report_type);
CREATE INDEX idx_reports_uploaded_by ON reports(uploaded_by);
CREATE INDEX idx_reports_is_deleted ON reports(is_deleted);
CREATE INDEX idx_reports_patient_upload ON reports(patient_id, upload_date DESC);
CREATE INDEX idx_reports_metadata_gin ON reports USING gin(metadata); -- For JSONB queries

-- =============================================================================
-- CLINICAL_SUMMARIES TABLE
-- Stores AI-generated clinical summaries
-- Supports multilingual content and persona-based adaptations
-- =============================================================================

CREATE TABLE clinical_summaries (
    summary_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID NOT NULL REFERENCES patients(patient_id) ON DELETE CASCADE,
    summary_text TEXT NOT NULL,
    language VARCHAR(10) NOT NULL,
    persona VARCHAR(50) NOT NULL,
    chief_complaints TEXT,
    medical_history TEXT,
    current_medications TEXT,
    abnormal_findings TEXT,
    pending_actions TEXT,
    ai_model_version VARCHAR(100) NOT NULL,
    ai_model_name VARCHAR(100) NOT NULL,
    generation_timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    generated_by VARCHAR(255) NOT NULL,
    input_report_ids UUID[], -- Array of report IDs used as input
    confidence_score DECIMAL(5,2),
    review_status VARCHAR(50) DEFAULT 'pending',
    reviewed_by VARCHAR(255),
    reviewed_at TIMESTAMP WITH TIME ZONE,
    review_notes TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Constraints
    CONSTRAINT valid_language CHECK (language IN ('en', 'hi', 'ta', 'bn', 'mr', 'te')),
    CONSTRAINT valid_persona CHECK (persona IN ('healthcare_provider', 'patient')),
    CONSTRAINT valid_confidence CHECK (confidence_score IS NULL OR (confidence_score >= 0 AND confidence_score <= 100)),
    CONSTRAINT valid_review_status CHECK (review_status IN ('pending', 'approved', 'rejected', 'needs_revision'))
);

-- Indexes for clinical_summaries table
CREATE INDEX idx_summaries_patient_id ON clinical_summaries(patient_id);
CREATE INDEX idx_summaries_generation_timestamp ON clinical_summaries(generation_timestamp DESC);
CREATE INDEX idx_summaries_language ON clinical_summaries(language);
CREATE INDEX idx_summaries_persona ON clinical_summaries(persona);
CREATE INDEX idx_summaries_review_status ON clinical_summaries(review_status);
CREATE INDEX idx_summaries_is_active ON clinical_summaries(is_active);
CREATE INDEX idx_summaries_patient_timestamp ON clinical_summaries(patient_id, generation_timestamp DESC);

-- =============================================================================
-- CANCER_RISK_ASSESSMENTS TABLE
-- Stores AI-generated cancer risk assessments
-- Includes NLP classification results and risk indicators
-- =============================================================================

CREATE TABLE cancer_risk_assessments (
    assessment_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID NOT NULL REFERENCES patients(patient_id) ON DELETE CASCADE,
    summary_id UUID REFERENCES clinical_summaries(summary_id) ON DELETE SET NULL,
    overall_risk_level VARCHAR(20) NOT NULL,
    risk_score DECIMAL(5,2) NOT NULL,
    cancer_types JSONB, -- Array of potential cancer types with probabilities
    red_flag_indicators JSONB, -- Array of detected red flags with sources
    lab_abnormalities JSONB, -- Lab values outside normal ranges
    imaging_findings JSONB, -- Suspicious imaging findings
    cross_reference_findings TEXT,
    ai_model_version VARCHAR(100) NOT NULL,
    ai_model_name VARCHAR(100) NOT NULL,
    assessment_timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    assessed_by VARCHAR(255) NOT NULL,
    input_report_ids UUID[], -- Array of report IDs analyzed
    confidence_level VARCHAR(20) NOT NULL,
    confidence_percentage DECIMAL(5,2) NOT NULL,
    explainability_text TEXT,
    evidence_sources JSONB, -- Citations to specific reports/sections
    requires_human_review BOOLEAN DEFAULT TRUE,
    review_status VARCHAR(50) DEFAULT 'pending',
    reviewed_by VARCHAR(255),
    reviewed_at TIMESTAMP WITH TIME ZONE,
    review_notes TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Constraints
    CONSTRAINT valid_risk_level CHECK (overall_risk_level IN ('low', 'medium', 'high', 'critical')),
    CONSTRAINT valid_risk_score CHECK (risk_score >= 0 AND risk_score <= 100),
    CONSTRAINT valid_confidence_level CHECK (confidence_level IN ('low', 'medium', 'high')),
    CONSTRAINT valid_confidence_percentage CHECK (confidence_percentage >= 0 AND confidence_percentage <= 100),
    CONSTRAINT valid_review_status CHECK (review_status IN ('pending', 'confirmed', 'disputed', 'needs_further_testing'))
);

-- Indexes for cancer_risk_assessments table
CREATE INDEX idx_assessments_patient_id ON cancer_risk_assessments(patient_id);
CREATE INDEX idx_assessments_summary_id ON cancer_risk_assessments(summary_id);
CREATE INDEX idx_assessments_timestamp ON cancer_risk_assessments(assessment_timestamp DESC);
CREATE INDEX idx_assessments_risk_level ON cancer_risk_assessments(overall_risk_level);
CREATE INDEX idx_assessments_review_status ON cancer_risk_assessments(review_status);
CREATE INDEX idx_assessments_requires_review ON cancer_risk_assessments(requires_human_review);
CREATE INDEX idx_assessments_is_active ON cancer_risk_assessments(is_active);
CREATE INDEX idx_assessments_patient_timestamp ON cancer_risk_assessments(patient_id, assessment_timestamp DESC);
CREATE INDEX idx_assessments_cancer_types_gin ON cancer_risk_assessments USING gin(cancer_types);
CREATE INDEX idx_assessments_red_flags_gin ON cancer_risk_assessments USING gin(red_flag_indicators);

-- =============================================================================
-- AUDIT_LOGS TABLE
-- Comprehensive audit trail for compliance (DPDP Act, HIPAA-ready)
-- 7-year retention as per Requirement 27.6
-- =============================================================================

CREATE TABLE audit_logs (
    log_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    event_category VARCHAR(50) NOT NULL,
    user_id VARCHAR(255) NOT NULL,
    user_role VARCHAR(50),
    user_ip_address INET,
    session_id VARCHAR(255),
    patient_id UUID REFERENCES patients(patient_id) ON DELETE SET NULL,
    resource_type VARCHAR(100),
    resource_id VARCHAR(255),
    action VARCHAR(100) NOT NULL,
    action_status VARCHAR(20) NOT NULL,
    before_state JSONB,
    after_state JSONB,
    changes JSONB,
    ai_model_used VARCHAR(100),
    ai_model_version VARCHAR(100),
    request_id VARCHAR(255),
    api_endpoint VARCHAR(500),
    http_method VARCHAR(10),
    http_status_code INTEGER,
    error_message TEXT,
    error_stack_trace TEXT,
    metadata JSONB,
    retention_until DATE NOT NULL DEFAULT (CURRENT_DATE + INTERVAL '7 years'), -- 7-year retention
    
    -- Constraints
    CONSTRAINT valid_event_category CHECK (event_category IN ('authentication', 'authorization', 'data_access', 'data_modification', 'ai_generation', 'export', 'deletion', 'system', 'security')),
    CONSTRAINT valid_action_status CHECK (action_status IN ('success', 'failure', 'partial', 'error')),
    CONSTRAINT valid_http_method CHECK (http_method IS NULL OR http_method IN ('GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'))
);

-- Indexes for audit_logs table (optimized for compliance queries)
CREATE INDEX idx_audit_event_timestamp ON audit_logs(event_timestamp DESC);
CREATE INDEX idx_audit_event_type ON audit_logs(event_type);
CREATE INDEX idx_audit_event_category ON audit_logs(event_category);
CREATE INDEX idx_audit_user_id ON audit_logs(user_id);
CREATE INDEX idx_audit_patient_id ON audit_logs(patient_id) WHERE patient_id IS NOT NULL;
CREATE INDEX idx_audit_action ON audit_logs(action);
CREATE INDEX idx_audit_action_status ON audit_logs(action_status);
CREATE INDEX idx_audit_retention_until ON audit_logs(retention_until);
CREATE INDEX idx_audit_session_id ON audit_logs(session_id);
CREATE INDEX idx_audit_user_timestamp ON audit_logs(user_id, event_timestamp DESC);
CREATE INDEX idx_audit_patient_timestamp ON audit_logs(patient_id, event_timestamp DESC) WHERE patient_id IS NOT NULL;
CREATE INDEX idx_audit_metadata_gin ON audit_logs USING gin(metadata);

-- Prevent deletion or modification of audit logs (immutable)
CREATE OR REPLACE FUNCTION prevent_audit_log_modification()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'Deletion of audit logs is not permitted';
    ELSIF TG_OP = 'UPDATE' THEN
        RAISE EXCEPTION 'Modification of audit logs is not permitted';
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER audit_log_immutable
BEFORE UPDATE OR DELETE ON audit_logs
FOR EACH ROW EXECUTE FUNCTION prevent_audit_log_modification();

-- =============================================================================
-- AUTOMATIC TIMESTAMP UPDATES
-- Trigger to automatically update updated_at columns
-- =============================================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_patients_updated_at
BEFORE UPDATE ON patients
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- AUDIT LOG RETENTION CLEANUP
-- Function to archive/delete audit logs past retention period
-- Should be called by a scheduled job
-- =============================================================================

CREATE OR REPLACE FUNCTION cleanup_expired_audit_logs()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    -- In production, consider archiving to S3 before deletion
    DELETE FROM audit_logs
    WHERE retention_until < CURRENT_DATE;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- VIEWS FOR COMMON QUERIES
-- =============================================================================

-- Active patients with recent activity
CREATE VIEW active_patients_summary AS
SELECT 
    p.patient_id,
    p.abha_number,
    p.patient_name,
    p.date_of_birth,
    p.gender,
    COUNT(DISTINCT r.report_id) as total_reports,
    COUNT(DISTINCT cs.summary_id) as total_summaries,
    COUNT(DISTINCT cra.assessment_id) as total_assessments,
    MAX(r.upload_date) as last_report_date,
    MAX(cs.generation_timestamp) as last_summary_date,
    MAX(cra.assessment_timestamp) as last_assessment_date
FROM patients p
LEFT JOIN reports r ON p.patient_id = r.patient_id AND r.is_deleted = FALSE
LEFT JOIN clinical_summaries cs ON p.patient_id = cs.patient_id AND cs.is_active = TRUE
LEFT JOIN cancer_risk_assessments cra ON p.patient_id = cra.patient_id AND cra.is_active = TRUE
WHERE p.is_active = TRUE
GROUP BY p.patient_id, p.abha_number, p.patient_name, p.date_of_birth, p.gender;

-- High-risk patients requiring review
CREATE VIEW high_risk_patients AS
SELECT 
    p.patient_id,
    p.abha_number,
    p.patient_name,
    cra.assessment_id,
    cra.overall_risk_level,
    cra.risk_score,
    cra.cancer_types,
    cra.assessment_timestamp,
    cra.review_status,
    cra.requires_human_review
FROM patients p
INNER JOIN cancer_risk_assessments cra ON p.patient_id = cra.patient_id
WHERE cra.is_active = TRUE
  AND cra.overall_risk_level IN ('high', 'critical')
  AND cra.review_status = 'pending'
ORDER BY cra.risk_score DESC, cra.assessment_timestamp DESC;

-- Recent audit events by patient
CREATE VIEW recent_patient_audit_events AS
SELECT 
    al.log_id,
    al.event_timestamp,
    al.event_type,
    al.event_category,
    al.user_id,
    al.user_role,
    al.patient_id,
    p.patient_name,
    p.abha_number,
    al.action,
    al.action_status,
    al.resource_type,
    al.resource_id
FROM audit_logs al
LEFT JOIN patients p ON al.patient_id = p.patient_id
WHERE al.event_timestamp >= CURRENT_TIMESTAMP - INTERVAL '30 days'
ORDER BY al.event_timestamp DESC;

-- =============================================================================
-- GRANT PERMISSIONS
-- These should be adjusted based on your application user roles
-- =============================================================================

-- Example: Create application user (adjust credentials in production)
-- CREATE USER app_user WITH PASSWORD 'secure_password_here';

-- Grant appropriate permissions
-- GRANT SELECT, INSERT, UPDATE ON patients, reports, clinical_summaries, cancer_risk_assessments TO app_user;
-- GRANT SELECT, INSERT ON audit_logs TO app_user;
-- GRANT SELECT ON active_patients_summary, high_risk_patients, recent_patient_audit_events TO app_user;

-- =============================================================================
-- COMMENTS FOR DOCUMENTATION
-- =============================================================================

COMMENT ON TABLE patients IS 'Patient demographic and identification information with ABDM ABHA number support';
COMMENT ON TABLE reports IS 'Medical report metadata with S3 references for actual document storage';
COMMENT ON TABLE clinical_summaries IS 'AI-generated clinical summaries with multilingual and persona-based content';
COMMENT ON TABLE cancer_risk_assessments IS 'AI-generated cancer risk assessments with NLP classification results';
COMMENT ON TABLE audit_logs IS 'Immutable audit trail for compliance with 7-year retention (DPDP Act, HIPAA-ready)';

COMMENT ON COLUMN patients.abha_number IS 'ABDM-compliant Ayushman Bharat Health Account number (format: XX-XXXX-XXXX-XXXX)';
COMMENT ON COLUMN reports.s3_key IS 'S3 object key for encrypted medical document storage';
COMMENT ON COLUMN reports.ocr_text IS 'Extracted text from scanned images using Amazon Textract';
COMMENT ON COLUMN clinical_summaries.persona IS 'Target persona: healthcare_provider (technical) or patient (simplified)';
COMMENT ON COLUMN cancer_risk_assessments.red_flag_indicators IS 'JSON array of detected cancer risk indicators with evidence';
COMMENT ON COLUMN audit_logs.retention_until IS 'Audit log retention date (7 years from creation as per Requirement 27.6)';
