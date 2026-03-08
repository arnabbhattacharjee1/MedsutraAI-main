# Outputs for AI Cancer Detection Platform Infrastructure

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = aws_subnet.private[*].id
}

output "public_subnet_cidrs" {
  description = "CIDR blocks of public subnets"
  value       = aws_subnet.public[*].cidr_block
}

output "private_subnet_cidrs" {
  description = "CIDR blocks of private subnets"
  value       = aws_subnet.private[*].cidr_block
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_ids" {
  description = "IDs of NAT Gateways"
  value       = aws_nat_gateway.main[*].id
}

output "nat_gateway_public_ips" {
  description = "Public IPs of NAT Gateways"
  value       = aws_eip.nat[*].public_ip
}

output "public_route_table_id" {
  description = "ID of public route table"
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "IDs of private route tables"
  value       = aws_route_table.private[*].id
}

output "vpc_endpoint_s3_id" {
  description = "ID of S3 VPC endpoint"
  value       = aws_vpc_endpoint.s3.id
}

output "vpc_endpoint_dynamodb_id" {
  description = "ID of DynamoDB VPC endpoint"
  value       = aws_vpc_endpoint.dynamodb.id
}

output "vpc_endpoint_kms_id" {
  description = "ID of KMS VPC endpoint"
  value       = aws_vpc_endpoint.kms.id
}

output "vpc_endpoints_security_group_id" {
  description = "ID of VPC endpoints security group"
  value       = aws_security_group.vpc_endpoints.id
}

output "availability_zones" {
  description = "Availability zones used"
  value       = var.availability_zones
}

# Security Group Outputs
output "eks_cluster_security_group_id" {
  description = "ID of EKS cluster security group"
  value       = aws_security_group.eks_cluster.id
}

output "eks_nodes_security_group_id" {
  description = "ID of EKS nodes security group"
  value       = aws_security_group.eks_nodes.id
}

output "rds_security_group_id" {
  description = "ID of RDS security group"
  value       = aws_security_group.rds.id
}

output "lambda_security_group_id" {
  description = "ID of Lambda security group"
  value       = aws_security_group.lambda.id
}

output "alb_security_group_id" {
  description = "ID of Application Load Balancer security group"
  value       = aws_security_group.alb.id
}

output "redis_security_group_id" {
  description = "ID of Redis security group"
  value       = aws_security_group.redis.id
}

# Network ACL Outputs
output "public_network_acl_id" {
  description = "ID of public subnets network ACL"
  value       = aws_network_acl.public.id
}

output "private_network_acl_id" {
  description = "ID of private subnets network ACL"
  value       = aws_network_acl.private.id
}

# KMS Key Outputs
output "kms_s3_key_id" {
  description = "ID of KMS key for S3 encryption"
  value       = aws_kms_key.s3_encryption.id
}

output "kms_s3_key_arn" {
  description = "ARN of KMS key for S3 encryption"
  value       = aws_kms_key.s3_encryption.arn
}

output "kms_s3_alias_name" {
  description = "Alias name of KMS key for S3 encryption"
  value       = aws_kms_alias.s3_encryption.name
}

output "kms_rds_key_id" {
  description = "ID of KMS key for RDS encryption"
  value       = aws_kms_key.rds_encryption.id
}

output "kms_rds_key_arn" {
  description = "ARN of KMS key for RDS encryption"
  value       = aws_kms_key.rds_encryption.arn
}

output "kms_rds_alias_name" {
  description = "Alias name of KMS key for RDS encryption"
  value       = aws_kms_alias.rds_encryption.name
}

output "kms_dynamodb_key_id" {
  description = "ID of KMS key for DynamoDB encryption"
  value       = aws_kms_key.dynamodb_encryption.id
}

output "kms_dynamodb_key_arn" {
  description = "ARN of KMS key for DynamoDB encryption"
  value       = aws_kms_key.dynamodb_encryption.arn
}

output "kms_dynamodb_alias_name" {
  description = "Alias name of KMS key for DynamoDB encryption"
  value       = aws_kms_alias.dynamodb_encryption.name
}

# S3 Bucket Outputs
output "s3_medical_documents_bucket_id" {
  description = "ID of medical documents S3 bucket"
  value       = aws_s3_bucket.medical_documents.id
}

output "s3_medical_documents_bucket_arn" {
  description = "ARN of medical documents S3 bucket"
  value       = aws_s3_bucket.medical_documents.arn
}

output "s3_frontend_assets_bucket_id" {
  description = "ID of frontend assets S3 bucket"
  value       = aws_s3_bucket.frontend_assets.id
}

