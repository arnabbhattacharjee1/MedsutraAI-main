#!/bin/bash
# Test script for S3 bucket configuration validation
# Validates bucket creation, encryption, versioning, logging, and policies

set -e

echo "=========================================="
echo "S3 Bucket Configuration Validation"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to print test result
print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $2"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: $2"
        ((TESTS_FAILED++))
    fi
}

# Function to print section header
print_section() {
    echo ""
    echo "=========================================="
    echo "$1"
    echo "=========================================="
}

# Test 1: Terraform syntax validation
print_section "Test 1: Terraform Syntax Validation"
if terraform fmt -check s3.tf > /dev/null 2>&1; then
    print_result 0 "Terraform formatting is correct"
else
    echo -e "${YELLOW}⚠ WARNING${NC}: Terraform formatting issues detected, auto-formatting..."
    terraform fmt s3.tf
    print_result 0 "Terraform formatting auto-corrected"
fi

# Test 2: Terraform validation
print_section "Test 2: Terraform Configuration Validation"
if terraform validate > /dev/null 2>&1; then
    print_result 0 "Terraform configuration is valid"
else
    print_result 1 "Terraform configuration validation failed"
    terraform validate
fi

# Test 3: Check for required S3 bucket resources
print_section "Test 3: Required S3 Bucket Resources"

required_buckets=(
    "aws_s3_bucket.medical_documents"
    "aws_s3_bucket.frontend_assets"
    "aws_s3_bucket.audit_logs"
    "aws_s3_bucket.access_logs"
)

for bucket in "${required_buckets[@]}"; do
    if grep -q "resource \"${bucket%.*}\" \"${bucket#*.}\"" s3.tf; then
        print_result 0 "Resource $bucket exists"
    else
        print_result 1 "Resource $bucket is missing"
    fi
done

# Test 4: Check encryption configuration
print_section "Test 4: Encryption Configuration"

# Check medical documents bucket uses KMS
if grep -A 10 "aws_s3_bucket_server_side_encryption_configuration.*medical_documents" s3.tf | grep -q "aws:kms"; then
    print_result 0 "Medical documents bucket uses KMS encryption"
else
    print_result 1 "Medical documents bucket KMS encryption not configured"
fi

# Check KMS key reference
if grep -A 10 "aws_s3_bucket_server_side_encryption_configuration.*medical_documents" s3.tf | grep -q "aws_kms_key.s3_encryption.arn"; then
    print_result 0 "Medical documents bucket references correct KMS key"
else
    print_result 1 "Medical documents bucket KMS key reference incorrect"
fi

# Check frontend assets bucket uses AES256
if grep -A 10 "aws_s3_bucket_server_side_encryption_configuration.*frontend_assets" s3.tf | grep -q "AES256"; then
    print_result 0 "Frontend assets bucket uses AES256 encryption"
else
    print_result 1 "Frontend assets bucket encryption not configured"
fi

# Check audit logs bucket uses AES256
if grep -A 10 "aws_s3_bucket_server_side_encryption_configuration.*audit_logs" s3.tf | grep -q "AES256"; then
    print_result 0 "Audit logs bucket uses AES256 encryption"
else
    print_result 1 "Audit logs bucket encryption not configured"
fi

# Test 5: Check versioning configuration
print_section "Test 5: Versioning Configuration"

versioned_buckets=(
    "medical_documents"
    "frontend_assets"
    "audit_logs"
    "access_logs"
)

for bucket in "${versioned_buckets[@]}"; do
    if grep -A 5 "aws_s3_bucket_versioning.*$bucket" s3.tf | grep -q "status.*=.*\"Enabled\""; then
        print_result 0 "Versioning enabled for $bucket bucket"
    else
        print_result 1 "Versioning not enabled for $bucket bucket"
    fi
done

# Test 6: Check public access block
print_section "Test 6: Public Access Block Configuration"

for bucket in "${versioned_buckets[@]}"; do
    if grep -A 10 "aws_s3_bucket_public_access_block.*$bucket" s3.tf | grep -q "block_public_acls.*=.*true"; then
        print_result 0 "Public access blocked for $bucket bucket"
    else
        print_result 1 "Public access not blocked for $bucket bucket"
    fi
done

# Test 7: Check access logging configuration
print_section "Test 7: Access Logging Configuration"

logged_buckets=(
    "medical_documents"
    "frontend_assets"
    "audit_logs"
)

for bucket in "${logged_buckets[@]}"; do
    if grep -A 5 "aws_s3_bucket_logging.*$bucket" s3.tf | grep -q "target_bucket.*=.*aws_s3_bucket.access_logs.id"; then
        print_result 0 "Access logging configured for $bucket bucket"
    else
        print_result 1 "Access logging not configured for $bucket bucket"
    fi
done

