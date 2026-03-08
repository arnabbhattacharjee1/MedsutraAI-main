# Amazon Cognito User Pool Configuration
# Task 3.1: Configure Amazon Cognito User Pool
# Requirements: 1.1, 13.1, 13.4

# Cognito User Pool
resource "aws_cognito_user_pool" "main" {
  name = "${var.project_name}-${var.environment}-user-pool"

  # MFA Configuration (Requirement 13.4)
  mfa_configuration = "OPTIONAL" # Users can enable MFA, admins can enforce it per user

  # Password Policy (12+ characters, complexity requirements)
  password_policy {
    minimum_length                   = 12
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 7
  }

  # Account Recovery Settings
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
    recovery_mechanism {
      name     = "verified_phone_number"
      priority = 2
    }
  }

  # Auto-verified Attributes (Email and Phone verification)
  auto_verified_attributes = ["email", "phone_number"]

  # User Attributes
  schema {
    name                     = "email"
    attribute_data_type      = "String"
    required                 = true
    mutable                  = true
    developer_only_attribute = false

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  schema {
    name                     = "phone_number"
    attribute_data_type      = "String"
    required                 = false
    mutable                  = true
    developer_only_attribute = false
  }

  schema {
    name                     = "name"
    attribute_data_type      = "String"
    required                 = true
    mutable                  = true
    developer_only_attribute = false

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  # Custom attribute for user role
  schema {
    name                     = "role"
    attribute_data_type      = "String"
    required                 = false
    mutable                  = true
    developer_only_attribute = false

    string_attribute_constraints {
      min_length = 1
      max_length = 50
    }
  }

  # Email Configuration
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  # SMS Configuration for MFA
  sms_configuration {
    external_id    = "${var.project_name}-${var.environment}-external"
    sns_caller_arn = aws_iam_role.cognito_sms.arn
    sns_region     = var.aws_region
  }

  # User Pool Add-ons
  user_pool_add_ons {
    advanced_security_mode = "ENFORCED" # Enable advanced security features
  }

  # Device Configuration
  device_configuration {
    challenge_required_on_new_device      = true
    device_only_remembered_on_user_prompt = true
  }

  # Username Configuration
  username_configuration {
    case_sensitive = false
  }

  # Verification Message Templates
  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
    email_subject        = "AI Cancer Detection Platform - Verify your email"
    email_message        = "Your verification code is {####}"
    sms_message          = "Your verification code is {####}"
  }

  # Admin Create User Configuration
  admin_create_user_config {
    allow_admin_create_user_only = false

    invite_message_template {
      email_subject = "Welcome to AI Cancer Detection Platform"
      email_message = "Your username is {username} and temporary password is {####}"
      sms_message   = "Your username is {username} and temporary password is {####}"
    }
  }

  # Account Takeover Protection
  user_pool_add_ons {
    advanced_security_mode = "ENFORCED"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-user-pool"
    Component   = "Authentication"
    Requirement = "1.1, 13.1, 13.4"
  }
}

# IAM Role for Cognito SMS
resource "aws_iam_role" "cognito_sms" {
  name = "${var.project_name}-${var.environment}-cognito-sms-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cognito-idp.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "${var.project_name}-${var.environment}-external"
          }
        }
      }
    ]
  })

  tags = {
    Name      = "${var.project_name}-${var.environment}-cognito-sms-role"
    Component = "Authentication"
  }
}

# IAM Policy for Cognito SMS
resource "aws_iam_role_policy" "cognito_sms" {
  name = "${var.project_name}-${var.environment}-cognito-sms-policy"
  role = aws_iam_role.cognito_sms.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = "*"
      }
    ]
  })
}