output "s3_frontend_assets_bucket_arn" {
  description = "ARN of frontend assets S3 bucket"
  value       = aws_s3_bucket.frontend_assets.arn
}

output "s3_audit_logs_bucket_id" {
  description = "ID of audit logs S3 bucket"
  value       = aws_s3_bucket.audit_logs.id
}

output "s3_audit_logs_bucket_arn" {
  description = "ARN of audit logs S3 bucket"
  value       = aws_s3_bucket.audit_logs.arn
}

output "s3_access_logs_bucket_id" {
  description = "ID of S3 access logs bucket"
  value       = aws_s3_bucket.access_logs.id
}

output "s3_access_logs_bucket_arn" {
  description = "ARN of S3 access logs bucket"
  value       = aws_s3_bucket.access_logs.arn
}

# RDS PostgreSQL Outputs

output "rds_primary_endpoint" {
  description = "Endpoint of the primary RDS PostgreSQL instance"
  value       = aws_db_instance.primary.endpoint
  sensitive   = true
}

output "rds_primary_address" {
  description = "Address of the primary RDS PostgreSQL instance"
  value       = aws_db_instance.primary.address
  sensitive   = true
}

output "rds_primary_port" {
  description = "Port of the primary RDS PostgreSQL instance"
  value       = aws_db_instance.primary.port
}

output "rds_primary_id" {
  description = "ID of the primary RDS PostgreSQL instance"
  value       = aws_db_instance.primary.id
}

output "rds_primary_arn" {
  description = "ARN of the primary RDS PostgreSQL instance"
  value       = aws_db_instance.primary.arn
}

output "rds_primary_resource_id" {
  description = "Resource ID of the primary RDS PostgreSQL instance"
  value       = aws_db_instance.primary.resource_id
}

output "rds_database_name" {
  description = "Name of the initial database"
  value       = aws_db_instance.primary.db_name
}

output "rds_replica_1_endpoint" {
  description = "Endpoint of the first read replica"
  value       = var.rds_create_read_replicas ? aws_db_instance.read_replica_1[0].endpoint : null
  sensitive   = true
}

output "rds_replica_1_address" {
  description = "Address of the first read replica"
  value       = var.rds_create_read_replicas ? aws_db_instance.read_replica_1[0].address : null
  sensitive   = true
}

output "rds_replica_2_endpoint" {
  description = "Endpoint of the second read replica"
  value       = var.rds_create_read_replicas && var.rds_create_second_replica ? aws_db_instance.read_replica_2[0].endpoint : null
  sensitive   = true
}

output "rds_replica_2_address" {
  description = "Address of the second read replica"
  value       = var.rds_create_read_replicas && var.rds_create_second_replica ? aws_db_instance.read_replica_2[0].address : null
  sensitive   = true
}

output "rds_subnet_group_name" {
  description = "Name of the DB subnet group"
  value       = aws_db_subnet_group.main.name
}

output "rds_parameter_group_name" {
  description = "Name of the DB parameter group"
  value       = aws_db_parameter_group.postgres15.name
}

output "rds_enhanced_monitoring_role_arn" {
  description = "ARN of the RDS enhanced monitoring IAM role"
  value       = aws_iam_role.rds_enhanced_monitoring.arn
}

# DynamoDB Table Outputs

output "dynamodb_sessions_table_name" {
  description = "Name of the sessions DynamoDB table"
  value       = aws_dynamodb_table.sessions.name
}

output "dynamodb_sessions_table_arn" {
  description = "ARN of the sessions DynamoDB table"
  value       = aws_dynamodb_table.sessions.arn
}

output "dynamodb_sessions_table_id" {
  description = "ID of the sessions DynamoDB table"
  value       = aws_dynamodb_table.sessions.id
}

output "dynamodb_agent_status_table_name" {
  description = "Name of the agent_status DynamoDB table"
  value       = aws_dynamodb_table.agent_status.name
}

output "dynamodb_agent_status_table_arn" {
  description = "ARN of the agent_status DynamoDB table"
  value       = aws_dynamodb_table.agent_status.arn
}

output "dynamodb_agent_status_table_id" {
  description = "ID of the agent_status DynamoDB table"
  value       = aws_dynamodb_table.agent_status.id
}

output "dynamodb_agent_status_stream_arn" {
  description = "ARN of the agent_status DynamoDB stream"
  value       = aws_dynamodb_table.agent_status.stream_arn
}

output "dynamodb_agent_status_stream_label" {
  description = "Label of the agent_status DynamoDB stream"
  value       = aws_dynamodb_table.agent_status.stream_label
}
