#!/usr/bin/env python3
"""
S3 Bucket Configuration Validation Script
Validates S3 bucket configuration for Task 1.4
"""

import re
import sys
from pathlib import Path

# ANSI color codes
GREEN = '\033[0;32m'
RED = '\033[0;31m'
YELLOW = '\033[1;33m'
BLUE = '\033[0;34m'
NC = '\033[0m'  # No Color

tests_passed = 0
tests_failed = 0

def print_result(passed, message):
    """Print test result with color"""
    global tests_passed, tests_failed
    if passed:
        print(f"{GREEN}✓ PASS{NC}: {message}")
        tests_passed += 1
    else:
        print(f"{RED}✗ FAIL{NC}: {message}")
        tests_failed += 1

def print_section(title):
    """Print section header"""
    print(f"\n{'='*50}")
    print(title)
    print('='*50)

def read_file(filename):
    """Read file content"""
    try:
        with open(filename, 'r', encoding='utf-8') as f:
            return f.read()
    except FileNotFoundError:
        print(f"{RED}Error: File {filename} not found{NC}")
        return ""

def check_resource_exists(content, resource_type, resource_name):
    """Check if a Terraform resource exists"""
    pattern = rf'resource\s+"{resource_type}"\s+"{resource_name}"'
    return bool(re.search(pattern, content))

def check_encryption_config(content, bucket_name, encryption_type):
    """Check encryption configuration for a bucket"""
    # Find the encryption configuration block for the bucket
    pattern = rf'resource\s+"aws_s3_bucket_server_side_encryption_configuration"\s+"{bucket_name}".*?(?=resource\s+|$)'
    match = re.search(pattern, content, re.DOTALL)
    
    if not match:
        return False
    
    config_block = match.group(0)
    return encryption_type in config_block

def check_versioning_enabled(content, bucket_name):
    """Check if versioning is enabled for a bucket"""
    pattern = rf'resource\s+"aws_s3_bucket_versioning"\s+"{bucket_name}".*?(?=resource\s+|$)'
    match = re.search(pattern, content, re.DOTALL)
    
    if not match:
        return False
    
    config_block = match.group(0)
    return 'status' in config_block and 'Enabled' in config_block

def check_public_access_block(content, bucket_name):
    """Check if public access is blocked"""
    pattern = rf'resource\s+"aws_s3_bucket_public_access_block"\s+"{bucket_name}".*?(?=resource\s+|$)'
    match = re.search(pattern, content, re.DOTALL)
    
    if not match:
        return False
    
    config_block = match.group(0)
    required_settings = [
        'block_public_acls',
        'block_public_policy',
        'ignore_public_acls',
        'restrict_public_buckets'
    ]
    return all(setting in config_block and 'true' in config_block for setting in required_settings)

def check_access_logging(content, bucket_name):
    """Check if access logging is configured"""
    pattern = rf'resource\s+"aws_s3_bucket_logging"\s+"{bucket_name}".*?(?=resource\s+|$)'
    match = re.search(pattern, content, re.DOTALL)
    
    if not match:
        return False
    
    config_block = match.group(0)
    return 'target_bucket' in config_block and 'access_logs' in config_block

def check_bucket_policy(content, bucket_name):
    """Check if bucket policy exists"""
    pattern = rf'resource\s+"aws_s3_bucket_policy"\s+"{bucket_name}".*?(?=resource\s+|$)'
    return bool(re.search(pattern, content, re.DOTALL))

def check_policy_statement(content, bucket_name, statement_sid):
    """Check if a specific policy statement exists"""
    pattern = rf'resource\s+"aws_s3_bucket_policy"\s+"{bucket_name}".*?(?=resource\s+|$)'
    match = re.search(pattern, content, re.DOTALL)
    
    if not match:
        return False
    
    policy_block = match.group(0)
    return statement_sid in policy_block

def check_lifecycle_policy(content, bucket_name):
    """Check if lifecycle policy exists"""
    pattern = rf'resource\s+"aws_s3_bucket_lifecycle_configuration"\s+"{bucket_name}".*?(?=resource\s+|$)'
    return bool(re.search(pattern, content, re.DOTALL))

def check_compliance_tags(content, bucket_name, tag_name, tag_value):
    """Check if compliance tags exist"""
    pattern = rf'resource\s+"aws_s3_bucket"\s+"{bucket_name}".*?(?=resource\s+|$)'
    match = re.search(pattern, content, re.DOTALL)
    
    if not match:
        return False
    
    bucket_block = match.group(0)
    return tag_name in bucket_block and tag_value in bucket_block

