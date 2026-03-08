# Quick Start Guide - VPC Infrastructure Deployment

This guide will help you deploy the VPC infrastructure for the AI Cancer Detection platform in under 15 minutes.

## Prerequisites Checklist

- [ ] AWS Account with admin access
- [ ] AWS CLI installed and configured
- [ ] Terraform 1.5.0+ installed
- [ ] Basic understanding of AWS VPC concepts

## Step-by-Step Deployment

### Step 1: Verify Prerequisites

```bash
# Check Terraform version
terraform version

# Check AWS CLI configuration
aws sts get-caller-identity

# Verify you're in the correct region
aws configure get region
```

### Step 2: Create State Backend Resources

```bash
# Set your region
export AWS_REGION=ap-south-1

# Create S3 bucket for Terraform state
aws s3api create-bucket \
  --bucket ai-cancer-detection-terraform-state \
  --region $AWS_REGION \
  --create-bucket-configuration LocationConstraint=$AWS_REGION

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket ai-cancer-detection-terraform-state \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket ai-cancer-detection-terraform-state \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name ai-cancer-detection-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region $AWS_REGION
```

### Step 3: Configure Terraform

```bash
# Navigate to terraform directory
cd infrastructure/terraform

# Copy example configuration files
cp terraform.tfvars.example terraform.tfvars
cp backend.tfvars.example backend.tfvars

# Edit terraform.tfvars (use your preferred editor)
nano terraform.tfvars
```

**For Production**:
```hcl
aws_region   = "ap-south-1"
environment  = "production"
project_name = "ai-cancer-detection"

vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]

enable_nat_gateway  = true
single_nat_gateway  = false  # High availability
```

**For Development** (Cost-optimized):
```hcl
aws_region   = "ap-south-1"
environment  = "development"
project_name = "ai-cancer-detection"

vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]

enable_nat_gateway  = true
single_nat_gateway  = true  # Cost optimization
```

### Step 4: Initialize Terraform

```bash
# Initialize Terraform with backend configuration
terraform init -backend-config=backend.tfvars
```

Expected output:
```
Initializing the backend...
Successfully configured the backend "s3"!
Terraform has been successfully initialized!
```

### Step 5: Validate Configuration

```bash
# Validate Terraform configuration
terraform validate

# Format Terraform files
terraform fmt -recursive

# Run validation script (optional)
chmod +x validate.sh
./validate.sh
```

### Step 6: Plan Infrastructure

```bash
# Create execution plan
terraform plan -out=tfplan

# Review the plan carefully
# You should see resources to be created:
# - 1 VPC
# - 6 Subnets (3 public, 3 private)
# - 1 Internet Gateway
# - 3 NAT Gateways (or 1 if single_nat_gateway=true)
# - 3 Elastic IPs
# - 4 Route Tables
# - 7 VPC Endpoints
# - 1 Security Group
```

### Step 7: Apply Infrastructure

```bash
# Apply the plan
terraform apply tfplan

# This will take approximately 5-10 minutes
# NAT Gateway creation is the slowest part
```

Expected output:
```
Apply complete! Resources: 30+ added, 0 changed, 0 destroyed.

Outputs:

vpc_id = "vpc-xxxxxxxxxxxxx"
public_subnet_ids = [
  "subnet-xxxxxxxxxxxxx",
  "subnet-xxxxxxxxxxxxx",
  "subnet-xxxxxxxxxxxxx",
]
private_subnet_ids = [
  "subnet-xxxxxxxxxxxxx",
  "subnet-xxxxxxxxxxxxx",
  "subnet-xxxxxxxxxxxxx",
]
...
```

### Step 8: Verify Deployment

```bash
# View all outputs
terraform output

# Save outputs to file for reference
terraform output -json > outputs.json

# Verify VPC in AWS Console
aws ec2 describe-vpcs --filters "Name=tag:Project,Values=AI-Cancer-Detection"

# Verify subnets
aws ec2 describe-subnets --filters "Name=tag:Project,Values=AI-Cancer-Detection"

# Verify NAT Gateways
aws ec2 describe-nat-gateways --filter "Name=tag:Project,Values=AI-Cancer-Detection"
```

