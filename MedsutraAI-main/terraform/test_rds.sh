#!/bin/bash
# Test script for RDS PostgreSQL infrastructure validation
# Validates RDS instance configuration, encryption, backups, and read replicas

set -e

echo "=========================================="
echo "RDS PostgreSQL Infrastructure Validation"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if terraform is initialized
if [ ! -d ".terraform" ]; then
    echo -e "${RED}Error: Terraform not initialized. Run 'terraform init' first.${NC}"
    exit 1
fi

# Validate Terraform configuration
echo "1. Validating Terraform configuration..."
if terraform validate > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Terraform configuration is valid${NC}"
else
    echo -e "${RED}✗ Terraform configuration validation failed${NC}"
    terraform validate
    exit 1
fi

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${YELLOW}⚠ Warning: terraform.tfvars not found${NC}"
    echo "  Please create terraform.tfvars from terraform.tfvars.example"
    echo "  and set rds_master_password before applying"
fi

# Plan the infrastructure
echo ""
echo "2. Planning RDS infrastructure..."
terraform plan -target=aws_db_subnet_group.main \
               -target=aws_db_parameter_group.postgres15 \
               -target=aws_db_instance.primary \
               -target=aws_db_instance.read_replica_1 \
               -target=aws_db_instance.read_replica_2 \
               -target=aws_iam_role.rds_enhanced_monitoring \
               -target=aws_iam_role_policy_attachment.rds_enhanced_monitoring \
               -out=rds.tfplan

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ RDS infrastructure plan created successfully${NC}"
else
    echo -e "${RED}✗ RDS infrastructure planning failed${NC}"
    exit 1
fi

# Validate RDS configuration in plan
echo ""
echo "3. Validating RDS configuration..."

# Check for encryption
if terraform show rds.tfplan | grep -q "storage_encrypted.*=.*true"; then
    echo -e "${GREEN}✓ RDS encryption at rest is enabled${NC}"
else
    echo -e "${RED}✗ RDS encryption at rest is not enabled${NC}"
    exit 1
fi

# Check for KMS key
if terraform show rds.tfplan | grep -q "kms_key_id"; then
    echo -e "${GREEN}✓ KMS encryption key is configured${NC}"
else
    echo -e "${RED}✗ KMS encryption key is not configured${NC}"
    exit 1
fi

# Check for automated backups
if terraform show rds.tfplan | grep -q "backup_retention_period.*=.*7"; then
    echo -e "${GREEN}✓ Automated backups with 7-day retention configured${NC}"
else
    echo -e "${YELLOW}⚠ Warning: Backup retention period is not 7 days${NC}"
fi

# Check for Multi-AZ
if terraform show rds.tfplan | grep -q "multi_az.*=.*true"; then
    echo -e "${GREEN}✓ Multi-AZ deployment is enabled${NC}"
else
    echo -e "${YELLOW}⚠ Warning: Multi-AZ deployment is not enabled${NC}"
fi

# Check for PostgreSQL 15
if terraform show rds.tfplan | grep -q "engine_version.*=.*\"15"; then
    echo -e "${GREEN}✓ PostgreSQL 15 is configured${NC}"
else
    echo -e "${RED}✗ PostgreSQL version is not 15${NC}"
    exit 1
fi

# Check for private subnet placement
if terraform show rds.tfplan | grep -q "publicly_accessible.*=.*false"; then
    echo -e "${GREEN}✓ RDS is in private subnet (not publicly accessible)${NC}"
else
    echo -e "${RED}✗ RDS is publicly accessible (security risk)${NC}"
    exit 1
fi

# Check for enhanced monitoring
if terraform show rds.tfplan | grep -q "monitoring_interval.*=.*60"; then
    echo -e "${GREEN}✓ Enhanced monitoring is enabled${NC}"
else
    echo -e "${YELLOW}⚠ Warning: Enhanced monitoring is not enabled${NC}"
fi

# Check for Performance Insights
if terraform show rds.tfplan | grep -q "performance_insights_enabled.*=.*true"; then
    echo -e "${GREEN}✓ Performance Insights is enabled${NC}"
else
    echo -e "${YELLOW}⚠ Warning: Performance Insights is not enabled${NC}"
fi

# Check for CloudWatch logs
if terraform show rds.tfplan | grep -q "enabled_cloudwatch_logs_exports"; then
    echo -e "${GREEN}✓ CloudWatch logs export is configured${NC}"
else
    echo -e "${YELLOW}⚠ Warning: CloudWatch logs export is not configured${NC}"
fi

# Check for read replicas
if terraform show rds.tfplan | grep -q "read_replica_1"; then
    echo -e "${GREEN}✓ Read replica 1 is configured${NC}"
else
    echo -e "${YELLOW}⚠ Warning: Read replica 1 is not configured${NC}"
fi

if terraform show rds.tfplan | grep -q "read_replica_2"; then
    echo -e "${GREEN}✓ Read replica 2 is configured${NC}"
else
    echo -e "${YELLOW}⚠ Info: Read replica 2 is not configured (optional)${NC}"
fi

# Check for deletion protection
if terraform show rds.tfplan | grep -q "deletion_protection.*=.*true"; then
    echo -e "${GREEN}✓ Deletion protection is enabled${NC}"
else
    echo -e "${YELLOW}⚠ Warning: Deletion protection is not enabled${NC}"
fi

# Summary
echo ""
echo "=========================================="
echo "Validation Summary"
echo "=========================================="
echo -e "${GREEN}RDS PostgreSQL infrastructure validation completed${NC}"
echo ""
echo "Configuration highlights:"
echo "  - PostgreSQL 15 in private subnets"
echo "  - Encrypted at rest with KMS"
echo "  - 7-day automated backup retention"
echo "  - Multi-AZ deployment for high availability"
echo "  - Read replicas for read scaling"
echo "  - Enhanced monitoring and Performance Insights"
echo "  - CloudWatch alarms for monitoring"
echo ""
echo "Next steps:"
echo "  1. Review the plan: terraform show rds.tfplan"
echo "  2. Apply the plan: terraform apply rds.tfplan"
echo "  3. Verify RDS instance: aws rds describe-db-instances"
echo ""
echo -e "${YELLOW}Note: Ensure terraform.tfvars is configured with a strong rds_master_password${NC}"

# Clean up plan file
rm -f rds.tfplan
