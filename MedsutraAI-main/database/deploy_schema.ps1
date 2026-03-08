# Deploy Database Schema to RDS PostgreSQL (PowerShell)
# Usage: .\deploy_schema.ps1 [-Environment mvp] [-WithSeedData]
# Example: .\deploy_schema.ps1 -Environment mvp -WithSeedData

param(
    [string]$Environment = "mvp",
    [switch]$WithSeedData = $false
)

$ErrorActionPreference = "Stop"

# Colors for output
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

Write-ColorOutput Green "=== Database Schema Deployment ==="
Write-Output "Environment: $Environment"
Write-Output "With seed data: $WithSeedData"
Write-Output ""

# Check if required tools are installed
try {
    $null = Get-Command psql -ErrorAction Stop
} catch {
    Write-ColorOutput Red "Error: psql is not installed. Please install PostgreSQL client."
    exit 1
}

try {
    $null = Get-Command terraform -ErrorAction Stop
} catch {
    Write-ColorOutput Red "Error: terraform is not installed."
    exit 1
}

# Get RDS connection details from Terraform outputs
Write-ColorOutput Yellow "Retrieving RDS connection details from Terraform..."
Push-Location ..\terraform

if (-not (Test-Path "terraform.tfstate")) {
    Write-ColorOutput Red "Error: terraform.tfstate not found. Please run 'terraform apply' first."
    Pop-Location
    exit 1
}

try {
    $RDS_ENDPOINT = terraform output -raw rds_endpoint 2>$null
    $RDS_DATABASE = terraform output -raw rds_database_name 2>$null
    $RDS_USERNAME = terraform output -raw rds_master_username 2>$null
} catch {
    Write-ColorOutput Red "Error: Could not retrieve RDS connection details from Terraform outputs."
    Write-Output "Please ensure RDS instance is created and Terraform outputs are configured."
    Pop-Location
    exit 1
}

if ([string]::IsNullOrEmpty($RDS_ENDPOINT) -or [string]::IsNullOrEmpty($RDS_DATABASE) -or [string]::IsNullOrEmpty($RDS_USERNAME)) {
    Write-ColorOutput Red "Error: Could not retrieve RDS connection details from Terraform outputs."
    Write-Output "Please ensure RDS instance is created and Terraform outputs are configured."
    Pop-Location
    exit 1
}

# Extract host and port from endpoint
$RDS_HOST = $RDS_ENDPOINT.Split(':')[0]
$RDS_PORT = $RDS_ENDPOINT.Split(':')[1]

Write-Output "RDS Host: $RDS_HOST"
Write-Output "RDS Port: $RDS_PORT"
Write-Output "RDS Database: $RDS_DATABASE"
Write-Output "RDS Username: $RDS_USERNAME"
Write-Output ""

# Prompt for password
Write-ColorOutput Yellow "Enter RDS master password:"
$SecurePassword = Read-Host -AsSecureString
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
$RDS_PASSWORD = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
Write-Output ""

if ([string]::IsNullOrEmpty($RDS_PASSWORD)) {
    Write-ColorOutput Red "Error: Password cannot be empty."
    Pop-Location
    exit 1
}

# Set PostgreSQL environment variables
$env:PGHOST = $RDS_HOST
$env:PGPORT = $RDS_PORT
$env:PGDATABASE = $RDS_DATABASE
$env:PGUSER = $RDS_USERNAME
$env:PGPASSWORD = $RDS_PASSWORD

# Test connection
Write-ColorOutput Yellow "Testing database connection..."
try {
    $result = psql -c "SELECT version();" 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Connection failed"
    }
} catch {
    Write-ColorOutput Red "Error: Could not connect to database."
    Write-Output "Please check:"
    Write-Output "  1. RDS instance is running"
    Write-Output "  2. Security groups allow connections from your IP"
    Write-Output "  3. Password is correct"
    Pop-Location
    exit 1
}

Write-ColorOutput Green "✓ Database connection successful"
Write-Output ""

