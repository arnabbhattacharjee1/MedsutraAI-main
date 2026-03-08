# RDS PostgreSQL Infrastructure

## Overview

This document describes the RDS PostgreSQL 15 infrastructure for the AI Cancer Detection and Clinical Summarization platform. The database stores patient records, clinical summaries, cancer risk assessments, and audit logs with full encryption, automated backups, and high availability.

## Architecture

### Primary Instance
- **Engine**: PostgreSQL 15.5
- **Instance Class**: db.r6g.xlarge (4 vCPU, 32 GB RAM)
- **Storage**: 100 GB gp3 with autoscaling up to 1 TB
- **IOPS**: 3,000 IOPS with 125 MB/s throughput
- **Multi-AZ**: Enabled for automatic failover
- **Encryption**: KMS encryption at rest
- **Backup**: 7-day retention with automated backups

### Read Replicas
- **Replica 1**: db.r6g.large in ap-south-1b
- **Replica 2**: db.r6g.large in ap-south-1c
- **Purpose**: Read scaling and high availability
- **Encryption**: Same KMS key as primary

### Network Configuration
- **Placement**: Private subnets across 3 availability zones
- **Security Group**: Allows connections only from Lambda and EKS
- **Public Access**: Disabled
- **VPC**: Isolated within application VPC

## Security Features

### Encryption
- **At Rest**: KMS customer-managed key with automatic rotation
- **In Transit**: SSL/TLS enforced for all connections
- **Performance Insights**: Encrypted with same KMS key
- **Backups**: Encrypted snapshots

### Access Control
- **Network**: Security group restricts access to Lambda and EKS only
- **Authentication**: Master user with strong password (stored in Secrets Manager recommended)
- **IAM**: Enhanced monitoring role with least privilege

### Compliance
- **DPDP Act**: Encryption and access controls for patient data
- **HIPAA-Ready**: Audit logging, encryption, and access controls
- **ABDM**: Supports ABHA number storage and FHIR data models

## Performance Optimization

### Parameter Group Settings
The custom parameter group is optimized for clinical data workloads:

- **Memory Settings**:
  - `shared_buffers`: 25% of instance memory
  - `effective_cache_size`: 75% of instance memory
  - `work_mem`: ~10 MB per operation
  - `maintenance_work_mem`: 2 GB

- **Checkpoint Settings**:
  - `checkpoint_completion_target`: 0.9
  - `wal_buffers`: 16 MB
  - `min_wal_size`: 2 GB
  - `max_wal_size`: 8 GB

- **Query Optimization**:
  - `random_page_cost`: 1.1 (optimized for SSD)
  - `effective_io_concurrency`: 200
  - `default_statistics_target`: 100

- **Connection Settings**:
  - `max_connections`: 200

### Storage
- **Type**: gp3 (General Purpose SSD)
- **Autoscaling**: Enabled (100 GB → 1 TB)
- **IOPS**: 3,000 baseline
- **Throughput**: 125 MB/s

## Monitoring and Alerting

### Enhanced Monitoring
- **Interval**: 60 seconds
- **Metrics**: OS-level metrics (CPU, memory, disk I/O)
- **Role**: Dedicated IAM role for monitoring

### Performance Insights
- **Enabled**: Yes
- **Retention**: 7 days
- **Encryption**: KMS encrypted

### CloudWatch Logs
- **Exported Logs**: PostgreSQL logs, upgrade logs
- **Retention**: Configurable via CloudWatch

### CloudWatch Alarms
1. **CPU Utilization**: Alert when > 80% for 10 minutes
2. **Database Connections**: Alert when > 180 connections (90% of max)
3. **Free Storage**: Alert when < 10 GB
4. **Read Latency**: Alert when > 100ms
5. **Write Latency**: Alert when > 100ms

## Backup and Recovery

### Automated Backups
- **Retention**: 7 days (meets requirement 26.1)
- **Backup Window**: 03:00-04:00 UTC (8:30-9:30 AM IST)
- **Encryption**: KMS encrypted
- **Cross-Region**: Can be configured for disaster recovery

### Maintenance
- **Window**: Monday 04:00-05:00 UTC (9:30-10:30 AM IST)
- **Auto Minor Version Upgrade**: Enabled
- **Deletion Protection**: Enabled for production

### Point-in-Time Recovery
- **Enabled**: Yes (via automated backups)
- **Granularity**: 5 minutes
- **Retention**: 7 days

## High Availability

### Multi-AZ Deployment
- **Primary**: ap-south-1a
- **Standby**: Automatic in different AZ
- **Failover**: Automatic (1-2 minutes)
- **Synchronous Replication**: Yes

### Read Replicas
- **Count**: 2 (configurable)
- **Replication**: Asynchronous
- **Lag**: Typically < 1 second
- **Promotion**: Can be promoted to primary

### Disaster Recovery
- **RTO**: 1-2 minutes (Multi-AZ failover)
- **RPO**: Near-zero (synchronous replication)
- **Cross-Region**: Can be configured for additional DR

## Database Schema

The RDS instance will host the following tables (created in Task 2.2):

1. **patients**: Patient metadata and ABHA numbers
2. **reports**: Medical reports with S3 references
3. **clinical_summaries**: AI-generated clinical summaries
4. **cancer_risk_assessments**: Cancer risk analysis results
5. **audit_logs**: Compliance and security audit trail (7-year retention)

## Configuration Variables

### Required Variables
```hcl
rds_master_password = "STRONG_PASSWORD_HERE"  # Set in terraform.tfvars
```