# User Pool Client
resource "aws_cognito_user_pool_client" "web_client" {
  name         = "${var.project_name}-${var.environment}-web-client"
  user_pool_id = aws_cognito_user_pool.main.id

  # OAuth Configuration
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code", "implicit"]
  allowed_oauth_scopes                 = ["email", "openid", "profile", "phone"]
  callback_urls                        = var.cognito_callback_urls
  logout_urls                          = var.cognito_logout_urls

  # Supported Identity Providers
  supported_identity_providers = ["COGNITO"]

  # Token Validity (Requirement 13.2 - 15 minute session timeout)
  id_token_validity      = 15 # minutes
  access_token_validity  = 15 # minutes
  refresh_token_validity = 7  # days

  token_validity_units {
    id_token      = "minutes"
    access_token  = "minutes"
    refresh_token = "days"
  }

  # Prevent user existence errors
  prevent_user_existence_errors = "ENABLED"

  # Read and Write Attributes
  read_attributes = [
    "email",
    "email_verified",
    "name",
    "phone_number",
    "phone_number_verified",
    "custom:role"
  ]

  write_attributes = [
    "email",
    "name",
    "phone_number",
    "custom:role"
  ]

  # Enable token revocation
  enable_token_revocation = true

  # Explicit auth flows
  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_PASSWORD_AUTH"
  ]
}

# User Groups for Role-Based Access Control (Requirement 13.1)

# Oncologist Group
resource "aws_cognito_user_group" "oncologist" {
  name         = "Oncologist"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Healthcare provider with full access - Oncologist role"
  precedence   = 1
  role_arn     = aws_iam_role.oncologist_role.arn
}

# Doctor Group
resource "aws_cognito_user_group" "doctor" {
  name         = "Doctor"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Healthcare provider with full access - Doctor role"
  precedence   = 2
  role_arn     = aws_iam_role.doctor_role.arn
}

# Patient Group
resource "aws_cognito_user_group" "patient" {
  name         = "Patient"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Limited access to own records only - Patient role"
  precedence   = 3
  role_arn     = aws_iam_role.patient_role.arn
}

# Admin Group
resource "aws_cognito_user_group" "admin" {
  name         = "Admin"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "System administration access - Admin role"
  precedence   = 0
  role_arn     = aws_iam_role.admin_role.arn
}

# IAM Roles for User Groups

# Oncologist IAM Role
resource "aws_iam_role" "oncologist_role" {
  name = "${var.project_name}-${var.environment}-oncologist-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_user_pool.main.id
          }
          "ForAnyValue:StringLike" = {
            "cognito-identity.amazonaws.com:amr" = "authenticated"
          }
        }
      }
    ]
  })

  tags = {
    Name      = "${var.project_name}-${var.environment}-oncologist-role"
    Component = "Authentication"
    Role      = "Oncologist"
  }
}

# Doctor IAM Role
resource "aws_iam_role" "doctor_role" {
  name = "${var.project_name}-${var.environment}-doctor-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_user_pool.main.id
          }
          "ForAnyValue:StringLike" = {
            "cognito-identity.amazonaws.com:amr" = "authenticated"
          }
        }
      }
    ]
  })

  tags = {
    Name      = "${var.project_name}-${var.environment}-doctor-role"
    Component = "Authentication"
    Role      = "Doctor"
  }
}

# Patient IAM Role
resource "aws_iam_role" "patient_role" {
  name = "${var.project_name}-${var.environment}-patient-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_user_pool.main.id
          }
          "ForAnyValue:StringLike" = {
            "cognito-identity.amazonaws.com:amr" = "authenticated"
          }
        }
      }
    ]
  })

  tags = {
    Name      = "${var.project_name}-${var.environment}-patient-role"
    Component = "Authentication"
    Role      = "Patient"
  }
}

# Admin IAM Role
resource "aws_iam_role" "admin_role" {
  name = "${var.project_name}-${var.environment}-admin-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_user_pool.main.id
          }
          "ForAnyValue:StringLike" = {
            "cognito-identity.amazonaws.com:amr" = "authenticated"
          }
        }
      }
    ]
  })

  tags = {
    Name      = "${var.project_name}-${var.environment}-admin-role"
    Component = "Authentication"
    Role      = "Admin"
  }
}