# Check if schema already exists
Write-ColorOutput Yellow "Checking if schema already exists..."
$TABLE_COUNT = (psql -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('patients', 'reports', 'clinical_summaries', 'cancer_risk_assessments', 'audit_logs');").Trim()

Pop-Location
Push-Location ..\database

if ($TABLE_COUNT -eq "5") {
    Write-ColorOutput Yellow "Warning: Schema already exists (found 5 tables)."
    Write-Output "Do you want to:"
    Write-Output "  1. Skip deployment (keep existing schema)"
    Write-Output "  2. Drop and recreate schema (WARNING: ALL DATA WILL BE LOST)"
    Write-Output "  3. Exit"
    $choice = Read-Host "Enter choice (1-3)"
    
    switch ($choice) {
        "1" {
            Write-Output "Skipping schema deployment."
        }
        "2" {
            Write-ColorOutput Red "Dropping existing schema..."
            psql -f migrations\001_initial_schema_rollback.sql
            Write-ColorOutput Green "✓ Schema dropped"
            Write-Output ""
            Write-ColorOutput Yellow "Creating new schema..."
            psql -f schema.sql
            Write-ColorOutput Green "✓ Schema created successfully"
        }
        "3" {
            Write-Output "Exiting."
            Pop-Location
            exit 0
        }
        default {
            Write-ColorOutput Red "Invalid choice. Exiting."
            Pop-Location
            exit 1
        }
    }
} elseif ([int]$TABLE_COUNT -gt 0) {
    Write-ColorOutput Red "Error: Partial schema detected (found $TABLE_COUNT tables)."
    Write-Output "Please manually clean up the database or use rollback script."
    Pop-Location
    exit 1
} else {
    Write-Output "No existing schema found. Proceeding with deployment."
    Write-Output ""
    
    # Deploy schema
    Write-ColorOutput Yellow "Deploying database schema..."
    psql -f schema.sql
    
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput Red "Error: Schema deployment failed"
        Pop-Location
        exit 1
    }
    
    Write-ColorOutput Green "✓ Schema deployed successfully"
}

# Verify deployment
Write-Output ""
Write-ColorOutput Yellow "Verifying schema deployment..."
$FINAL_TABLE_COUNT = (psql -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('patients', 'reports', 'clinical_summaries', 'cancer_risk_assessments', 'audit_logs');").Trim()

if ($FINAL_TABLE_COUNT -eq "5") {
    Write-ColorOutput Green "✓ All 5 tables created successfully"
} else {
    Write-ColorOutput Red "Error: Expected 5 tables, found $FINAL_TABLE_COUNT"
    Pop-Location
    exit 1
}

# Check indexes
$INDEX_COUNT = (psql -t -c "SELECT COUNT(*) FROM pg_indexes WHERE schemaname = 'public';").Trim()
Write-ColorOutput Green "✓ Created $INDEX_COUNT indexes"

# Check views
$VIEW_COUNT = (psql -t -c "SELECT COUNT(*) FROM information_schema.views WHERE table_schema = 'public';").Trim()
Write-ColorOutput Green "✓ Created $VIEW_COUNT views"

# Load seed data if requested
if ($WithSeedData) {
    Write-Output ""
    Write-ColorOutput Yellow "Loading seed data..."
    psql -f seeds\test_data.sql
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput Green "✓ Seed data loaded successfully"
        
        # Show counts
        Write-Output ""
        Write-Output "Data summary:"
        psql -t -c "SELECT 'Patients: ' || COUNT(*) FROM patients;"
        psql -t -c "SELECT 'Reports: ' || COUNT(*) FROM reports;"
        psql -t -c "SELECT 'Clinical Summaries: ' || COUNT(*) FROM clinical_summaries;"
        psql -t -c "SELECT 'Cancer Risk Assessments: ' || COUNT(*) FROM cancer_risk_assessments;"
        psql -t -c "SELECT 'Audit Logs: ' || COUNT(*) FROM audit_logs;"
    } else {
        Write-ColorOutput Red "Warning: Seed data loading failed"
    }
}

Pop-Location

Write-Output ""
Write-ColorOutput Green "=== Deployment Complete ==="
Write-Output ""
Write-Output "Database schema has been successfully deployed to:"
Write-Output "  Host: $RDS_HOST"
Write-Output "  Database: $RDS_DATABASE"
Write-Output ""
Write-Output "Next steps:"
Write-Output "  1. Update application configuration with database connection details"
Write-Output "  2. Configure application user credentials (separate from master user)"
Write-Output "  3. Test database connectivity from application"
Write-Output ""
