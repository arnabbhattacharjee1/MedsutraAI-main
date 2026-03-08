#!/bin/bash
# Test script for security groups and network ACLs configuration
# Validates Terraform configuration without applying changes

set -e

echo "=========================================="
echo "Security Groups & Network ACLs Test"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}ERROR: Terraform is not installed${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 1: Initializing Terraform...${NC}"
terraform init -upgrade

echo ""
echo -e "${YELLOW}Step 2: Validating Terraform configuration...${NC}"
terraform validate

echo ""
echo -e "${YELLOW}Step 3: Formatting check...${NC}"
terraform fmt -check -recursive || {
    echo -e "${YELLOW}Formatting issues found. Auto-formatting...${NC}"
    terraform fmt -recursive
}

echo ""
echo -e "${YELLOW}Step 4: Planning infrastructure (security groups & NACLs)...${NC}"
terraform plan -out=tfplan

echo ""
echo -e "${GREEN}✓ Validation successful!${NC}"
echo ""
echo "Summary of Security Groups to be created:"
echo "  - EKS Cluster Security Group"
echo "  - EKS Nodes Security Group (with inter-pod communication)"
echo "  - RDS Security Group (Lambda and EKS access only)"
echo "  - Lambda Security Group (outbound to required services)"
echo "  - ALB Security Group"
echo "  - Redis Security Group"
echo ""
echo "Summary of Network ACLs to be created:"
echo "  - Public Subnet NACL (HTTP/HTTPS from internet)"
echo "  - Private Subnet NACL (VPC internal + NAT gateway traffic)"
echo ""
echo -e "${YELLOW}To apply these changes, run:${NC}"
echo "  terraform apply tfplan"
echo ""
echo -e "${YELLOW}To destroy the plan without applying:${NC}"
echo "  rm tfplan"
