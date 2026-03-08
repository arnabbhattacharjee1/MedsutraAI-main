#!/bin/bash
# Test script for KMS configuration validation
# Validates KMS key creation, rotation settings, and key policies

set -e

echo "=========================================="
echo "KMS Configuration Validation"
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

echo "Test 1: Validate Terraform syntax for kms.tf"
if terraform validate > /dev/null 2>&1; then
    print_result 0 "Terraform configuration is valid"
else
    print_result 1 "Terraform configuration has syntax errors"
    terraform validate
fi

echo ""
echo "Test 2: Check KMS key resources are defined"
if grep -q "resource \"aws_kms_key\" \"s3_encryption\"" kms.tf; then
    print_result 0 "S3 KMS key resource is defined"
else
    print_result 1 "S3 KMS key resource is missing"
fi

if grep -q "resource \"aws_kms_key\" \"rds_encryption\"" kms.tf; then
    print_result 0 "RDS KMS key resource is defined"
else
    print_result 1 "RDS KMS key resource is missing"
fi

if grep -q "resource \"aws_kms_key\" \"dynamodb_encryption\"" kms.tf; then
    print_result 0 "DynamoDB KMS key resource is defined"
else
    print_result 1 "DynamoDB KMS key resource is missing"
fi

echo ""
echo "Test 3: Verify automatic key rotation is enabled"
S3_ROTATION=$(grep -A 5 "resource \"aws_kms_key\" \"s3_encryption\"" kms.tf | grep "enable_key_rotation" | grep "true" || echo "")
if [ -n "$S3_ROTATION" ]; then
    print_result 0 "S3 KMS key has automatic rotation enabled"
else
    print_result 1 "S3 KMS key does not have automatic rotation enabled"
fi

RDS_ROTATION=$(grep -A 5 "resource \"aws_kms_key\" \"rds_encryption\"" kms.tf | grep "enable_key_rotation" | grep "true" || echo "")
if [ -n "$RDS_ROTATION" ]; then
    print_result 0 "RDS KMS key has automatic rotation enabled"
else
    print_result 1 "RDS KMS key does not have automatic rotation enabled"
fi

DYNAMODB_ROTATION=$(grep -A 5 "resource \"aws_kms_key\" \"dynamodb_encryption\"" kms.tf | grep "enable_key_rotation" | grep "true" || echo "")
if [ -n "$DYNAMODB_ROTATION" ]; then
    print_result 0 "DynamoDB KMS key has automatic rotation enabled"
else
    print_result 1 "DynamoDB KMS key does not have automatic rotation enabled"
fi

echo ""
echo "Test 4: Verify KMS key aliases are defined"
if grep -q "resource \"aws_kms_alias\" \"s3_encryption\"" kms.tf; then
    print_result 0 "S3 KMS key alias is defined"
else
    print_result 1 "S3 KMS key alias is missing"
fi

if grep -q "resource \"aws_kms_alias\" \"rds_encryption\"" kms.tf; then
    print_result 0 "RDS KMS key alias is defined"
else
    print_result 1 "RDS KMS key alias is missing"
fi

if grep -q "resource \"aws_kms_alias\" \"dynamodb_encryption\"" kms.tf; then
    print_result 0 "DynamoDB KMS key alias is defined"
else
    print_result 1 "DynamoDB KMS key alias is missing"
fi

echo ""
echo "Test 5: Verify KMS key policies are defined"
if grep -q "resource \"aws_kms_key_policy\" \"s3_encryption\"" kms.tf; then
    print_result 0 "S3 KMS key policy is defined"
else
    print_result 1 "S3 KMS key policy is missing"
fi

if grep -q "resource \"aws_kms_key_policy\" \"rds_encryption\"" kms.tf; then
    print_result 0 "RDS KMS key policy is defined"
else
    print_result 1 "RDS KMS key policy is missing"
fi

if grep -q "resource \"aws_kms_key_policy\" \"dynamodb_encryption\"" kms.tf; then
    print_result 0 "DynamoDB KMS key policy is defined"
else
    print_result 1 "DynamoDB KMS key policy is missing"
fi

echo ""
echo "Test 6: Verify deletion window is configured"
DELETION_WINDOWS=$(grep "deletion_window_in_days" kms.tf | wc -l)
if [ "$DELETION_WINDOWS" -eq 3 ]; then
    print_result 0 "All KMS keys have deletion window configured"
else
    print_result 1 "Not all KMS keys have deletion window configured (found $DELETION_WINDOWS, expected 3)"
fi

echo ""
echo "Test 7: Verify service-specific permissions in key policies"
if grep -q "s3.amazonaws.com" kms.tf; then
    print_result 0 "S3 service permissions are configured in key policy"
else
    print_result 1 "S3 service permissions are missing from key policy"
fi

if grep -q "rds.amazonaws.com" kms.tf; then
    print_result 0 "RDS service permissions are configured in key policy"
else
    print_result 1 "RDS service permissions are missing from key policy"
fi

if grep -q "dynamodb.amazonaws.com" kms.tf; then
    print_result 0 "DynamoDB service permissions are configured in key policy"
else
    print_result 1 "DynamoDB service permissions are missing from key policy"
fi

echo ""
echo "Test 8: Verify data classification tags"
if grep -q "DataClassification.*PHI" kms.tf; then
    print_result 0 "PHI data classification tags are present"
else
    print_result 1 "PHI data classification tags are missing"
fi

echo ""
echo "Test 9: Verify KMS outputs are defined"
if grep -q "output \"kms_s3_key_arn\"" outputs.tf; then
    print_result 0 "S3 KMS key outputs are defined"
else
    print_result 1 "S3 KMS key outputs are missing"
fi

if grep -q "output \"kms_rds_key_arn\"" outputs.tf; then
    print_result 0 "RDS KMS key outputs are defined"
else
    print_result 1 "RDS KMS key outputs are missing"
fi

if grep -q "output \"kms_dynamodb_key_arn\"" outputs.tf; then
    print_result 0 "DynamoDB KMS key outputs are defined"
else
    print_result 1 "DynamoDB KMS key outputs are missing"
fi

echo ""
echo "Test 10: Verify AWS caller identity data source"
if grep -q "data \"aws_caller_identity\" \"current\"" kms.tf; then
    print_result 0 "AWS caller identity data source is defined"
else
    print_result 1 "AWS caller identity data source is missing"
fi

echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "Tests Passed: ${GREEN}${TESTS_PASSED}${NC}"
echo -e "Tests Failed: ${RED}${TESTS_FAILED}${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed. Please review the configuration.${NC}"
    exit 1
fi
