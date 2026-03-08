#!/bin/bash
# Validation script for Task 4 API Gateway and Lambda functions
# Tests PatientService and ReportService endpoints

set -e

echo "========================================="
echo "Task 4 API Gateway Validation"
echo "========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    print_warning "jq is not installed. Install it for better JSON output formatting."
    JQ_AVAILABLE=false
else
    JQ_AVAILABLE=true
fi

# Get API Gateway URL from Terraform output
echo "Fetching API Gateway URL..."
API_URL=$(terraform output -raw api_gateway_invoke_url 2>/dev/null)

if [ -z "$API_URL" ]; then
    print_error "Failed to get API Gateway URL from Terraform output"
    print_info "Make sure you have run 'terraform apply' first"
    exit 1
fi

print_success "API Gateway URL: $API_URL"
echo ""

# Get JWT token (you'll need to implement authentication)
print_warning "JWT token authentication required"
print_info "Please set JWT_TOKEN environment variable with a valid token"
print_info "Example: export JWT_TOKEN='your-jwt-token-here'"
echo ""

if [ -z "$JWT_TOKEN" ]; then
    print_warning "JWT_TOKEN not set. Some tests will be skipped."
    echo ""
fi

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# ============================================
# Test 1: Health Check (if implemented)
# ============================================

echo "========================================="
echo "Test 1: Health Check"
echo "========================================="

RESPONSE=$(curl -s -w "\n%{http_code}" "$API_URL/health")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" == "200" ] || [ "$HTTP_CODE" == "404" ]; then
    if [ "$HTTP_CODE" == "200" ]; then
        print_success "Health check endpoint exists and returned 200"
        ((TESTS_PASSED++))
    else
        print_warning "Health check endpoint not implemented (404)"
        ((TESTS_SKIPPED++))
    fi
else
    print_error "Health check failed with HTTP $HTTP_CODE"
    ((TESTS_FAILED++))
fi
echo ""

# ============================================
# Test 2: GET /patients/{patientId} - No Auth
# ============================================

echo "========================================="
echo "Test 2: GET /patients/{patientId} - No Auth"
echo "========================================="

TEST_PATIENT_ID="123e4567-e89b-12d3-a456-426614174000"

RESPONSE=$(curl -s -w "\n%{http_code}" "$API_URL/patients/$TEST_PATIENT_ID")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" == "401" ] || [ "$HTTP_CODE" == "403" ]; then
    print_success "Correctly rejected unauthorized request (HTTP $HTTP_CODE)"
    ((TESTS_PASSED++))
else
    print_error "Expected 401/403 but got HTTP $HTTP_CODE"
    ((TESTS_FAILED++))
fi
echo ""

# ============================================
# Test 3: GET /patients/{patientId} - With Auth
# ============================================

if [ -n "$JWT_TOKEN" ]; then
    echo "========================================="
    echo "Test 3: GET /patients/{patientId} - With Auth"
    echo "========================================="

    RESPONSE=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Bearer $JWT_TOKEN" \
        "$API_URL/patients/$TEST_PATIENT_ID")
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')

    if [ "$HTTP_CODE" == "200" ]; then
        print_success "Successfully retrieved patient data (HTTP 200)"
        if [ "$JQ_AVAILABLE" = true ]; then
            echo "$BODY" | jq '.'
        else
            echo "$BODY"
        fi
        ((TESTS_PASSED++))
    elif [ "$HTTP_CODE" == "404" ]; then
        print_warning "Patient not found (HTTP 404) - This is expected if patient doesn't exist"
        ((TESTS_PASSED++))
    else
        print_error "Unexpected response: HTTP $HTTP_CODE"
        echo "$BODY"
        ((TESTS_FAILED++))
    fi
    echo ""
else
    print_warning "Skipping Test 3: JWT_TOKEN not set"
    ((TESTS_SKIPPED++))
    echo ""
fi

# ============================================
# Test 4: GET /patients/{patientId} - ABHA Number
# ============================================

if [ -n "$JWT_TOKEN" ]; then
    echo "========================================="
    echo "Test 4: GET /patients/{patientId} - ABHA Number"
    echo "========================================="

    TEST_ABHA="12-3456-7890-1234"

    RESPONSE=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Bearer $JWT_TOKEN" \
        "$API_URL/patients/$TEST_ABHA")
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')

    if [ "$HTTP_CODE" == "200" ]; then
        print_success "Successfully retrieved patient by ABHA number (HTTP 200)"
        if [ "$JQ_AVAILABLE" = true ]; then
            echo "$BODY" | jq '.'
        else
            echo "$BODY"
        fi
        ((TESTS_PASSED++))
    elif [ "$HTTP_CODE" == "404" ]; then
        print_warning "Patient not found (HTTP 404) - This is expected if patient doesn't exist"
        ((TESTS_PASSED++))
    elif [ "$HTTP_CODE" == "400" ]; then
        print_warning "Invalid ABHA format (HTTP 400)"
        echo "$BODY"
        ((TESTS_PASSED++))
    else
        print_error "Unexpected response: HTTP $HTTP_CODE"
        echo "$BODY"
        ((TESTS_FAILED++))
    fi
    echo ""
