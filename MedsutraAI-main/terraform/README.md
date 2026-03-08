# AI Cancer Detection Platform - Infrastructure as Code

This directory contains Terraform configurations for deploying the AWS infrastructure for the AI Cancer Detection and Clinical Summarization platform.

## Architecture Overview

The infrastructure creates a highly available, secure VPC with:

- **VPC**: 10.0.0.0/16 CIDR block
- **Public Subnets**: 3 subnets across 3 availability zones for NAT gateways and load balancers
- **Private Subnets**: 3 subnets across 3 availability zones for EKS, RDS, and Lambda
- **Internet Gateway**: For public subnet internet access
- **NAT Gateways**: For private subnet outbound internet access (one per AZ for high availability)
- **VPC Endpoints**: Private connectivity to S3, DynamoDB, and KMS

## Prerequisites

1. **AWS Account**: Active AWS account with appropriate permissions
2. **Terraform**: Version 1.5.0 or higher
3. **AWS CLI**: Configured with credentials
4. **S3 Bucket**: For Terraform state storage (create manually before first run)
5. **DynamoDB Table**: For Terraform state locking (create manually before first run)

### Create State Backend Resources

```bash
# Create S3 bucket for Terraform state
aws s3api create-bucket \
  --bucket ai-cancer-detection-terraform-state \
  --region ap-south-1 \
  --create-bucket-configuration LocationConstraint=ap-south-1

# Enable versioning on state bucket
aws s3api put-bucket-versioning \
  --bucket ai-cancer-detection-terraform-state \
  --versioning-configuration Status=Enabled

# Enable encryption on state bucket
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
  --region ap-south-1
```

## Configuration

1. **Copy example files**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   cp backend.tfvars.example backend.tfvars
   ```

2. **Edit terraform.tfvars**:
   - Update `aws_region` if deploying to a different region
   - Adjust `environment` (dev, staging, production)
   - Modify CIDR blocks if needed
   - Set `single_nat_gateway = true` for cost optimization in non-production environments

3. **Edit backend.tfvars**:
   - Update bucket name and DynamoDB table name if different
   - Ensure region matches your deployment region

## Deployment

### Initialize Terraform

```bash
terraform init -backend-config=backend.tfvars
```

### Plan Infrastructure Changes

```bash
terraform plan -out=tfplan
```

Review the plan carefully to ensure all resources are correct.

### Apply Infrastructure Changes

```bash
terraform apply tfplan
```

### View Outputs

```bash
terraform output
```

## Outputs

The configuration provides the following outputs:

- `vpc_id`: VPC identifier
- `public_subnet_ids`: List of public subnet IDs
- `private_subnet_ids`: List of private subnet IDs
- `nat_gateway_ids`: List of NAT Gateway IDs
- `vpc_endpoint_s3_id`: S3 VPC endpoint ID
- `vpc_endpoint_dynamodb_id`: DynamoDB VPC endpoint ID
- `vpc_endpoint_kms_id`: KMS VPC endpoint ID

These outputs are used by subsequent infrastructure components (EKS, RDS, Lambda, etc.).

## Cost Optimization

### Production Environment
- Uses 3 NAT Gateways (one per AZ) for high availability
- Estimated cost: ~$100-150/month for NAT Gateways alone

### Development/Staging Environment
- Set `single_nat_gateway = true` to use only one NAT Gateway
- Estimated cost: ~$35-50/month for single NAT Gateway
- **Note**: Single NAT Gateway is not recommended for production due to single point of failure

### VPC Endpoints
- Gateway endpoints (S3, DynamoDB): No additional cost
- Interface endpoints (KMS, ECR, Logs, STS): ~$7-10/month per endpoint

## Security Features

1. **Network Isolation**: Private subnets have no direct internet access
2. **VPC Endpoints**: Private connectivity to AWS services without internet gateway
3. **Security Groups**: Restrictive security group for VPC endpoints
4. **Encryption**: All VPC endpoints support encryption in transit
5. **DNS**: Private DNS enabled for interface endpoints

## Compliance

This infrastructure supports:

- **DPDP Act**: Network isolation and encryption
- **HIPAA-Ready**: Private subnets, VPC endpoints, audit logging
- **ABDM Alignment**: Secure network architecture for healthcare data

## Maintenance

### Update Infrastructure

1. Modify Terraform files as needed
2. Run `terraform plan` to review changes
3. Run `terraform apply` to apply changes

### Destroy Infrastructure

**WARNING**: This will destroy all resources. Ensure you have backups.

```bash
terraform destroy
```

## Troubleshooting

### Issue: Terraform state lock error

**Solution**: Check if another Terraform process is running. If not, manually release the lock:

```bash
aws dynamodb delete-item \
  --table-name ai-cancer-detection-terraform-locks \
  --key '{"LockID": {"S": "ai-cancer-detection-terraform-state/production/vpc/terraform.tfstate"}}'
```

### Issue: NAT Gateway creation timeout

**Solution**: NAT Gateway creation can take 5-10 minutes. If it times out, run `terraform apply` again.

### Issue: VPC endpoint creation fails

**Solution**: Ensure the service is available in your region. Some services may not be available in all regions.

## Next Steps

After VPC setup is complete, proceed to:

1. Task 1.2: Configure security groups and network ACLs
2. Task 1.3: Set up AWS KMS for encryption
3. Task 1.4: Configure S3 buckets with encryption

## References

- [AWS VPC Documentation](https://docs.aws.amazon.com/vpc/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS VPC Endpoints](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints.html)
