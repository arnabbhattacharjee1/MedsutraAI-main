#!/bin/bash
# Validation script for Terraform configuration

set -e

echo "==================================="
echo "Terraform Configuration Validation"
echo "==================================="
echo ""

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "❌ ERROR: Terraform is not installed"
    echo "   Please install Terraform 1.5.0 or higher"
    exit 1
fi

echo "✓ Terraform is installed"
terraform version
echo ""

# Check Terraform version
TERRAFORM_VERSION=$(terraform version -json | grep -o '"terraform_version":"[^"]*' | cut -d'"' -f4)
REQUIRED_VERSION="1.5.0"

if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$TERRAFORM_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
    echo "❌ ERROR: Terraform version $TERRAFORM_VERSION is below required version $REQUIRED_VERSION"
    exit 1
fi

echo "✓ Terraform version meets requirements"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "⚠️  WARNING: AWS CLI is not installed"
    echo "   AWS CLI is recommended for managing AWS resources"
else
    echo "✓ AWS CLI is installed"
    aws --version
fi
echo ""

# Check if configuration files exist
if [ ! -f "terraform.tfvars" ]; then
    echo "⚠️  WARNING: terraform.tfvars not found"
    echo "   Copy terraform.tfvars.example to terraform.tfvars and customize"
else
    echo "✓ terraform.tfvars exists"
fi
echo ""

if [ ! -f "backend.tfvars" ]; then
    echo "⚠️  WARNING: backend.tfvars not found"
    echo "   Copy backend.tfvars.example to backend.tfvars and customize"
else
    echo "✓ backend.tfvars exists"
fi
echo ""

# Validate Terraform configuration
echo "Validating Terraform configuration..."
terraform init -backend=false > /dev/null 2>&1
terraform validate

if [ $? -eq 0 ]; then
    echo "✓ Terraform configuration is valid"
else
    echo "❌ ERROR: Terraform configuration validation failed"
    exit 1
fi
echo ""

# Format check
echo "Checking Terraform formatting..."
terraform fmt -check -recursive

if [ $? -eq 0 ]; then
    echo "✓ Terraform files are properly formatted"
else
    echo "⚠️  WARNING: Some Terraform files need formatting"
    echo "   Run 'terraform fmt -recursive' to fix"
fi
echo ""

echo "==================================="
echo "Validation Complete!"
echo "==================================="
echo ""
echo "Next steps:"
echo "1. Ensure terraform.tfvars and backend.tfvars are configured"
echo "2. Create S3 bucket and DynamoDB table for state backend"
echo "3. Run: terraform init -backend-config=backend.tfvars"
echo "4. Run: terraform plan"
echo "5. Run: terraform apply"