## Post-Deployment

### Save Important Information

```bash
# Export VPC ID for use in other tasks
export VPC_ID=$(terraform output -raw vpc_id)

# Export subnet IDs
export PUBLIC_SUBNET_IDS=$(terraform output -json public_subnet_ids | jq -r '.[]' | tr '\n' ',')
export PRIVATE_SUBNET_IDS=$(terraform output -json private_subnet_ids | jq -r '.[]' | tr '\n' ',')

# Save to environment file
cat > ../vpc-outputs.env << EOF
VPC_ID=$VPC_ID
PUBLIC_SUBNET_IDS=$PUBLIC_SUBNET_IDS
PRIVATE_SUBNET_IDS=$PRIVATE_SUBNET_IDS
EOF
```

### Test Connectivity

```bash
# Test VPC endpoint connectivity (optional)
# Launch a test EC2 instance in private subnet and verify S3 access via endpoint
```

## Troubleshooting

### Issue: "Error creating NAT Gateway: timeout"

**Solution**: NAT Gateway creation can take 5-10 minutes. Wait and run `terraform apply` again.

### Issue: "Error acquiring state lock"

**Solution**: Another Terraform process may be running. If not, release the lock:

```bash
aws dynamodb delete-item \
  --table-name ai-cancer-detection-terraform-locks \
  --key '{"LockID": {"S": "ai-cancer-detection-terraform-state/production/vpc/terraform.tfstate"}}'
```

### Issue: "InvalidParameterValue: Value (ap-south-1d) for parameter availabilityZone is invalid"

**Solution**: Not all regions have the same AZs. Update `availability_zones` in terraform.tfvars:

```bash
# List available AZs in your region
aws ec2 describe-availability-zones --region ap-south-1 --query 'AvailabilityZones[].ZoneName'
```

### Issue: "Error creating VPC Endpoint: service not available"

**Solution**: Some VPC endpoints may not be available in all regions. Comment out unavailable endpoints in `vpc_endpoints.tf`.

## Cost Estimation

### Production (3 NAT Gateways)
- **Monthly**: ~$133 + data transfer
- **Annual**: ~$1,596 + data transfer

### Development (1 NAT Gateway)
- **Monthly**: ~$68 + data transfer
- **Annual**: ~$816 + data transfer

**Data Transfer Costs**: ~$0.045/GB for NAT Gateway data processing

## Next Steps

1. ✅ VPC infrastructure deployed
2. ⏭️ Task 1.2: Configure security groups and network ACLs
3. ⏭️ Task 1.3: Set up AWS KMS for encryption
4. ⏭️ Task 1.4: Configure S3 buckets with encryption

## Cleanup (If Needed)

**WARNING**: This will destroy all infrastructure!

```bash
# Destroy all resources
terraform destroy

# Confirm by typing 'yes'

# Delete state backend (optional)
aws s3 rb s3://ai-cancer-detection-terraform-state --force
aws dynamodb delete-table --table-name ai-cancer-detection-terraform-locks
```

## Support

For issues or questions:
1. Check the [README.md](README.md) for detailed documentation
2. Review [ARCHITECTURE.md](ARCHITECTURE.md) for design details
3. Check AWS documentation for service-specific issues

## Success Criteria

- [ ] VPC created with correct CIDR block
- [ ] 3 public subnets across 3 AZs
- [ ] 3 private subnets across 3 AZs
- [ ] Internet Gateway attached
- [ ] NAT Gateways operational (3 for prod, 1 for dev)
- [ ] Route tables configured correctly
- [ ] VPC endpoints created (S3, DynamoDB, KMS, etc.)
- [ ] All Terraform outputs available
- [ ] No errors in AWS Console

Congratulations! Your VPC infrastructure is now ready for the next phase of deployment.
