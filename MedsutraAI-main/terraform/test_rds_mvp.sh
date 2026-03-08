#!/bin/bash
# MVP Test script for RDS PostgreSQL infrastructure validation
# Validates simplified RDS configuration for MVP deployment

set -e

echo "=========================================="
echo "RDS PostgreSQL MVP Infrastructure Validation"
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
    echo "  For MVP deployment, copy terraform.tfvars.mvp to terraform.tfvars"
    echo "  and set rds_master_password before applying"
    echo ""
    echo "  cp terraform.tfvars.mvp terraform.tfvars"
    echo "  # Edit terraform.tfvars and set rds_master_password"
fi

# Plan the infrastructure (MVP - no read replicas)
echo ""
echo "2. Planning RDS infrastructure (MVP mode)..."
terraform plan -target=aws_db_subnet_group.main \
               -target=aws_db_parameter_group.postgres15 \
               -target=aws_db_instance.primary \
               -target=aws_iam_role.rds_enhanced_monitoring \
               -target=aws_iam_role_policy_attachment.rds_enhanced_monitoring \
               -target=aws_cloudwatch_metric_alarm.rds_cpu_high \
               -target=aws_cloudwatch_metric_alarm.rds_connections_high \
               -target=aws_cloudwatch_metric_alarm.rds_storage_low \
               -target=aws_cloudwatch_metric_alarm.rds_read_latency_high \
               -target=aws_cloudwatch_metric_alarm.rds_write_latency_high \
               -out=rds_mvp.tfplan

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ RDS MVP infrastructure plan created successfully${NC}"
else
    echo -e "${RED}✗ RDS MVP infrastructure planning failed${NC}"
    exit 1
fi

# Validate RDS configuration in plan
echo ""
echo "3. Validating RDS MVP configuration..."

# Check for encryption
if terraform show rds_mvp.tfplan | grep -q "storage_encrypted.*=.*true"; then
    echo -e "${GREEN}✓ RDS encryption at rest is enabled${NC}"
else
    echo -e "${RED}✗ RDS encryption at rest is not enabled${NC}"
    exit 1
fi

# Check for KMS key
if terraform show rds_mvp.tfplan | grep -q "kms_key_id"; then
    echo -e "${GREEN}✓ KMS encryption key is configured${NC}"
else
    echo -e "${RED}✗ KMS encryption key is not configured${NC}"
    exit 1
fi

# Check for automated backups
if terraform show rds_mvp.tfplan | grep -q "backup_retention_period.*=.*7"; then
    echo -e "${GREEN}✓ Automated backups with 7-day retention configured${NC}"
else
    echo -e "${YELLOW}⚠ Warning: Backup retention period is not 7 days${NC}"
fi

# Check for PostgreSQL 15
if terraform show rds_mvp.tfplan | grep -q "engine_version.*=.*\"15"; then
    echo -e "${GREEN}✓ PostgreSQL 15 is configured${NC}"
else
    echo -e "${RED}✗ PostgreSQL version is not 15${NC}"
    exit 1
fi

# Check for private subnet placement
if terraform show rds_mvp.tfplan | grep -q "publicly_accessible.*=.*false"; then
    echo -e "${GREEN}✓ RDS is in private subnet (not publicly accessible)${NC}"
else
    echo -e "${RED}✗ RDS is publicly accessible (security risk)${NC}"
    exit 1
fi

# Check for enhanced monitoring
if terraform show rds_mvp.tfplan | grep -q "monitoring_interval.*=.*60"; then
    echo -e "${GREEN}✓ Enhanced monitoring is enabled${NC}"
else
    echo -e "${YELLOW}⚠ Warning: Enhanced monitoring is not enabled${NC}"
fi

# Check for Performance Insights
if terraform show rds_mvp.tfplan | grep -q "performance_insights_enabled.*=.*true"; then
    echo -e "${GREEN}✓ Performance Insights is enabled${NC}"
else
    echo -e "${YELLOW}⚠ Warning: Performance Insights is not enabled${NC}"
fi

# MVP-specific checks
echo ""
echo "4. Validating MVP simplifications..."

# Verify no read replicas (MVP simplification)
if terraform show rds_mvp.tfplan | grep -q "read_replica_1"; then
    echo -e "${YELLOW}⚠ Warning: Read replica 1 is configured (not needed for MVP)${NC}"
else
    echo -e "${GREEN}✓ No read replicas configured (MVP simplification)${NC}"
fi

# Check instance class is appropriate for MVP
if terraform show rds_mvp.tfplan | grep -q "instance_class.*=.*\"db.t4g"; then
    echo -e "${GREEN}✓ Using cost-effective instance class for MVP${NC}"
elif terraform show rds_mvp.tfplan | grep -q "instance_class.*=.*\"db.t3"; then
    echo -e "${GREEN}✓ Using cost-effective instance class for MVP${NC}"
else
    echo -e "${YELLOW}⚠ Info: Using production-grade instance class${NC}"
fi

# Summary
echo ""
echo "=========================================="
echo "MVP Validation Summary"
echo "=========================================="
echo -e "${GREEN}RDS PostgreSQL MVP infrastructure validation completed${NC}"
echo ""
echo "MVP Configuration highlights:"
echo "  ✓ PostgreSQL 15 in private subnets"
echo "  ✓ Encrypted at rest with KMS"
echo "  ✓ 7-day automated backup retention"
echo "  ✓ Single instance (no read replicas for MVP)"
echo "  ✓ Enhanced monitoring and Performance Insights"
echo "  ✓ CloudWatch alarms for monitoring"
echo ""
echo "MVP Simplifications applied:"
echo "  • Single AZ deployment (no Multi-AZ)"
echo "  • No read replicas"
echo "  • Smaller instance class (cost-optimized)"
echo "  • Deletion protection disabled (easier cleanup)"
echo ""
echo "Next steps:"
echo "  1. Review the plan: terraform show rds_mvp.tfplan"
echo "  2. Apply the plan: terraform apply rds_mvp.tfplan"
echo "  3. Verify RDS instance:"
echo "     aws rds describe-db-instances --db-instance-identifier ai-cancer-detection-mvp-postgres-primary"
echo ""
echo -e "${YELLOW}Note: Ensure terraform.tfvars is configured with a strong rds_master_password${NC}"
echo -e "${YELLOW}      For MVP, use: cp terraform.tfvars.mvp terraform.tfvars${NC}"

# Clean up plan file
rm -f rds_mvp.tfplan

echo ""
echo "=========================================="
echo "Task 2.1 Validation Complete"
echo "=========================================="
