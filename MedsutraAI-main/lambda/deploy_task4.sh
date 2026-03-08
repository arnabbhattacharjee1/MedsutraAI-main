#!/bin/bash
# Deployment script for Task 4 Lambda functions
# PatientService (Node.js) and ReportService (Python)

set -e

echo "========================================="
echo "Task 4 Lambda Functions Deployment"
echo "========================================="
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

# Check if required tools are installed
echo "Checking prerequisites..."

if ! command -v node &> /dev/null; then
    print_error "Node.js is not installed"
    exit 1
fi
print_success "Node.js found: $(node --version)"

if ! command -v npm &> /dev/null; then
    print_error "npm is not installed"
    exit 1
fi
print_success "npm found: $(npm --version)"

if ! command -v python3 &> /dev/null; then
    print_error "Python 3 is not installed"
    exit 1
fi
print_success "Python 3 found: $(python3 --version)"

if ! command -v pip3 &> /dev/null; then
    print_error "pip3 is not installed"
    exit 1
fi
print_success "pip3 found"

echo ""

# ============================================
# PatientService (Node.js 20)
# ============================================

echo "========================================="
echo "Building PatientService Lambda (Node.js)"
echo "========================================="
echo ""

cd patient-service

echo "Installing dependencies..."
npm install --production
print_success "Dependencies installed"

echo "Running tests..."
npm test
if [ $? -eq 0 ]; then
    print_success "Tests passed"
else
    print_error "Tests failed"
    exit 1
fi

echo "Creating deployment package..."
if [ -f patient-service.zip ]; then
    rm patient-service.zip
fi

zip -r patient-service.zip index.js node_modules package.json > /dev/null 2>&1
print_success "Deployment package created: patient-service.zip"

echo "Package size: $(du -h patient-service.zip | cut -f1)"
echo ""

cd ..

# ============================================
# ReportService (Python 3.11)
# ============================================

echo "========================================="
echo "Building ReportService Lambda (Python)"
echo "========================================="
echo ""

cd report-service

echo "Installing dependencies..."
pip3 install -r requirements.txt -t package/ --upgrade > /dev/null 2>&1
print_success "Dependencies installed"

echo "Running tests..."
python3 -m pytest test_lambda_function.py -v
if [ $? -eq 0 ]; then
    print_success "Tests passed"
else
    print_error "Tests failed"
    exit 1
fi

echo "Creating deployment package..."
if [ -f report-service.zip ]; then
    rm report-service.zip
fi

# Copy Lambda function to package directory
cp lambda_function.py package/

# Create zip from package directory
cd package
zip -r ../report-service.zip . > /dev/null 2>&1
cd ..

# Clean up package directory
rm -rf package

print_success "Deployment package created: report-service.zip"

echo "Package size: $(du -h report-service.zip | cut -f1)"
echo ""

cd ..

# ============================================
# Summary
# ============================================

echo "========================================="
echo "Deployment Summary"
echo "========================================="
echo ""

print_success "PatientService: patient-service/patient-service.zip"
print_success "ReportService: report-service/report-service.zip"

echo ""
echo "Next steps:"
echo "1. Deploy infrastructure with Terraform:"
echo "   cd ../terraform"
echo "   terraform apply"
echo ""
echo "2. Test API endpoints:"
echo "   ./test_api_gateway.sh"
echo ""

print_success "Build completed successfully!"