def check_bucket_key_enabled(content, bucket_name):
    """Check if bucket key is enabled for cost optimization"""
    pattern = rf'resource\s+"aws_s3_bucket_server_side_encryption_configuration"\s+"{bucket_name}".*?(?=resource\s+|$)'
    match = re.search(pattern, content, re.DOTALL)
    
    if not match:
        return False
    
    config_block = match.group(0)
    return 'bucket_key_enabled' in config_block and 'true' in config_block

def main():
    """Main validation function"""
    print(f"{BLUE}{'='*50}")
    print("S3 Bucket Configuration Validation")
    print(f"{'='*50}{NC}")
    
    # Read S3 configuration file
    s3_content = read_file('s3.tf')
    if not s3_content:
        print(f"{RED}Failed to read s3.tf{NC}")
        sys.exit(1)
    
    # Read outputs file
    outputs_content = read_file('outputs.tf')
    
    # Test 1: Check required bucket resources
    print_section("Test 1: Required S3 Bucket Resources")
    
    required_buckets = [
        ('aws_s3_bucket', 'medical_documents'),
        ('aws_s3_bucket', 'frontend_assets'),
        ('aws_s3_bucket', 'audit_logs'),
        ('aws_s3_bucket', 'access_logs')
    ]
    
    for resource_type, resource_name in required_buckets:
        exists = check_resource_exists(s3_content, resource_type, resource_name)
        print_result(exists, f"Resource {resource_type}.{resource_name} exists")
    
    # Test 2: Check encryption configuration
    print_section("Test 2: Encryption Configuration")
    
    # Medical documents should use KMS
    kms_encrypted = check_encryption_config(s3_content, 'medical_documents', 'aws:kms')
    print_result(kms_encrypted, "Medical documents bucket uses KMS encryption")
    
    kms_key_ref = 'aws_kms_key.s3_encryption.arn' in s3_content
    print_result(kms_key_ref, "Medical documents bucket references correct KMS key")
    
    # Frontend assets should use AES256
    frontend_encrypted = check_encryption_config(s3_content, 'frontend_assets', 'AES256')
    print_result(frontend_encrypted, "Frontend assets bucket uses AES256 encryption")
    
    # Audit logs should use AES256
    audit_encrypted = check_encryption_config(s3_content, 'audit_logs', 'AES256')
    print_result(audit_encrypted, "Audit logs bucket uses AES256 encryption")
    
    # Access logs should use AES256
    access_encrypted = check_encryption_config(s3_content, 'access_logs', 'AES256')
    print_result(access_encrypted, "Access logs bucket uses AES256 encryption")
    
    # Test 3: Check versioning configuration
    print_section("Test 3: Versioning Configuration")
    
    versioned_buckets = ['medical_documents', 'frontend_assets', 'audit_logs', 'access_logs']
    
    for bucket in versioned_buckets:
        versioning_enabled = check_versioning_enabled(s3_content, bucket)
        print_result(versioning_enabled, f"Versioning enabled for {bucket} bucket")
    
    # Test 4: Check public access block
    print_section("Test 4: Public Access Block Configuration")
    
    for bucket in versioned_buckets:
        public_blocked = check_public_access_block(s3_content, bucket)
        print_result(public_blocked, f"Public access blocked for {bucket} bucket")
    
    # Test 5: Check access logging
    print_section("Test 5: Access Logging Configuration")
    
    logged_buckets = ['medical_documents', 'frontend_assets', 'audit_logs']
    
    for bucket in logged_buckets:
        logging_configured = check_access_logging(s3_content, bucket)
        print_result(logging_configured, f"Access logging configured for {bucket} bucket")
    
    # Test 6: Check bucket policies
    print_section("Test 6: Bucket Policy Configuration")
    
    policy_buckets = ['medical_documents', 'frontend_assets', 'audit_logs']
    
    for bucket in policy_buckets:
        policy_exists = check_bucket_policy(s3_content, bucket)
        print_result(policy_exists, f"Bucket policy exists for {bucket} bucket")
    
    # Test 7: Check security policies
    print_section("Test 7: Security Policy Validation")
    
    # Check for DenyInsecureTransport in all bucket policies
    for bucket in policy_buckets:
        deny_insecure = check_policy_statement(s3_content, bucket, 'DenyInsecureTransport')
        print_result(deny_insecure, f"DenyInsecureTransport policy exists for {bucket} bucket")
    
    # Check for encryption enforcement in medical documents
    encryption_enforcement = check_policy_statement(s3_content, 'medical_documents', 'DenyUnencryptedObjectUploads')
    print_result(encryption_enforcement, "Encryption enforcement policy exists for medical documents bucket")
    
    # Check for KMS key enforcement in medical documents
    kms_enforcement = check_policy_statement(s3_content, 'medical_documents', 'EnforceKMSEncryption')
    print_result(kms_enforcement, "KMS encryption enforcement policy exists for medical documents bucket")
    
    # Check for log deletion prevention in audit logs
    log_deletion_prevention = check_policy_statement(s3_content, 'audit_logs', 'PreventLogDeletion')
    print_result(log_deletion_prevention, "Log deletion prevention policy exists for audit logs bucket")
    
    # Test 8: Check lifecycle policies
    print_section("Test 8: Lifecycle Policy Configuration")
    
    # Medical documents lifecycle
    medical_lifecycle = check_lifecycle_policy(s3_content, 'medical_documents')
    print_result(medical_lifecycle, "Lifecycle policy configured for medical documents bucket")
    
    # Audit logs lifecycle with 7-year retention
    audit_lifecycle = check_lifecycle_policy(s3_content, 'audit_logs')
    print_result(audit_lifecycle, "Lifecycle policy configured for audit logs bucket")
    
    seven_year_retention = '2555' in s3_content  # 7 years = 2555 days
    print_result(seven_year_retention, "7-year retention policy configured for audit logs bucket")
    
    # Access logs lifecycle
    access_lifecycle = check_lifecycle_policy(s3_content, 'access_logs')
    print_result(access_lifecycle, "Lifecycle policy configured for access logs bucket")
    
    # Frontend assets lifecycle
    frontend_lifecycle = check_lifecycle_policy(s3_content, 'frontend_assets')
    print_result(frontend_lifecycle, "Lifecycle policy configured for frontend assets bucket")
    
    # Test 9: Check compliance tags
    print_section("Test 9: Compliance Tagging")
    
    # Medical documents PHI tag
    phi_tag = check_compliance_tags(s3_content, 'medical_documents', 'DataClassification', 'PHI')
    print_result(phi_tag, "PHI data classification tag exists for medical documents bucket")
    
    # Medical documents compliance tag
    compliance_tag = check_compliance_tags(s3_content, 'medical_documents', 'Compliance', 'HIPAA-DPDP')
    print_result(compliance_tag, "Compliance tag exists for medical documents bucket")
    
    # Audit logs compliance tag
    audit_compliance_tag = check_compliance_tags(s3_content, 'audit_logs', 'Compliance', 'HIPAA-DPDP')
    print_result(audit_compliance_tag, "Compliance tag exists for audit logs bucket")
    
    # Test 10: Check bucket key enablement
    print_section("Test 10: Bucket Key Configuration (Cost Optimization)")
    
    for bucket in versioned_buckets:
        bucket_key = check_bucket_key_enabled(s3_content, bucket)
        print_result(bucket_key, f"Bucket key enabled for {bucket} bucket")
    
    # Test 11: Check outputs
    print_section("Test 11: Terraform Outputs")
    
    required_outputs = [
        's3_medical_documents_bucket_id',
        's3_medical_documents_bucket_arn',
        's3_frontend_assets_bucket_id',
        's3_frontend_assets_bucket_arn',
        's3_audit_logs_bucket_id',
        's3_audit_logs_bucket_arn',
        's3_access_logs_bucket_id',
        's3_access_logs_bucket_arn'
    ]
    
    for output in required_outputs:
        output_exists = f'output "{output}"' in outputs_content
        print_result(output_exists, f"Output {output} is defined")
    
    # Final summary
    print_section("Test Summary")
    total_tests = tests_passed + tests_failed
    print(f"Total tests: {total_tests}")
    print(f"{GREEN}Passed: {tests_passed}{NC}")
    print(f"{RED}Failed: {tests_failed}{NC}")
    print()
    
    if tests_failed == 0:
        print(f"{GREEN}{'='*50}")
        print("All tests passed! ✓")
        print(f"{'='*50}{NC}")
        return 0
    else:
        print(f"{RED}{'='*50}")
        print("Some tests failed. Please review the output above.")
        print(f"{'='*50}{NC}")
        return 1

if __name__ == '__main__':
    sys.exit(main())
