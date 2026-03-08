-- Seed Data for Testing
-- Description: Sample data for development and testing
-- WARNING: DO NOT USE IN PRODUCTION

BEGIN;

-- Insert test patients
INSERT INTO patients (patient_id, abha_number, patient_name, date_of_birth, gender, phone_number, email, created_by) VALUES
('11111111-1111-1111-1111-111111111111', '12-3456-7890-1234', 'Test Patient One', '1980-05-15', 'Male', '+91-9876543210', 'patient1@example.com', 'system'),
('22222222-2222-2222-2222-222222222222', '98-7654-3210-9876', 'Test Patient Two', '1975-08-22', 'Female', '+91-9876543211', 'patient2@example.com', 'system'),
('33333333-3333-3333-3333-333333333333', NULL, 'Test Patient Three', '1990-12-10', 'Male', '+91-9876543212', 'patient3@example.com', 'system');

-- Insert test reports
INSERT INTO reports (report_id, patient_id, report_type, report_title, s3_bucket, s3_key, file_format, file_size_bytes, uploaded_by, report_date) VALUES
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'lab', 'Complete Blood Count', 'cancer-detection-dev-reports', 'patients/11111111-1111-1111-1111-111111111111/lab/cbc_2024.pdf', 'pdf', 1024000, 'doctor@example.com', '2024-01-15'),
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '11111111-1111-1111-1111-111111111111', 'radiology', 'Chest X-Ray', 'cancer-detection-dev-reports', 'patients/11111111-1111-1111-1111-111111111111/radiology/chest_xray_2024.pdf', 'pdf', 2048000, 'doctor@example.com', '2024-01-20'),
('cccccccc-cccc-cccc-cccc-cccccccccccc', '22222222-2222-2222-2222-222222222222', 'lab', 'Tumor Marker Test', 'cancer-detection-dev-reports', 'patients/22222222-2222-2222-2222-222222222222/lab/tumor_markers_2024.pdf', 'pdf', 512000, 'doctor@example.com', '2024-02-01');

-- Insert test clinical summaries
INSERT INTO clinical_summaries (summary_id, patient_id, summary_text, language, persona, chief_complaints, ai_model_version, ai_model_name, generated_by, input_report_ids, confidence_score) VALUES
('dddddddd-dddd-dddd-dddd-dddddddddddd', '11111111-1111-1111-1111-111111111111', 'Patient presents with routine checkup. CBC shows normal values. Chest X-ray clear.', 'en', 'healthcare_provider', 'Routine checkup', 'claude-3-sonnet-v1', 'Amazon Bedrock Claude 3 Sonnet', 'system', ARRAY['aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::UUID, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::UUID], 85.5),
('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '22222222-2222-2222-2222-222222222222', 'Patient shows elevated tumor markers. Further investigation recommended.', 'en', 'healthcare_provider', 'Elevated tumor markers', 'claude-3-sonnet-v1', 'Amazon Bedrock Claude 3 Sonnet', 'system', ARRAY['cccccccc-cccc-cccc-cccc-cccccccccccc'::UUID], 72.3);

-- Insert test cancer risk assessments
INSERT INTO cancer_risk_assessments (
    assessment_id, 
    patient_id, 
    summary_id, 
    overall_risk_level, 
    risk_score, 
    cancer_types, 
    red_flag_indicators,
    ai_model_version, 
    ai_model_name, 
    assessed_by, 
    input_report_ids, 
    confidence_level, 
    confidence_percentage
) VALUES
(
    'ffffffff-ffff-ffff-ffff-ffffffffffff', 
    '11111111-1111-1111-1111-111111111111', 
    'dddddddd-dddd-dddd-dddd-dddddddddddd', 
    'low', 
    15.5, 
    '{"lung": 0.05, "breast": 0.02}'::jsonb,
    '[]'::jsonb,
    'sagemaker-cancer-detection-v1', 
    'Amazon SageMaker Cancer Detection Model', 
    'system', 
    ARRAY['aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::UUID, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::UUID], 
    'high', 
    88.2
),
(
    '10101010-1010-1010-1010-101010101010', 
    '22222222-2222-2222-2222-222222222222', 
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 
    'high', 
    75.8, 
    '{"breast": 0.65, "ovarian": 0.35}'::jsonb,
    '[{"indicator": "Elevated CA-125", "source": "lab_report", "confidence": 0.82}]'::jsonb,
    'sagemaker-cancer-detection-v1', 
    'Amazon SageMaker Cancer Detection Model', 
    'system', 
    ARRAY['cccccccc-cccc-cccc-cccc-cccccccccccc'::UUID], 
    'medium', 
    68.5
);

-- Insert test audit logs
INSERT INTO audit_logs (event_type, event_category, user_id, user_role, patient_id, action, action_status, api_endpoint, http_method, http_status_code) VALUES
('user_login', 'authentication', 'doctor@example.com', 'Doctor', NULL, 'login', 'success', '/api/auth/login', 'POST', 200),
('patient_record_access', 'data_access', 'doctor@example.com', 'Doctor', '11111111-1111-1111-1111-111111111111', 'view_patient', 'success', '/api/patients/11111111-1111-1111-1111-111111111111', 'GET', 200),
('report_upload', 'data_modification', 'doctor@example.com', 'Doctor', '11111111-1111-1111-1111-111111111111', 'upload_report', 'success', '/api/reports', 'POST', 201),
('clinical_summary_generation', 'ai_generation', 'system', 'AI_Agent', '11111111-1111-1111-1111-111111111111', 'generate_summary', 'success', '/api/ai/summarize', 'POST', 200),
('cancer_risk_assessment', 'ai_generation', 'system', 'AI_Agent', '22222222-2222-2222-2222-222222222222', 'assess_risk', 'success', '/api/ai/assess-risk', 'POST', 200);

COMMIT;

-- Verify seed data
SELECT 'Patients: ' || COUNT(*) FROM patients;
SELECT 'Reports: ' || COUNT(*) FROM reports;
SELECT 'Clinical Summaries: ' || COUNT(*) FROM clinical_summaries;
SELECT 'Cancer Risk Assessments: ' || COUNT(*) FROM cancer_risk_assessments;
SELECT 'Audit Logs: ' || COUNT(*) FROM audit_logs;