# Test 8: Check bucket policies
print_section "Test 8: Bucket Policy Configuration"

policy_buckets=(
    "medical_documents"
    "frontend_assets"
    "audit_logs"
)

for bucket in "${policy_buckets[@]}"; do
    if grep -q "aws_s3_bucket_policy.*$bucket" s3.tf; then
        print_result 0 "Bucket policy exists for $bucket bucket"
    else
        print_result 1 "Bucket policy missing for $bucket bucket"
    fi
done

# Test 9: Check security policies
print_section "Test 9: Security Policy Validation"

# Check for DenyInsecureTransport in all bucket policies
for bucket in "${policy_buckets[@]}"; do
    if grep -A 50 "aws_s3_bucket_policy.*$bucket" s3.tf | grep -q "DenyInsecureTransport"; then
        print_result 0 "DenyInsecureTransport policy exists for $bucket bucket"
    else
        print_result 1 "DenyInsecureTransport policy missing for $bucket bucket"
    fi
done

# Check for encryption enforcement in medical documents bucket
if grep -A 50 "aws_s3_bucket_policy.*medical_documents" s3.tf | grep -q "DenyUnencryptedObjectUploads"; then
    print_result 0 "Encryption enforcement policy exists for medical documents bucket"
else
    print_result 1 "Encryption enforcement policy missing for medical documents bucket"
fi

# Check for log deletion prevention in audit logs bucket
if grep -A 50 "aws_s3_bucket_policy.*audit_logs" s3.tf | grep -q "PreventLogDeletion"; then
    print_result 0 "Log deletion prevention policy exists for audit logs bucket"
else
    print_result 1 "Log deletion prevention policy missing for audit logs bucket"
fi

# Test 10: Check lifecycle policies
print_section "Test 10: Lifecycle Policy Configuration"

# Check medical documents lifecycle
if grep -A 20 "aws_s3_bucket_lifecycle_configuration.*medical_documents" s3.tf | grep -q "noncurrent_version_expiration"; then
    print_result 0 "Lifecycle policy configured for medical documents bucket"
else
    print_result 1 "Lifecycle policy missing for medical documents bucket"
fi

# Check audit logs lifecycle with 7-year retention
if grep -A 30 "aws_s3_bucket_lifecycle_configuration.*audit_logs" s3.tf | grep -q "2555"; then
    print_result 0 "7-year retention policy configured for audit logs bucket"
else
    print_result 1 "7-year retention policy missing for audit logs bucket"
fi

# Test 11: Check compliance tags
print_section "Test 11: Compliance Tagging"

# Check medical documents bucket has PHI tag
if grep -A 10 "resource \"aws_s3_bucket\" \"medical_documents\"" s3.tf | grep -q "DataClassification.*=.*\"PHI\""; then
    print_result 0 "PHI data classification tag exists for medical documents bucket"
else
    print_result 1 "PHI data classification tag missing for medical documents bucket"
fi

# Check compliance tags
if grep -A 10 "resource \"aws_s3_bucket\" \"medical_documents\"" s3.tf | grep -q "Compliance"; then
    print_result 0 "Compliance tag exists for medical documents bucket"
else
    print_result 1 "Compliance tag missing for medical documents bucket"
fi

# Test 12: Check bucket key enablement for cost optimization
print_section "Test 12: Bucket Key Configuration"

for bucket in "${versioned_buckets[@]}"; do
    if grep -A 10 "aws_s3_bucket_server_side_encryption_configuration.*$bucket" s3.tf | grep -q "bucket_key_enabled.*=.*true"; then
        print_result 0 "Bucket key enabled for $bucket bucket (cost optimization)"
    else
        print_result 1 "Bucket key not enabled for $bucket bucket"
    fi
done

# Test 13: Check outputs are defined
print_section "Test 13: Terraform Outputs"

required_outputs=(
    "s3_medical_documents_bucket_id"
    "s3_medical_documents_bucket_arn"
    "s3_frontend_assets_bucket_id"
    "s3_frontend_assets_bucket_arn"
    "s3_audit_logs_bucket_id"
    "s3_audit_logs_bucket_arn"
    "s3_access_logs_bucket_id"
    "s3_access_logs_bucket_arn"
)

for output in "${required_outputs[@]}"; do
    if grep -q "output \"$output\"" outputs.tf; then
        print_result 0 "Output $output is defined"
    else
        print_result 1 "Output $output is missing"
    fi
done

# Final summary
print_section "Test Summary"
TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED))
echo "Total tests: $TOTAL_TESTS"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}=========================================="
    echo "All tests passed! ✓"
    echo -e "==========================================${NC}"
    exit 0
else
    echo -e "${RED}=========================================="
    echo "Some tests failed. Please review the output above."
    echo -e "==========================================${NC}"
    exit 1
fi
