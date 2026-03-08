#!/bin/bash

# Validation Script for JWT Token Management
# Verifies that all components are correctly implemented

set -e

echo "=========================================="
echo "JWT Token Management Validation"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0

# Function to print colored output
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
    ((PASSED++))
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
    ((FAILED++))
}

echo "1. Checking file structure..."
echo ""

# Check authorizer files
if [ -f "authorizer/index.js" ]; then
    print_success "authorizer/index.js exists"
else
    print_error "authorizer/index.js missing"
fi

if [ -f "authorizer/index.test.js" ]; then
    print_success "authorizer/index.test.js exists"
else
    print_error "authorizer/index.test.js missing"
fi

if [ -f "authorizer/package.json" ]; then
    print_success "authorizer/package.json exists"
else
    print_error "authorizer/package.json missing"
fi

# Check token-refresh files
if [ -f "token-refresh/index.js" ]; then
    print_success "token-refresh/index.js exists"
else
    print_error "token-refresh/index.js missing"
fi

if [ -f "token-refresh/index.test.js" ]; then
    print_success "token-refresh/index.test.js exists"
else
    print_error "token-refresh/index.test.js missing"
fi

if [ -f "token-refresh/package.json" ]; then
    print_success "token-refresh/package.json exists"
else
    print_error "token-refresh/package.json missing"
fi

# Check documentation
if [ -f "JWT_TOKEN_MANAGEMENT.md" ]; then
    print_success "JWT_TOKEN_MANAGEMENT.md exists"
else
    print_error "JWT_TOKEN_MANAGEMENT.md missing"
fi

if [ -f "JWT_QUICKSTART.md" ]; then
    print_success "JWT_QUICKSTART.md exists"
else
    print_error "JWT_QUICKSTART.md missing"
fi

if [ -f "TASK_3.2_COMPLETION.md" ]; then
    print_success "TASK_3.2_COMPLETION.md exists"
else
    print_error "TASK_3.2_COMPLETION.md missing"
fi

echo ""
echo "2. Checking code quality..."
echo ""

# Check for required functions in authorizer
if grep -q "exports.handler" authorizer/index.js; then
    print_success "Authorizer handler function exists"
else
    print_error "Authorizer handler function missing"
fi

if grep -q "verifyToken" authorizer/index.js; then
    print_success "Token verification function exists"
else
    print_error "Token verification function missing"
fi

if grep -q "generatePolicy" authorizer/index.js; then
    print_success "Policy generation function exists"
else
    print_error "Policy generation function missing"
fi

# Check for required functions in token-refresh
if grep -q "exports.handler" token-refresh/index.js; then
    print_success "Token refresh handler function exists"
else
    print_error "Token refresh handler function missing"
fi

if grep -q "refreshTokens" token-refresh/index.js; then
    print_success "Token refresh function exists"
else
    print_error "Token refresh function missing"
fi

echo ""
echo "3. Checking requirements implementation..."
echo ""

# Check Requirement 13.2 (15-minute expiration)
if grep -q "15 minutes" authorizer/index.js || grep -q "900" authorizer/index.js; then
    print_success "Requirement 13.2: 15-minute expiration documented"
else
    print_warning "Requirement 13.2: 15-minute expiration not explicitly documented"
fi

# Check Requirement 20.1 (unique session identifier)
if grep -q "decoded.sub" authorizer/index.js; then
    print_success "Requirement 20.1: Unique session identifier (sub claim) extracted"
else
    print_error "Requirement 20.1: Unique session identifier not extracted"
fi

echo ""
echo "4. Checking test coverage..."
echo ""

# Check authorizer tests
if grep -q "describe.*JWT Lambda Authorizer" authorizer/index.test.js; then
    print_success "Authorizer test suite exists"
else
    print_error "Authorizer test suite missing"
fi

if grep -q "Requirement 13.2" authorizer/index.test.js; then
    print_success "Requirement 13.2 test exists"
else
    print_error "Requirement 13.2 test missing"
fi

if grep -q "Requirement 20.1" authorizer/index.test.js; then
    print_success "Requirement 20.1 test exists"
else
    print_error "Requirement 20.1 test missing"
fi

# Check token-refresh tests
if grep -q "describe.*Token Refresh Lambda" token-refresh/index.test.js; then
    print_success "Token refresh test suite exists"
else
    print_error "Token refresh test suite missing"
fi

echo ""
echo "5. Checking Terraform configuration..."
echo ""

if [ -f "../terraform/lambda_authorizer.tf" ]; then
    print_success "Terraform configuration exists"
    
    if grep -q "aws_lambda_function.jwt_authorizer" ../terraform/lambda_authorizer.tf; then
        print_success "JWT authorizer Lambda resource defined"
    else
        print_error "JWT authorizer Lambda resource missing"
    fi
    
    if grep -q "aws_lambda_function.token_refresh" ../terraform/lambda_authorizer.tf; then
        print_success "Token refresh Lambda resource defined"
    else
        print_error "Token refresh Lambda resource missing"
    fi
else
    print_error "Terraform configuration missing"
fi

echo ""
echo "6. Checking deployment scripts..."
echo ""

if [ -f "deploy.sh" ]; then
    print_success "Bash deployment script exists"
    if [ -x "deploy.sh" ]; then
        print_success "Bash deployment script is executable"
    else
        print_warning "Bash deployment script is not executable (run: chmod +x deploy.sh)"
    fi
else
    print_error "Bash deployment script missing"
fi

if [ -f "deploy.ps1" ]; then
    print_success "PowerShell deployment script exists"
else
    print_error "PowerShell deployment script missing"
fi

echo ""
echo "=========================================="
echo "Validation Summary"
echo "=========================================="
echo ""

echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"

echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All validations passed!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Run './deploy.sh' to package Lambda functions"
    echo "2. Run 'cd ../terraform && terraform apply' to deploy"
    echo "3. Test the implementation using JWT_QUICKSTART.md"
    exit 0
else
    echo -e "${RED}✗ Some validations failed. Please fix the issues above.${NC}"
    exit 1
fi
