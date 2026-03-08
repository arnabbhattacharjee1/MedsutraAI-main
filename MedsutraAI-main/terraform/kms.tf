# AWS KMS Configuration for AI Cancer Detection Platform
# Customer-managed keys for encrypting patient data at rest
# Supports S3 (medical documents), RDS (patient records), and DynamoDB (session state)

# KMS Key for S3 - Medical Documents and Reports
resource "aws_kms_key" "s3_encryption" {
  description             = "KMS key for S3 bucket encryption - medical documents and reports"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  
  tags = {
    Name            = "${var.project_name}-s3-kms-key"
    DataClassification = "PHI" # Protected Health Information
    Service         = "S3"
  }
}

resource "aws_kms_alias" "s3_encryption" {
  name          = "alias/${var.project_name}-s3-encryption"
  target_key_id = aws_kms_key.s3_encryption.key_id
}

# KMS Key Policy for S3
resource "aws_kms_key_policy" "s3_encryption" {
  key_id = aws_kms_key.s3_encryption.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow S3 to use the key"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "s3.${var.aws_region}.amazonaws.com"
          }
        }
      },
      {
        Sid    = "Allow CloudFront to use the key"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })
}

# KMS Key for RDS - Patient Records Database
resource "aws_kms_key" "rds_encryption" {
  description             = "KMS key for RDS encryption - patient records and metadata"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  
  tags = {
    Name            = "${var.project_name}-rds-kms-key"
    DataClassification = "PHI" # Protected Health Information
    Service         = "RDS"
  }
}

resource "aws_kms_alias" "rds_encryption" {
  name          = "alias/${var.project_name}-rds-encryption"
  target_key_id = aws_kms_key.rds_encryption.key_id
}

# KMS Key Policy for RDS
resource "aws_kms_key_policy" "rds_encryption" {
  key_id = aws_kms_key.rds_encryption.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow RDS to use the key"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:CreateGrant",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "rds.${var.aws_region}.amazonaws.com"
          }
        }
      },
      {
        Sid    = "Allow RDS Enhanced Monitoring"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })
}

# KMS Key for DynamoDB - Session State and Real-time Data
resource "aws_kms_key" "dynamodb_encryption" {
  description             = "KMS key for DynamoDB encryption - session state and agent status"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  
  tags = {
    Name            = "${var.project_name}-dynamodb-kms-key"
    DataClassification = "Session-Data"
    Service         = "DynamoDB"
  }
}

resource "aws_kms_alias" "dynamodb_encryption" {
  name          = "alias/${var.project_name}-dynamodb-encryption"
  target_key_id = aws_kms_key.dynamodb_encryption.key_id
}

# KMS Key Policy for DynamoDB
resource "aws_kms_key_policy" "dynamodb_encryption" {
  key_id = aws_kms_key.dynamodb_encryption.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow DynamoDB to use the key"
        Effect = "Allow"
        Principal = {
          Service = "dynamodb.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:CreateGrant",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "dynamodb.${var.aws_region}.amazonaws.com"
          }
        }
      },
      {
        Sid    = "Allow DynamoDB Streams"
        Effect = "Allow"
        Principal = {
          Service = "dynamodb.amazonaws.com"
        }
        Action = [
          "kms:Decrypt"
        ]
        Resource = "*"
      }
    ]
  })
}

# Data source for current AWS account ID
data "aws_caller_identity" "current" {}
