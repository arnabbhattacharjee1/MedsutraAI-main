#!/bin/bash
# Deploy Database Schema to RDS PostgreSQL
# Usage: ./deploy_schema.sh [environment] [options]
# Example: ./deploy_schema.sh mvp --with-seed-data

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT="${1:-mvp}"
WITH_SEED_DATA=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --with-seed-data)
            WITH_SEED_DATA=true
            shift
            ;;
    esac
done

echo -e "${GREEN}=== Database Schema Deployment ===${NC}"
echo "Environment: $ENVIRONMENT"
echo "With seed data: $WITH_SEED_DATA"
echo ""

# Check if required tools are installed
if ! command -v psql &> /dev/null; then
    echo -e "${RED}Error: psql is not installed. Please install PostgreSQL client.${NC}"
    exit 1
fi

if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Error: terraform is not installed.${NC}"
    exit 1
fi

# Get RDS connection details from Terraform outputs
echo -e "${YELLOW}Retrieving RDS connection details from Terraform...${NC}"
cd ../terraform

if [ ! -f "terraform.tfstate" ]; then
    echo -e "${RED}Error: terraform.tfstate not found. Please run 'terraform apply' first.${NC}"
    exit 1
fi

RDS_ENDPOINT=$(terraform output -raw rds_endpoint 2>/dev/null || echo "")
RDS_DATABASE=$(terraform output -raw rds_database_name 2>/dev/null || echo "")
RDS_USERNAME=$(terraform output -raw rds_master_username 2>/dev/null || echo "")

if [ -z "$RDS_ENDPOINT" ] || [ -z "$RDS_DATABASE" ] || [ -z "$RDS_USERNAME" ]; then
    echo -e "${RED}Error: Could not retrieve RDS connection details from Terraform outputs.${NC}"
    echo "Please ensure RDS instance is created and Terraform outputs are configured."
    exit 1
fi

# Extract host and port from endpoint
RDS_HOST=$(echo $RDS_ENDPOINT | cut -d':' -f1)
RDS_PORT=$(echo $RDS_ENDPOINT | cut -d':' -f2)

echo "RDS Host: $RDS_HOST"
echo "RDS Port: $RDS_PORT"
echo "RDS Database: $RDS_DATABASE"
echo "RDS Username: $RDS_USERNAME"
echo ""

# Prompt for password
echo -e "${YELLOW}Enter RDS master password:${NC}"
read -s RDS_PASSWORD
echo ""

if [ -z "$RDS_PASSWORD" ]; then
    echo -e "${RED}Error: Password cannot be empty.${NC}"
    exit 1
fi

# Set PostgreSQL environment variables
export PGHOST=$RDS_HOST
export PGPORT=$RDS_PORT
export PGDATABASE=$RDS_DATABASE
export PGUSER=$RDS_USERNAME
export PGPASSWORD=$RDS_PASSWORD

# Test connection
echo -e "${YELLOW}Testing database connection...${NC}"
if ! psql -c "SELECT version();" > /dev/null 2>&1; then
    echo -e "${RED}Error: Could not connect to database.${NC}"
    echo "Please check:"
    echo "  1. RDS instance is running"
    echo "  2. Security groups allow connections from your IP"
    echo "  3. Password is correct"
    exit 1
fi

echo -e "${GREEN}✓ Database connection successful${NC}"
echo ""

# Check if schema already exists
echo -e "${YELLOW}Checking if schema already exists...${NC}"
TABLE_COUNT=$(psql -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('patients', 'reports', 'clinical_summaries', 'cancer_risk_assessments', 'audit_logs');" | xargs)

if [ "$TABLE_COUNT" -eq "5" ]; then
    echo -e "${YELLOW}Warning: Schema already exists (found 5 tables).${NC}"
    echo "Do you want to:"
    echo "  1. Skip deployment (keep existing schema)"
    echo "  2. Drop and recreate schema (WARNING: ALL DATA WILL BE LOST)"
    echo "  3. Exit"
    read -p "Enter choice (1-3): " choice
    
    case $choice in
        1)
            echo "Skipping schema deployment."
            ;;
        2)
            echo -e "${RED}Dropping existing schema...${NC}"
            cd ../database
            psql -f migrations/001_initial_schema_rollback.sql
            echo -e "${GREEN}✓ Schema dropped${NC}"
            echo ""
            echo -e "${YELLOW}Creating new schema...${NC}"
            psql -f schema.sql
            echo -e "${GREEN}✓ Schema created successfully${NC}"
            ;;
        3)
            echo "Exiting."
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice. Exiting.${NC}"
            exit 1
            ;;
    esac
elif [ "$TABLE_COUNT" -gt "0" ]; then
    echo -e "${RED}Error: Partial schema detected (found $TABLE_COUNT tables).${NC}"
    echo "Please manually clean up the database or use rollback script."
    exit 1
else
    echo "No existing schema found. Proceeding with deployment."
    echo ""
    
    # Deploy schema
    echo -e "${YELLOW}Deploying database schema...${NC}"
    cd ../database
    psql -f schema.sql
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Schema deployed successfully${NC}"
    else
        echo -e "${RED}Error: Schema deployment failed${NC}"
        exit 1
    fi
fi

# Verify deployment
echo ""
echo -e "${YELLOW}Verifying schema deployment...${NC}"
FINAL_TABLE_COUNT=$(psql -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('patients', 'reports', 'clinical_summaries', 'cancer_risk_assessments', 'audit_logs');" | xargs)

if [ "$FINAL_TABLE_COUNT" -eq "5" ]; then
    echo -e "${GREEN}✓ All 5 tables created successfully${NC}"
else
    echo -e "${RED}Error: Expected 5 tables, found $FINAL_TABLE_COUNT${NC}"
    exit 1
fi

# Check indexes
INDEX_COUNT=$(psql -t -c "SELECT COUNT(*) FROM pg_indexes WHERE schemaname = 'public';" | xargs)
echo -e "${GREEN}✓ Created $INDEX_COUNT indexes${NC}"

# Check views
VIEW_COUNT=$(psql -t -c "SELECT COUNT(*) FROM information_schema.views WHERE table_schema = 'public';" | xargs)
echo -e "${GREEN}✓ Created $VIEW_COUNT views${NC}"

# Load seed data if requested
if [ "$WITH_SEED_DATA" = true ]; then
    echo ""
    echo -e "${YELLOW}Loading seed data...${NC}"
    psql -f seeds/test_data.sql
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Seed data loaded successfully${NC}"
        
        # Show counts
        echo ""
        echo "Data summary:"
        psql -t -c "SELECT 'Patients: ' || COUNT(*) FROM patients;"
        psql -t -c "SELECT 'Reports: ' || COUNT(*) FROM reports;"
        psql -t -c "SELECT 'Clinical Summaries: ' || COUNT(*) FROM clinical_summaries;"
        psql -t -c "SELECT 'Cancer Risk Assessments: ' || COUNT(*) FROM cancer_risk_assessments;"
        psql -t -c "SELECT 'Audit Logs: ' || COUNT(*) FROM audit_logs;"
    else
        echo -e "${RED}Warning: Seed data loading failed${NC}"
    fi
fi

echo ""
echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo ""
echo "Database schema has been successfully deployed to:"
echo "  Host: $RDS_HOST"
echo "  Database: $RDS_DATABASE"
echo ""
echo "Next steps:"
echo "  1. Update application configuration with database connection details"
echo "  2. Configure application user credentials (separate from master user)"
echo "  3. Test database connectivity from application"
echo ""