### Optional Variables (with defaults)
```hcl
rds_instance_class              = "db.r6g.xlarge"
rds_replica_instance_class      = "db.r6g.large"
rds_allocated_storage           = 100
rds_max_allocated_storage       = 1000
rds_iops                        = 3000
rds_storage_throughput          = 125
rds_database_name               = "cancer_detection_db"
rds_master_username             = "dbadmin"
rds_multi_az                    = true
rds_create_read_replicas        = true
rds_create_second_replica       = true
rds_skip_final_snapshot         = false
rds_deletion_protection         = true
```

## Deployment

### Prerequisites
1. VPC and subnets (Task 1.1) ✓
2. Security groups (Task 1.2) ✓
3. KMS keys (Task 1.3) ✓

### Steps

1. **Configure Password**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars and set rds_master_password
   ```

2. **Validate Configuration**:
   ```bash
   chmod +x test_rds.sh
   ./test_rds.sh
   ```

3. **Apply Infrastructure**:
   ```bash
   terraform plan -target=aws_db_instance.primary
   terraform apply -target=aws_db_instance.primary
   ```

4. **Verify Deployment**:
   ```bash
   aws rds describe-db-instances \
     --db-instance-identifier ai-cancer-detection-production-postgres-primary
   ```

### Estimated Deployment Time
- Primary instance: 10-15 minutes
- Read replica 1: 10-15 minutes
- Read replica 2: 10-15 minutes
- Total: ~30-45 minutes

## Connection Information

### Primary Endpoint
```bash
terraform output rds_primary_endpoint
# Output: <instance-id>.xxxxxxxxxx.ap-south-1.rds.amazonaws.com:5432
```

### Read Replica Endpoints
```bash
terraform output rds_replica_1_endpoint
terraform output rds_replica_2_endpoint
```

### Connection String Format
```
postgresql://dbadmin:<password>@<endpoint>:5432/cancer_detection_db?sslmode=require
```

### From Lambda
Lambda functions in the VPC can connect using the security group rules:
```python
import psycopg2

conn = psycopg2.connect(
    host=os.environ['RDS_ENDPOINT'],
    port=5432,
    database='cancer_detection_db',
    user='dbadmin',
    password=os.environ['RDS_PASSWORD'],
    sslmode='require'
)
```

### From EKS
Kubernetes pods can connect using the same security group rules:
```yaml
env:
  - name: DB_HOST
    value: "<rds-endpoint>"
  - name: DB_PORT
    value: "5432"
  - name: DB_NAME
    value: "cancer_detection_db"
  - name: DB_USER
    valueFrom:
      secretKeyRef:
        name: rds-credentials
        key: username
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: rds-credentials
        key: password
```

## Cost Estimation

### Monthly Costs (ap-south-1 region)
- **Primary (db.r6g.xlarge, Multi-AZ)**: ~$450/month
- **Replica 1 (db.r6g.large)**: ~$150/month
- **Replica 2 (db.r6g.large)**: ~$150/month
- **Storage (100 GB gp3)**: ~$12/month
- **Backup Storage (7 days)**: ~$10/month
- **Data Transfer**: Variable
- **Total**: ~$772/month

### Cost Optimization Options
1. **Development**: Use db.t4g.medium without replicas (~$50/month)
2. **Single AZ**: Disable Multi-AZ (50% savings on primary)
3. **Reserved Instances**: 1-year commitment (30-40% savings)
4. **Fewer Replicas**: Remove second replica (~$150/month savings)

## Maintenance

### Regular Tasks
- **Weekly**: Review CloudWatch alarms and Performance Insights
- **Monthly**: Review storage usage and autoscaling
- **Quarterly**: Review parameter group settings and optimize
- **Annually**: Review instance sizing and cost optimization

### Upgrade Process
1. Test upgrade on read replica
2. Promote tested replica to primary
3. Upgrade old primary (now replica)
4. Verify application compatibility

## Troubleshooting

### High CPU Usage
- Check slow queries in Performance Insights
- Review parameter group settings
- Consider scaling up instance class

### Connection Issues
- Verify security group rules
- Check VPC endpoint connectivity
- Verify SSL/TLS configuration

### Replication Lag
- Check network connectivity
- Review write workload on primary
- Consider scaling up replica instance class

### Storage Full
- Verify autoscaling is enabled
- Check for large tables or indexes
- Review backup retention settings

## Security Best Practices

1. **Password Management**:
   - Use AWS Secrets Manager for password storage
   - Rotate passwords regularly
   - Never commit passwords to version control

2. **Network Security**:
   - Keep RDS in private subnets
   - Use security groups for access control
   - Enable VPC Flow Logs for monitoring

3. **Encryption**:
   - Always use SSL/TLS for connections
   - Rotate KMS keys annually
   - Enable encryption for all backups

4. **Monitoring**:
   - Set up SNS notifications for alarms
   - Review audit logs regularly
   - Monitor failed connection attempts

5. **Compliance**:
   - Enable audit logging for HIPAA compliance
   - Maintain 7-year retention for audit logs
   - Document all access and changes

## References

- [AWS RDS PostgreSQL Documentation](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_PostgreSQL.html)
- [PostgreSQL 15 Release Notes](https://www.postgresql.org/docs/15/release-15.html)
- [RDS Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.html)
- [HIPAA Compliance on AWS](https://aws.amazon.com/compliance/hipaa-compliance/)

## Task Completion

This infrastructure satisfies the following requirements:
- **Requirement 12.4**: Encryption at rest with KMS
- **Requirement 13.5**: Automated backups and disaster recovery
- **Requirement 26.1**: AWS deployment with healthcare compliance

Task 2.1 is complete when:
- [x] RDS PostgreSQL 15 instance created in private subnet
- [x] Encryption at rest enabled with KMS
- [x] Automated backups configured with 7-day retention
- [x] Read replicas set up for high availability
- [x] Parameter groups configured for optimal performance
- [x] CloudWatch monitoring and alarms configured
- [x] Documentation complete
