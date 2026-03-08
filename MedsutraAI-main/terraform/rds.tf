# RDS PostgreSQL Configuration for AI Cancer Detection Platform
# PostgreSQL 15 instance for patient records, clinical summaries, and audit logs
# Encrypted at rest with KMS, automated backups, read replicas for high availability

# DB Subnet Group for RDS (spans multiple AZs for high availability)
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${var.project_name}-${var.environment}-db-subnet-group"
  }
}

# DB Parameter Group for PostgreSQL 15 - Optimized for performance
resource "aws_db_parameter_group" "postgres15" {
  name        = "${var.project_name}-${var.environment}-postgres15-params"
  family      = "postgres15"
  description = "Custom parameter group for PostgreSQL 15 - optimized for clinical data workloads"

  # Performance optimization parameters
  parameter {
    name  = "shared_buffers"
    value = "{DBInstanceClassMemory/4096}" # 25% of instance memory
  }

  parameter {
    name  = "effective_cache_size"
    value = "{DBInstanceClassMemory*3/4096}" # 75% of instance memory
  }

  parameter {
    name  = "maintenance_work_mem"
    value = "2097152" # 2GB in KB
  }

  parameter {
    name  = "checkpoint_completion_target"
    value = "0.9"
  }

  parameter {
    name  = "wal_buffers"
    value = "16384" # 16MB in 8KB blocks
  }

  parameter {
    name  = "default_statistics_target"
    value = "100"
  }

  parameter {
    name  = "random_page_cost"
    value = "1.1" # Optimized for SSD storage
  }

  parameter {
    name  = "effective_io_concurrency"
    value = "200" # For SSD storage
  }

  parameter {
    name  = "work_mem"
    value = "10485" # ~10MB per operation
  }

  parameter {
    name  = "min_wal_size"
    value = "2048" # 2GB
  }

  parameter {
    name  = "max_wal_size"
    value = "8192" # 8GB
  }

  # Connection settings
  parameter {
    name  = "max_connections"
    value = "200"
  }

  # Logging for audit and debugging
  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name  = "log_duration"
    value = "1"
  }

  parameter {
    name  = "log_statement"
    value = "ddl" # Log DDL statements
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-postgres15-params"
  }
}

# Primary RDS PostgreSQL Instance
resource "aws_db_instance" "primary" {
  identifier     = "${var.project_name}-${var.environment}-postgres-primary"
  engine         = "postgres"
  engine_version = "15.5"
  instance_class = var.rds_instance_class

  # Storage configuration
  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = var.rds_max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.rds_encryption.arn
  iops                  = var.rds_iops
  storage_throughput    = var.rds_storage_throughput

  # Database configuration
  db_name  = var.rds_database_name
  username = var.rds_master_username
  password = var.rds_master_password
  port     = 5432

  # Network configuration
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = var.rds_multi_az

  # Parameter and option groups
  parameter_group_name = aws_db_parameter_group.postgres15.name

  # Backup configuration - 7-day retention as per requirements
  backup_retention_period   = 7
  backup_window             = "03:00-04:00" # UTC - 8:30-9:30 AM IST (low traffic)
  maintenance_window        = "mon:04:00-mon:05:00" # UTC - 9:30-10:30 AM IST Monday
  copy_tags_to_snapshot     = true
  skip_final_snapshot       = var.rds_skip_final_snapshot
  final_snapshot_identifier = "${var.project_name}-${var.environment}-postgres-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  # Monitoring and logging
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  monitoring_interval             = 60 # Enhanced monitoring every 60 seconds
  monitoring_role_arn             = aws_iam_role.rds_enhanced_monitoring.arn
  performance_insights_enabled    = true
  performance_insights_kms_key_id = aws_kms_key.rds_encryption.arn
  performance_insights_retention_period = 7

  # Deletion protection for production
  deletion_protection = var.rds_deletion_protection

  # Auto minor version upgrade during maintenance window
  auto_minor_version_upgrade = true

  tags = {
    Name               = "${var.project_name}-${var.environment}-postgres-primary"
    DataClassification = "PHI"
    BackupRetention    = "7-days"
  }

  lifecycle {
    ignore_changes = [
      password, # Prevent password changes from triggering replacement
      final_snapshot_identifier
    ]
  }
}

