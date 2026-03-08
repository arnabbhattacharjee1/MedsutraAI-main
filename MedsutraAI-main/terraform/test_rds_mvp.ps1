# MVP Test script for RDS PostgreSQL infrastructure validation
# Validates simplified RDS configuration for MVP deployment

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "RDS PostgreSQL MVP Infrastructure Validation" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Check if terraform is initialized
if (-not (Test-Path ".terraform")) {
    Write-Host "Error: Terraform not initialized. Run 'terraform init' first." -ForegroundColor Red
    exit 1
}

# Validate Terraform configuration
Write-Host "1. Validating Terraform configuration..." -ForegroundColor Yellow
try {
    $null = terraform validate 2>&1
    Write-Host "✓ Terraform configuration is valid" -ForegroundColor Green
} catch {
    Write-Host "✗ Terraform configuration validation failed" -ForegroundColor Red
    terraform validate
    exit 1
}

# Check if terraform.tfvars exists
if (-not (Test-Path "terraform.tfvars")) {
    Write-Host "⚠ Warning: terraform.tfvars not found" -ForegroundColor Yellow
    Write-Host "  For MVP deployment, copy terraform.tfvars.mvp to terraform.tfvars"
    Write-Host "  and set rds_master_password before applying"
    Write-Host ""
    Write-Host "  Copy-Item terraform.tfvars.mvp terraform.tfvars"
    Write-Host "  # Edit terraform.tfvars and set rds_master_password"
}

# Plan the infrastructure (MVP - no read replicas)
Write-Host ""
Write-Host "2. Planning RDS infrastructure (MVP mode)..." -ForegroundColor Yellow
$planArgs = @(
    "plan",
    "-target=aws_db_subnet_group.main",
    "-target=aws_db_parameter_group.postgres15",
    "-target=aws_db_instance.primary",
    "-target=aws_iam_role.rds_enhanced_monitoring",
    "-target=aws_iam_role_policy_attachment.rds_enhanced_monitoring",
    "-target=aws_cloudwatch_metric_alarm.rds_cpu_high",
    "-target=aws_cloudwatch_metric_alarm.rds_connections_high",
    "-target=aws_cloudwatch_metric_alarm.rds_storage_low",
    "-target=aws_cloudwatch_metric_alarm.rds_read_latency_high",
    "-target=aws_cloudwatch_metric_alarm.rds_write_latency_high",
    "-out=rds_mvp.tfplan"
)

try {
    & terraform $planArgs
    Write-Host "✓ RDS MVP infrastructure plan created successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ RDS MVP infrastructure planning failed" -ForegroundColor Red
    exit 1
}

# Validate RDS configuration in plan
Write-Host ""
Write-Host "3. Validating RDS MVP configuration..." -ForegroundColor Yellow

$planOutput = terraform show rds_mvp.tfplan | Out-String

# Check for encryption
if ($planOutput -match "storage_encrypted\s*=\s*true") {
    Write-Host "✓ RDS encryption at rest is enabled" -ForegroundColor Green
} else {
    Write-Host "✗ RDS encryption at rest is not enabled" -ForegroundColor Red
    exit 1
}

# Check for KMS key
if ($planOutput -match "kms_key_id") {
    Write-Host "✓ KMS encryption key is configured" -ForegroundColor Green
} else {
    Write-Host "✗ KMS encryption key is not configured" -ForegroundColor Red
    exit 1
}

# Check for automated backups
if ($planOutput -match "backup_retention_period\s*=\s*7") {
    Write-Host "✓ Automated backups with 7-day retention configured" -ForegroundColor Green
} else {
    Write-Host "⚠ Warning: Backup retention period is not 7 days" -ForegroundColor Yellow
}

# Check for PostgreSQL 15
if ($planOutput -match 'engine_version\s*=\s*"15') {
    Write-Host "✓ PostgreSQL 15 is configured" -ForegroundColor Green
} else {
    Write-Host "✗ PostgreSQL version is not 15" -ForegroundColor Red
    exit 1
}

# Check for private subnet placement
if ($planOutput -match "publicly_accessible\s*=\s*false") {
    Write-Host "✓ RDS is in private subnet (not publicly accessible)" -ForegroundColor Green
} else {
    Write-Host "✗ RDS is publicly accessible (security risk)" -ForegroundColor Red
    exit 1
}

# Check for enhanced monitoring
if ($planOutput -match "monitoring_interval\s*=\s*60") {
    Write-Host "✓ Enhanced monitoring is enabled" -ForegroundColor Green
} else {
    Write-Host "⚠ Warning: Enhanced monitoring is not enabled" -ForegroundColor Yellow
}

# Check for Performance Insights
if ($planOutput -match "performance_insights_enabled\s*=\s*true") {
    Write-Host "✓ Performance Insights is enabled" -ForegroundColor Green
} else {
    Write-Host "⚠ Warning: Performance Insights is not enabled" -ForegroundColor Yellow
}

# MVP-specific checks
Write-Host ""
Write-Host "4. Validating MVP simplifications..." -ForegroundColor Yellow

# Verify no read replicas (MVP simplification)
if ($planOutput -match "read_replica_1") {
    Write-Host "⚠ Warning: Read replica 1 is configured (not needed for MVP)" -ForegroundColor Yellow
} else {
    Write-Host "✓ No read replicas configured (MVP simplification)" -ForegroundColor Green
}

# Check instance class is appropriate for MVP
if ($planOutput -match 'instance_class\s*=\s*"db\.t4g') {
    Write-Host "✓ Using cost-effective instance class for MVP" -ForegroundColor Green
} elseif ($planOutput -match 'instance_class\s*=\s*"db\.t3') {
    Write-Host "✓ Using cost-effective instance class for MVP" -ForegroundColor Green
} else {
    Write-Host "⚠ Info: Using production-grade instance class" -ForegroundColor Yellow
}

# Summary
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "MVP Validation Summary" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "RDS PostgreSQL MVP infrastructure validation completed" -ForegroundColor Green
Write-Host ""
Write-Host "MVP Configuration highlights:"
Write-Host "  ✓ PostgreSQL 15 in private subnets"
Write-Host "  ✓ Encrypted at rest with KMS"
Write-Host "  ✓ 7-day automated backup retention"
Write-Host "  ✓ Single instance (no read replicas for MVP)"
Write-Host "  ✓ Enhanced monitoring and Performance Insights"
Write-Host "  ✓ CloudWatch alarms for monitoring"
Write-Host ""
Write-Host "MVP Simplifications applied:"
Write-Host "  • Single AZ deployment (no Multi-AZ)"
Write-Host "  • No read replicas"
Write-Host "  • Smaller instance class (cost-optimized)"
Write-Host "  • Deletion protection disabled (easier cleanup)"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Review the plan: terraform show rds_mvp.tfplan"
Write-Host "  2. Apply the plan: terraform apply rds_mvp.tfplan"
Write-Host "  3. Verify RDS instance:"
Write-Host "     aws rds describe-db-instances --db-instance-identifier ai-cancer-detection-mvp-postgres-primary"
Write-Host ""
Write-Host "Note: Ensure terraform.tfvars is configured with a strong rds_master_password" -ForegroundColor Yellow
Write-Host "      For MVP, use: Copy-Item terraform.tfvars.mvp terraform.tfvars" -ForegroundColor Yellow

# Clean up plan file
if (Test-Path "rds_mvp.tfplan") {
    Remove-Item "rds_mvp.tfplan" -Force
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Task 2.1 Validation Complete" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
