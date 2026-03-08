#!/bin/bash

# Lambda Deployment Script
# Packages Lambda functions for deployment

set -e

echo "=========================================="
echo "Lambda Function Deployment Script"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    print_error "Node.js is not installed. Please install Node.js 20.x"
    exit 1
fi

print_success "Node.js version: $(node --version)"

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    print_error "npm is not installed. Please install npm"
    exit 1
fi

print_success "npm version: $(npm --version)"

echo ""
echo "=========================================="
echo "Packaging JWT Authorizer Lambda"
echo "=========================================="
echo ""

cd authorizer

# Install dependencies
echo "Installing dependencies..."
npm install --production

# Run tests (optional)
if [ "$1" != "--skip-tests" ]; then
    echo "Running tests..."
    npm install --save-dev
    npm test || print_warning "Tests failed, but continuing with deployment"
fi

# Create deployment package
echo "Creating deployment package..."
if [ -f authorizer.zip ]; then
    rm authorizer.zip
fi

zip -r authorizer.zip index.js node_modules/ > /dev/null

print_success "Created authorizer.zip ($(du -h authorizer.zip | cut -f1))"

cd ..

echo ""
echo "=========================================="
echo "Packaging Token Refresh Lambda"
echo "=========================================="
echo ""

cd token-refresh

# Install dependencies
echo "Installing dependencies..."
npm install --production

# Run tests (optional)
if [ "$1" != "--skip-tests" ]; then
    echo "Running tests..."
    npm install --save-dev
    npm test || print_warning "Tests failed, but continuing with deployment"
fi

# Create deployment package
echo "Creating deployment package..."
if [ -f token-refresh.zip ]; then
    rm token-refresh.zip
fi

zip -r token-refresh.zip index.js node_modules/ > /dev/null

print_success "Created token-refresh.zip ($(du -h token-refresh.zip | cut -f1))"

cd ..

echo ""
echo "=========================================="
echo "Deployment Summary"
echo "=========================================="
echo ""

print_success "JWT Authorizer: authorizer/authorizer.zip"
print_success "Token Refresh: token-refresh/token-refresh.zip"

echo ""
echo "Next steps:"
echo "1. Run 'terraform apply' to deploy the Lambda functions"
echo "2. Configure API Gateway to use the JWT authorizer"
echo "3. Test the token refresh endpoint"
echo ""

print_success "Lambda functions packaged successfully!"
