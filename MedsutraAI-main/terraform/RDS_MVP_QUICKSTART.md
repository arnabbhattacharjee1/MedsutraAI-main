# RDS PostgreSQL MVP Quick Start Guide

## 🚀 Quick Deployment (5 Steps)

### Step 1: Copy MVP Configuration
```bash
cd infrastructure/terraform
cp terraform.tfvars.mvp terraform.tfvars
```

### Step 2: Set Strong Password
Edit `terraform.tfvars` and replace `CHANGE_ME_TO_STRONG_PASSWORD`:
```hcl
rds_master_password = "YourStrongPassword123!"
```

Requirements:
- ✅ At least 8 characters
- ✅ Uppercase + lowercase + numbers
- ❌ Cannot contain: / " @

### Step 3: Initialize Terraform (if not done)
```bash
terraform init
```

### Step 4: Deploy RDS
```bash
terraform apply -target=aws_db_subnet_group.main \
                -target=aws_db_parameter_group.postgres15 \
                -target=aws_db_instance.primary \
                -target=aws_iam_role.rds_enhanced_monitoring \
                -target=aws_iam_role_policy_attachment.rds_enhanced_monitoring
```

Type `yes` when prompted.

⏱️ **Deployment time**: 10-15 minutes

### Step 5: Get Connection Info
```bash
terraform output rds_primary_endpoint
```

## 📊 MVP Configuration

| Setting | Value | Production |
|---------|-------|------------|
| Instance Class | db.t4g.large | db.r6g.xlarge |
| Storage | 50 GB | 100 GB |
| Multi-AZ | ❌ No | ✅ Yes |
| Read Replicas | ❌ No | ✅ Yes (2) |
| Cost/Month | ~$50 | ~$772 |

## ✅ What's Included

- ✅ PostgreSQL 15.5
- ✅ KMS encryption at rest
- ✅ 7-day automated backups
- ✅ Private subnet (not public)
- ✅ Security group restrictions
- ✅ Enhanced monitoring
- ✅ Performance Insights
- ✅ CloudWatch alarms

## 🔗 Connection String

```
postgresql://dbadmin:<password>@<endpoint>:5432/cancer_detection_db?sslmode=require
```

Get endpoint:
```bash
terraform output rds_primary_endpoint
```

## 🧪 Verify Deployment

```bash
# Check status
aws rds describe-db-instances \
  --db-instance-identifier ai-cancer-detection-mvp-postgres-primary \
  --query 'DBInstances[0].[DBInstanceStatus,Endpoint.Address,StorageEncrypted]'

# Expected output:
# [
#   "available",
#   "ai-cancer-detection-mvp-postgres-primary.xxxxx.ap-south-1.rds.amazonaws.com",
#   true
# ]
```

## 🔐 Security Notes

⚠️ **IMPORTANT**:
- Never commit `terraform.tfvars` to git
- Store password in AWS Secrets Manager for production
- RDS is NOT publicly accessible (by design)
- Connect from Lambda/EKS within VPC only

## 🐛 Troubleshooting

### "Terraform not found"
Install from: https://www.terraform.io/downloads

### "AWS credentials not configured"
```bash
aws configure
# Enter: Access Key, Secret Key, Region (ap-south-1)
```

### "Cannot connect from local machine"
✅ **This is correct!** RDS is in private subnet for security.
Connect from Lambda or EKS within the VPC.

### "Deployment taking too long"
⏱️ Normal. RDS creation takes 10-15 minutes.

## 📈 Upgrade to Production

To enable production features, edit `terraform.tfvars`:

```hcl
# Enable production features
rds_instance_class = "db.r6g.xlarge"
rds_allocated_storage = 100
rds_multi_az = true
rds_create_read_replicas = true
rds_deletion_protection = true
```

Then run:
```bash
terraform apply
```

## 📚 Full Documentation

- **Complete Guide**: `RDS.md`
- **Task Completion**: `TASK_2.1_COMPLETION.md`
- **Architecture**: `ARCHITECTURE.md`

## ⏭️ Next Steps

1. ✅ Task 2.1: RDS PostgreSQL (COMPLETE)
2. ➡️ Task 2.2: Create database schema
3. ➡️ Task 2.3: Set up DynamoDB tables

---

**Need Help?** See `TASK_2.1_COMPLETION.md` for detailed instructions.
