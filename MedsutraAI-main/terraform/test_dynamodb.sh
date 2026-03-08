#!/bin/bash
# Test script for DynamoDB tables configuration
# Validates Terraform syntax and configuration for sessions and agent_status tables

set -e

echo "=========================================="
echo "DynamoDB Tables Configuration Test"
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

# Test 1: Validate Terraform syntax
echo "Test 1: Validating Terraform syntax..."
terraform fmt -check dynamodb.tf > /dev/null 2>&1
print_result $? "Terraform syntax validation"
echo ""

# Test 2: Validate Python syntax for validation script
echo "Test 2: Validating Python syntax..."
python3 -m py_compile validate_dynamodb.py > /dev/null 2>&1
print_result $? "Python syntax validation"
echo ""

# Test 3: Run Python validation script
echo "Test 3: Running DynamoDB configuration validation..."
python3 validate_dynamodb.py
if [ $? -eq 0 ]; then
    print_result 0 "DynamoDB configuration validation"
else
    print_result 1 "DynamoDB configuration validation"
fi
echo ""

# Test 4: Check for required resources
echo "Test 4: Checking for required DynamoDB resources..."
REQUIRED_RESOURCES=(
    "aws_dynamodb_table.sessions"
    "aws_dynamodb_table.agent_status"
)

ALL_FOUND=true
for resource in "${REQUIRED_RESOURCES[@]}"; do
    if grep -q "resource \"${resource%.*}\" \"${resource#*.}\"" dynamodb.tf; then
        echo -e "  ${GREEN}✓${NC} Found: $resource"
    else
        echo -e "  ${RED}✗${NC} Missing: $resource"
        ALL_FOUND=false
    fi
done

if [ "$ALL_FOUND" = true ]; then
    print_result 0 "All required DynamoDB resources present"
else
    print_result 1 "Some required DynamoDB resources missing"
fi
echo ""

# Test 5: Validate encryption configuration
echo "Test 5: Validating encryption configuration..."
if grep -q "server_side_encryption" dynamodb.tf && \
   grep -q "kms_key_arn = aws_kms_key.dynamodb_encryption.arn" dynamodb.tf; then
    print_result 0 "Encryption with KMS configured correctly"
else
    print_result 1 "Encryption configuration missing or incorrect"
fi
echo ""

# Test 6: Validate TTL configuration
echo "Test 6: Validating TTL configuration..."
TTL_COUNT=$(grep -c "ttl {" dynamodb.tf)
if [ "$TTL_COUNT" -eq 2 ]; then
    print_result 0 "TTL configured for both tables"
else
    print_result 1 "TTL configuration missing or incorrect (found $TTL_COUNT, expected 2)"
fi
echo ""

# Test 7: Validate billing mode
echo "Test 7: Validating billing mode (on-demand)..."
BILLING_MODE_COUNT=$(grep -c "billing_mode.*=.*\"PAY_PER_REQUEST\"" dynamodb.tf)
if [ "$BILLING_MODE_COUNT" -eq 2 ]; then
    print_result 0 "On-demand billing mode configured for both tables"
else
    print_result 1 "Billing mode configuration incorrect (found $BILLING_MODE_COUNT, expected 2)"
fi
echo ""

# Test 8: Validate DynamoDB Streams for agent_status
echo "Test 8: Validating DynamoDB Streams configuration..."
if grep -q "stream_enabled.*=.*true" dynamodb.tf && \
   grep -q "stream_view_type.*=.*\"NEW_AND_OLD_IMAGES\"" dynamodb.tf; then
    print_result 0 "DynamoDB Streams configured for agent_status table"
else
    print_result 1 "DynamoDB Streams configuration missing or incorrect"
fi
echo ""

# Test 9: Validate Global Secondary Indexes
echo "Test 9: Validating Global Secondary Indexes..."
GSI_COUNT=$(grep -c "global_secondary_index {" dynamodb.tf)
if [ "$GSI_COUNT" -ge 3 ]; then
    print_result 0 "Global Secondary Indexes configured (found $GSI_COUNT)"
else
    print_result 1 "Insufficient Global Secondary Indexes (found $GSI_COUNT, expected at least 3)"
fi
echo ""

# Test 10: Validate point-in-time recovery
echo "Test 10: Validating point-in-time recovery..."
PITR_COUNT=$(grep -c "point_in_time_recovery {" dynamodb.tf)
if [ "$PITR_COUNT" -eq 2 ]; then
    print_result 0 "Point-in-time recovery enabled for both tables"
else
    print_result 1 "Point-in-time recovery configuration incorrect (found $PITR_COUNT, expected 2)"
fi
echo ""

# Summary
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Review the DynamoDB configuration in dynamodb.tf"
    echo "2. Run 'terraform plan' to preview the changes"
    echo "3. Run 'terraform apply' to create the DynamoDB tables"
    echo "4. Verify the tables in AWS Console"
    exit 0
else
    echo -e "${RED}Some tests failed. Please review the configuration.${NC}"
    exit 1
fi