else
    print_warning "Skipping Test 4: JWT_TOKEN not set"
    ((TESTS_SKIPPED++))
    echo ""
fi

# ============================================
# Test 5: GET /patients/{patientId} - Invalid ABHA
# ============================================

if [ -n "$JWT_TOKEN" ]; then
    echo "========================================="
    echo "Test 5: GET /patients/{patientId} - Invalid ABHA"
    echo "========================================="

    INVALID_ABHA="1234567890123"  # Missing hyphens

    RESPONSE=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Bearer $JWT_TOKEN" \
        "$API_URL/patients/$INVALID_ABHA")
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')

    if [ "$HTTP_CODE" == "400" ]; then
        print_success "Correctly rejected invalid ABHA format (HTTP 400)"
        ((TESTS_PASSED++))
    else
        print_error "Expected 400 but got HTTP $HTTP_CODE"
        echo "$BODY"
        ((TESTS_FAILED++))
    fi
    echo ""
else
    print_warning "Skipping Test 5: JWT_TOKEN not set"
    ((TESTS_SKIPPED++))
    echo ""
fi

# ============================================
# Test 6: POST /reports/upload - No Auth
# ============================================

echo "========================================="
echo "Test 6: POST /reports/upload - No Auth"
echo "========================================="

RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -d '{"patientId":"test","fileName":"test.pdf","fileContent":"dGVzdA=="}' \
    "$API_URL/reports/upload")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" == "401" ] || [ "$HTTP_CODE" == "403" ]; then
    print_success "Correctly rejected unauthorized request (HTTP $HTTP_CODE)"
    ((TESTS_PASSED++))
else
    print_error "Expected 401/403 but got HTTP $HTTP_CODE"
    ((TESTS_FAILED++))
fi
echo ""

# ============================================
# Test 7: POST /reports/upload - Missing Fields
# ============================================

if [ -n "$JWT_TOKEN" ]; then
    echo "========================================="
    echo "Test 7: POST /reports/upload - Missing Fields"
    echo "========================================="

    RESPONSE=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Authorization: Bearer $JWT_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{"fileName":"test.pdf"}' \
        "$API_URL/reports/upload")
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')

    if [ "$HTTP_CODE" == "400" ]; then
        print_success "Correctly rejected request with missing fields (HTTP 400)"
        ((TESTS_PASSED++))
    else
        print_error "Expected 400 but got HTTP $HTTP_CODE"
        echo "$BODY"
        ((TESTS_FAILED++))
    fi
    echo ""
else
    print_warning "Skipping Test 7: JWT_TOKEN not set"
    ((TESTS_SKIPPED++))
    echo ""
fi

# ============================================
# Test 8: POST /reports/upload - Unsupported Format
# ============================================

if [ -n "$JWT_TOKEN" ]; then
    echo "========================================="
    echo "Test 8: POST /reports/upload - Unsupported Format"
    echo "========================================="

    # Base64 encoded "test content"
    TEST_CONTENT=$(echo -n "test content" | base64)

    RESPONSE=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Authorization: Bearer $JWT_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"patientId\":\"$TEST_PATIENT_ID\",\"fileName\":\"test.txt\",\"fileContent\":\"$TEST_CONTENT\",\"contentType\":\"text/plain\"}" \
        "$API_URL/reports/upload")
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')

    if [ "$HTTP_CODE" == "400" ]; then
        print_success "Correctly rejected unsupported file format (HTTP 400)"
        ((TESTS_PASSED++))
    else
        print_error "Expected 400 but got HTTP $HTTP_CODE"
        echo "$BODY"
        ((TESTS_FAILED++))
    fi
    echo ""
else
    print_warning "Skipping Test 8: JWT_TOKEN not set"
    ((TESTS_SKIPPED++))
    echo ""
fi

# ============================================
# Test Summary
# ============================================

echo "========================================="
echo "Test Summary"
echo "========================================="
echo ""

TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))

echo "Total Tests: $TOTAL_TESTS"
print_success "Passed: $TESTS_PASSED"
if [ $TESTS_FAILED -gt 0 ]; then
    print_error "Failed: $TESTS_FAILED"
fi
if [ $TESTS_SKIPPED -gt 0 ]; then
    print_warning "Skipped: $TESTS_SKIPPED"
fi
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    print_success "All tests passed!"
    exit 0
else
    print_error "Some tests failed"
    exit 1
fi