# Read Replica 1 for high availability and read scaling
resource "aws_db_instance" "read_replica_1" {
  count = var.rds_create_read_replicas ? 1 : 0

  identifier     = "${var.project_name}-${var.environment}-postgres-replica-1"
  replicate_source_db = aws_db_instance.primary.identifier
  instance_class = var.rds_replica_instance_class

  # Storage configuration (inherited from primary but can be different)
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.rds_encryption.arn
  iops                  = var.rds_replica_iops
  storage_throughput    = var.rds_replica_storage_throughput

  # Network configuration
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  availability_zone      = var.availability_zones[1] # Different AZ from primary

  # Parameter group
  parameter_group_name = aws_db_parameter_group.postgres15.name

  # Backup configuration (replicas can have their own backup settings)
  backup_retention_period = 7
  skip_final_snapshot     = true

  # Monitoring
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  monitoring_interval             = 60
  monitoring_role_arn             = aws_iam_role.rds_enhanced_monitoring.arn
  performance_insights_enabled    = true
  performance_insights_kms_key_id = aws_kms_key.rds_encryption.arn
  performance_insights_retention_period = 7

  # Auto minor version upgrade
  auto_minor_version_upgrade = true

  tags = {
    Name               = "${var.project_name}-${var.environment}-postgres-replica-1"
    DataClassification = "PHI"
    ReplicaOf          = aws_db_instance.primary.identifier
  }
}

# Read Replica 2 for additional high availability
resource "aws_db_instance" "read_replica_2" {
  count = var.rds_create_read_replicas && var.rds_create_second_replica ? 1 : 0

  identifier     = "${var.project_name}-${var.environment}-postgres-replica-2"
  replicate_source_db = aws_db_instance.primary.identifier
  instance_class = var.rds_replica_instance_class

  # Storage configuration
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.rds_encryption.arn
  iops                  = var.rds_replica_iops
  storage_throughput    = var.rds_replica_storage_throughput

  # Network configuration
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  availability_zone      = var.availability_zones[2] # Third AZ

  # Parameter group
  parameter_group_name = aws_db_parameter_group.postgres15.name

  # Backup configuration
  backup_retention_period = 7
  skip_final_snapshot     = true

  # Monitoring
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  monitoring_interval             = 60
  monitoring_role_arn             = aws_iam_role.rds_enhanced_monitoring.arn
  performance_insights_enabled    = true
  performance_insights_kms_key_id = aws_kms_key.rds_encryption.arn
  performance_insights_retention_period = 7

  # Auto minor version upgrade
  auto_minor_version_upgrade = true

  tags = {
    Name               = "${var.project_name}-${var.environment}-postgres-replica-2"
    DataClassification = "PHI"
    ReplicaOf          = aws_db_instance.primary.identifier
  }
}

# IAM Role for RDS Enhanced Monitoring
resource "aws_iam_role" "rds_enhanced_monitoring" {
  name = "${var.project_name}-${var.environment}-rds-enhanced-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-enhanced-monitoring"
  }
}

# Attach AWS managed policy for RDS Enhanced Monitoring
resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# CloudWatch Alarms for RDS Monitoring

# CPU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name          = "${var.project_name}-${var.environment}-rds-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors RDS CPU utilization"
  alarm_actions       = [] # Add SNS topic ARN for notifications

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.primary.id
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-cpu-high"
  }
}

# Database Connections Alarm
resource "aws_cloudwatch_metric_alarm" "rds_connections_high" {
  alarm_name          = "${var.project_name}-${var.environment}-rds-connections-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "180" # 90% of max_connections (200)
  alarm_description   = "This metric monitors RDS database connections"
  alarm_actions       = [] # Add SNS topic ARN for notifications

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.primary.id
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-connections-high"
  }
}

# Free Storage Space Alarm
resource "aws_cloudwatch_metric_alarm" "rds_storage_low" {
  alarm_name          = "${var.project_name}-${var.environment}-rds-storage-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "10737418240" # 10 GB in bytes
  alarm_description   = "This metric monitors RDS free storage space"
  alarm_actions       = [] # Add SNS topic ARN for notifications

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.primary.id
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-storage-low"
  }
}

# Read Latency Alarm
resource "aws_cloudwatch_metric_alarm" "rds_read_latency_high" {
  alarm_name          = "${var.project_name}-${var.environment}-rds-read-latency-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ReadLatency"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "0.1" # 100ms
  alarm_description   = "This metric monitors RDS read latency"
  alarm_actions       = [] # Add SNS topic ARN for notifications

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.primary.id
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-read-latency-high"
  }
}

# Write Latency Alarm
resource "aws_cloudwatch_metric_alarm" "rds_write_latency_high" {
  alarm_name          = "${var.project_name}-${var.environment}-rds-write-latency-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "WriteLatency"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "0.1" # 100ms
  alarm_description   = "This metric monitors RDS write latency"
  alarm_actions       = [] # Add SNS topic ARN for notifications

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.primary.id
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-write-latency-high"
  }
}
