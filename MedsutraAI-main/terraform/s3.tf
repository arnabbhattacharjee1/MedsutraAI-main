# AWS S3 Configuration for AI Cancer Detection Platform
# Three buckets: medical documents (PHI), frontend assets, and audit logs
# Medical documents bucket uses KMS encryption for HIPAA/DPDP compliance

# Data source for CloudFront Origin Access Identity (for frontend bucket)
data "aws_cloudfront_log_delivery_canonical_user_id" "cloudfront" {}

# S3 Bucket for Access Logs (must be created first)
resource "aws_s3_bucket" "access_logs" {
  bucket = "${var.project_name}-access-logs-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "${var.project_name}-access-logs"
    Environment = var.environment
    Purpose     = "S3 Access Logging"
  }
}

# Block public access for access logs bucket
resource "aws_s3_bucket_public_access_block" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning for access logs bucket
resource "aws_s3_bucket_versioning" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption for access logs bucket (AES256)
resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Lifecycle policy for access logs bucket (retain for 7 years per compliance)
resource "aws_s3_bucket_lifecycle_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    id     = "transition-to-glacier"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }

    expiration {
      days = 2555 # 7 years retention
    }
  }
}

# S3 Bucket for Medical Documents (PHI - Protected Health Information)
resource "aws_s3_bucket" "medical_documents" {
  bucket = "${var.project_name}-medical-docs-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name               = "${var.project_name}-medical-documents"
    Environment        = var.environment
    DataClassification = "PHI"
    Compliance         = "HIPAA-DPDP"
  }
}

# Block public access for medical documents bucket
resource "aws_s3_bucket_public_access_block" "medical_documents" {
  bucket = aws_s3_bucket.medical_documents.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning for medical documents bucket
resource "aws_s3_bucket_versioning" "medical_documents" {
  bucket = aws_s3_bucket.medical_documents.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption with KMS for medical documents bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "medical_documents" {
  bucket = aws_s3_bucket.medical_documents.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3_encryption.arn
    }
    bucket_key_enabled = true
  }
}

# Enable access logging for medical documents bucket
resource "aws_s3_bucket_logging" "medical_documents" {
  bucket = aws_s3_bucket.medical_documents.id

  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "medical-documents/"
}

# Lifecycle policy for medical documents bucket
resource "aws_s3_bucket_lifecycle_configuration" "medical_documents" {
  bucket = aws_s3_bucket.medical_documents.id

  rule {
    id     = "transition-old-versions"
    status = "Enabled"

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 90
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 2555 # 7 years retention for compliance
    }
  }

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Bucket policy for medical documents - least privilege access
resource "aws_s3_bucket_policy" "medical_documents" {
  bucket = aws_s3_bucket.medical_documents.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyUnencryptedObjectUploads"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:PutObject"
        Resource = "${aws_s3_bucket.medical_documents.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      },
      {
        Sid    = "DenyInsecureTransport"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.medical_documents.arn,
          "${aws_s3_bucket.medical_documents.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid    = "EnforceKMSEncryption"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:PutObject"
        Resource = "${aws_s3_bucket.medical_documents.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption-aws-kms-key-id" = aws_kms_key.s3_encryption.arn
          }
        }
      }
    ]
  })
}

# S3 Bucket for Frontend Static Assets
resource "aws_s3_bucket" "frontend_assets" {
  bucket = "${var.project_name}-frontend-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "${var.project_name}-frontend-assets"
    Environment = var.environment
    Purpose     = "Static Website Hosting"
  }
}

# Block public access for frontend assets bucket (CloudFront will access via OAI)
resource "aws_s3_bucket_public_access_block" "frontend_assets" {
  bucket = aws_s3_bucket.frontend_assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning for frontend assets bucket
resource "aws_s3_bucket_versioning" "frontend_assets" {
  bucket = aws_s3_bucket.frontend_assets.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption for frontend assets bucket (AES256)
resource "aws_s3_bucket_server_side_encryption_configuration" "frontend_assets" {
  bucket = aws_s3_bucket.frontend_assets.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Enable access logging for frontend assets bucket
resource "aws_s3_bucket_logging" "frontend_assets" {
  bucket = aws_s3_bucket.frontend_assets.id

  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "frontend-assets/"
}

# Lifecycle policy for frontend assets bucket
resource "aws_s3_bucket_lifecycle_configuration" "frontend_assets" {
  bucket = aws_s3_bucket.frontend_assets.id

  rule {
    id     = "cleanup-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Bucket policy for frontend assets - CloudFront access only
resource "aws_s3_bucket_policy" "frontend_assets" {
  bucket = aws_s3_bucket.frontend_assets.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyInsecureTransport"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.frontend_assets.arn,
          "${aws_s3_bucket.frontend_assets.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# S3 Bucket for Audit Logs
resource "aws_s3_bucket" "audit_logs" {
  bucket = "${var.project_name}-audit-logs-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "${var.project_name}-audit-logs"
    Environment = var.environment
    Purpose     = "Compliance Audit Logging"
    Compliance  = "HIPAA-DPDP"
  }
}

# Block public access for audit logs bucket
resource "aws_s3_bucket_public_access_block" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning for audit logs bucket (required for compliance)
resource "aws_s3_bucket_versioning" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption for audit logs bucket (AES256)
resource "aws_s3_bucket_server_side_encryption_configuration" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Enable access logging for audit logs bucket
resource "aws_s3_bucket_logging" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "audit-logs/"
}

# Lifecycle policy for audit logs bucket (7 years retention)
resource "aws_s3_bucket_lifecycle_configuration" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  rule {
    id     = "transition-to-glacier"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }

    expiration {
      days = 2555 # 7 years retention for compliance
    }
  }

  rule {
    id     = "retain-deleted-versions"
    status = "Enabled"

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 2555 # 7 years retention
    }
  }
}

# Bucket policy for audit logs - least privilege access, prevent deletion
resource "aws_s3_bucket_policy" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyInsecureTransport"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.audit_logs.arn,
          "${aws_s3_bucket.audit_logs.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid    = "DenyUnencryptedObjectUploads"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:PutObject"
        Resource = "${aws_s3_bucket.audit_logs.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "AES256"
          }
        }
      },
      {
        Sid    = "PreventLogDeletion"
        Effect = "Deny"
        Principal = "*"
        Action = [
          "s3:DeleteObject",
          "s3:DeleteObjectVersion"
        ]
        Resource = "${aws_s3_bucket.audit_logs.arn}/*"
        Condition = {
          StringNotLike = {
            "aws:userid" = [
              "AIDAI*", # Allow only specific admin roles (placeholder)
              "${data.aws_caller_identity.current.account_id}"
            ]
          }
        }
      }
    ]
  })
}

# Enable MFA Delete protection for audit logs bucket (requires manual AWS CLI configuration)
# Note: MFA Delete can only be enabled by the root account using AWS CLI
# Command: aws s3api put-bucket-versioning --bucket <bucket-name> --versioning-configuration Status=Enabled,MFADelete=Enabled --mfa "arn:aws:iam::account-id:mfa/root-account-mfa-device serial-number"

