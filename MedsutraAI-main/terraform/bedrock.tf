# Amazon Bedrock Configuration
# Task 7.3: Configure Amazon Bedrock access
# Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 6.8

# Data source to check Bedrock model availability
data "aws_bedrock_foundation_models" "available" {
  by_provider = "Anthropic"
}

# IAM Role for EKS pods to access Bedrock (IRSA - IAM Roles for Service Accounts)
resource "aws_iam_role" "bedrock_eks_role" {
  name               = "${var.project_name}-bedrock-eks-role-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:ai-agents:bedrock-service-account"
            "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-bedrock-eks-role-${var.environment}"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Purpose     = "Bedrock access for AI agents"
  }
}

# IAM Policy for Bedrock model invocation
resource "aws_iam_policy" "bedrock_invoke_policy" {
  name        = "${var.project_name}-bedrock-invoke-policy-${var.environment}"
  description = "Policy for invoking Amazon Bedrock models"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "BedrockModelInvocation"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = [
          "arn:aws:bedrock:${var.aws_region}::foundation-model/anthropic.claude-3-sonnet-20240229-v1:0",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/anthropic.claude-3-haiku-20240307-v1:0",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/amazon.titan-embed-text-v2:0"
        ]
      },
      {
        Sid    = "BedrockModelListing"
        Effect = "Allow"
        Action = [
          "bedrock:ListFoundationModels",
          "bedrock:GetFoundationModel"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchLogsForBedrock"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/bedrock/*"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-bedrock-invoke-policy-${var.environment}"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Attach Bedrock policy to EKS role
resource "aws_iam_role_policy_attachment" "bedrock_eks_policy_attachment" {
  role       = aws_iam_role.bedrock_eks_role.name
  policy_arn = aws_iam_policy.bedrock_invoke_policy.arn
}

# IAM Role for Lambda functions to access Bedrock
resource "aws_iam_role" "bedrock_lambda_role" {
  name               = "${var.project_name}-bedrock-lambda-role-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-bedrock-lambda-role-${var.environment}"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Purpose     = "Bedrock access for Lambda functions"
  }
}

# Attach Bedrock policy to Lambda role
resource "aws_iam_role_policy_attachment" "bedrock_lambda_policy_attachment" {
  role       = aws_iam_role.bedrock_lambda_role.name
  policy_arn = aws_iam_policy.bedrock_invoke_policy.arn
}

# Attach basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "bedrock_lambda_basic_execution" {
  role       = aws_iam_role.bedrock_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# CloudWatch Log Group for Bedrock invocations
resource "aws_cloudwatch_log_group" "bedrock_invocations" {
  name              = "/aws/bedrock/${var.project_name}-${var.environment}"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.main.arn

  tags = {
    Name        = "${var.project_name}-bedrock-logs-${var.environment}"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# CloudWatch Log Group for model invocation metrics
resource "aws_cloudwatch_log_group" "bedrock_metrics" {
  name              = "/aws/bedrock/${var.project_name}-${var.environment}/metrics"
  retention_in_days = 90
  kms_key_id        = aws_kms_key.main.arn

  tags = {
    Name        = "${var.project_name}-bedrock-metrics-${var.environment}"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}

# Data source for EKS cluster (assuming it will be created)
data "aws_eks_cluster" "cluster" {
  name = "${var.project_name}-eks-${var.environment}"
  
  depends_on = [
    # Add dependency on EKS cluster resource when it's created
  ]
}

# SSM Parameter for Bedrock configuration
resource "aws_ssm_parameter" "bedrock_config" {
  name        = "/${var.project_name}/${var.environment}/bedrock/config"
  description = "Amazon Bedrock configuration for AI agents"
  type        = "String"
  value = jsonencode({
    models = {
      clinical_summarization = {
        model_id     = "anthropic.claude-3-sonnet-20240229-v1:0"
        max_tokens   = 4096
        temperature  = 0.7
        top_p        = 0.9
      }
      explainability = {
        model_id     = "anthropic.claude-3-sonnet-20240229-v1:0"
        max_tokens   = 2048
        temperature  = 0.5
        top_p        = 0.9
      }
      translation = {
        model_id     = "anthropic.claude-3-haiku-20240307-v1:0"
        max_tokens   = 2048
        temperature  = 0.3
        top_p        = 0.9
      }
      embeddings = {
        model_id    = "amazon.titan-embed-text-v2:0"
        dimensions  = 1024
      }
    }
    region = var.aws_region
    logging = {
      enabled    = true
      log_group  = aws_cloudwatch_log_group.bedrock_invocations.name
    }
    rate_limits = {
      requests_per_minute = 100
      tokens_per_minute   = 100000
    }
  })

  tags = {
    Name        = "${var.project_name}-bedrock-config-${var.environment}"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Outputs
output "bedrock_eks_role_arn" {
  description = "ARN of the IAM role for EKS pods to access Bedrock"
  value       = aws_iam_role.bedrock_eks_role.arn
}

output "bedrock_lambda_role_arn" {
  description = "ARN of the IAM role for Lambda functions to access Bedrock"
  value       = aws_iam_role.bedrock_lambda_role.arn
}

output "bedrock_config_parameter" {
  description = "SSM parameter name containing Bedrock configuration"
  value       = aws_ssm_parameter.bedrock_config.name
}

output "bedrock_log_group" {
  description = "CloudWatch log group for Bedrock invocations"
  value       = aws_cloudwatch_log_group.bedrock_invocations.name
}