# Cognito User Pool Domain
resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${var.project_name}-${var.environment}-${random_string.domain_suffix.result}"
  user_pool_id = aws_cognito_user_pool.main.id
}

# Random string for unique domain suffix
resource "random_string" "domain_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Account Lockout Configuration using Risk Configuration
resource "aws_cognito_risk_configuration" "main" {
  user_pool_id = aws_cognito_user_pool.main.id

  account_takeover_risk_configuration {
    notify_configuration {
      from              = var.cognito_notification_email
      reply_to          = var.cognito_notification_email
      source_arn        = aws_ses_email_identity.cognito_notifications.arn
      
      block_email {
        subject     = "Suspicious Activity Detected"
        html_body   = "<p>We detected suspicious activity on your account and have blocked the sign-in attempt.</p>"
        text_body   = "We detected suspicious activity on your account and have blocked the sign-in attempt."
      }

      mfa_email {
        subject     = "MFA Required"
        html_body   = "<p>We detected unusual activity. Please complete MFA to sign in.</p>"
        text_body   = "We detected unusual activity. Please complete MFA to sign in."
      }

      no_action_email {
        subject     = "Sign-in Detected"
        html_body   = "<p>A sign-in was detected from a new location.</p>"
        text_body   = "A sign-in was detected from a new location."
      }
    }

    actions {
      event_action = "BLOCK"

      high_action {
        event_action = "BLOCK"
        notify       = true
      }

      medium_action {
        event_action = "MFA_REQUIRED"
        notify       = true
      }

      low_action {
        event_action = "NO_ACTION"
        notify       = false
      }
    }
  }

  compromised_credentials_risk_configuration {
    event_filter = ["SIGN_IN", "PASSWORD_CHANGE", "SIGN_UP"]

    actions {
      event_action = "BLOCK"
    }
  }

  risk_exception_configuration {
    blocked_ip_range_list = var.cognito_blocked_ip_ranges
  }
}

# SES Email Identity for Cognito Notifications
resource "aws_ses_email_identity" "cognito_notifications" {
  email = var.cognito_notification_email
}

# Outputs
output "cognito_user_pool_id" {
  description = "ID of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.id
}

output "cognito_user_pool_arn" {
  description = "ARN of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.arn
}

output "cognito_user_pool_endpoint" {
  description = "Endpoint of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.endpoint
}

output "cognito_user_pool_client_id" {
  description = "ID of the Cognito User Pool Client"
  value       = aws_cognito_user_pool_client.web_client.id
  sensitive   = true
}

output "cognito_user_pool_client_secret" {
  description = "Secret of the Cognito User Pool Client"
  value       = aws_cognito_user_pool_client.web_client.client_secret
  sensitive   = true
}

output "cognito_user_pool_domain" {
  description = "Domain of the Cognito User Pool"
  value       = aws_cognito_user_pool_domain.main.domain
}

output "cognito_user_pool_domain_url" {
  description = "Full URL of the Cognito User Pool Domain"
  value       = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${var.aws_region}.amazoncognito.com"
}

output "cognito_user_groups" {
  description = "List of Cognito User Groups"
  value = {
    oncologist = aws_cognito_user_group.oncologist.name
    doctor     = aws_cognito_user_group.doctor.name
    patient    = aws_cognito_user_group.patient.name
    admin      = aws_cognito_user_group.admin.name
  }
}

output "cognito_iam_roles" {
  description = "IAM Roles for Cognito User Groups"
  value = {
    oncologist = aws_iam_role.oncologist_role.arn
    doctor     = aws_iam_role.doctor_role.arn
    patient    = aws_iam_role.patient_role.arn
    admin      = aws_iam_role.admin_role.arn
  }
}
