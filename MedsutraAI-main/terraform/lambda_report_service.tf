# ReportService Lambda Function Configuration
# Task 4.4: Implement ReportService Lambda (Python 3.11)
# Requirements: 4.1, 4.2, 4.3, 4.4, 4.6, 18.1, 18.2, 18.3, 18.4, 22.2

# =============================================================================
# IAM Role for ReportService Lambda
# =============================================================================

resource "aws_iam_role" "lambda_report_service" {
  name = "${var.project_name}-lambda-report-service-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-lambda-report-service-${var.environment}"
  })
}

# Attach basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_report_service_basic" {
  role       = aws_iam_role.lambda_report_service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Attach VPC execution policy (for RDS access)
resource "aws_iam_role_policy_attachment" "lambda_report_service_vpc" {
  role       = aws_iam_role.lambda_report_service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Policy for S3 access (medical documents bucket)
resource "aws_iam_role_policy" "lambda_report_service_s3" {
  name = "${var.project_name}-lambda-report-service-s3-${var.environment}"
  role = aws_iam_role.lambda_report_service.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "${aws_s3_bucket.medical_documents.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.medical_documents.arn
      }
    ]
  })
}

# Policy for KMS access (S3 encryption)
resource "aws_iam_role_policy" "lambda_report_service_kms" {
  name = "${var.project_name}-lambda-report-service-kms-${var.environment}"
  role = aws_iam_role.lambda_report_service.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.s3_encryption.arn
      }
    ]
  })
}

# Policy for Textract access (OCR)
resource "aws_iam_role_policy" "lambda_report_service_textract" {
  name = "${var.project_name}-lambda-report-service-textract-${var.environment}"
  role = aws_iam_role.lambda_report_service.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "textract:DetectDocumentText",
          "textract:AnalyzeDocument"
        ]
        Resource = "*"
      }
    ]
  })
}

# Policy for RDS access
resource "aws_iam_role_policy" "lambda_report_service_rds" {
  name = "${var.project_name}-lambda-report-service-rds-${var.environment}"
  role = aws_iam_role.lambda_report_service.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:DescribeDBClusters"
        ]
        Resource = "*"
      }
    ]
  })
}

# =============================================================================
# Lambda Function
# =============================================================================

resource "aws_lambda_function" "report_service" {
  filename         = "${path.module}/../lambda/report-service/report-service.zip"
  function_name    = "${var.project_name}-report-service-${var.environment}"
  role            = aws_iam_role.lambda_report_service.arn
  handler         = "lambda_function.lambda_handler"
  source_code_hash = fileexists("${path.module}/../lambda/report-service/report-service.zip") ? filebase64sha256("${path.module}/../lambda/report-service/report-service.zip") : null
  runtime         = "python3.11"
  timeout         = 300  # 5 minutes
  memory_size     = 1024

  # VPC configuration for RDS access
  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      DB_HOST        = aws_db_instance.primary.address
      DB_PORT        = aws_db_instance.primary.port
      DB_NAME        = aws_db_instance.primary.db_name
      DB_USER        = var.rds_master_username
      DB_PASSWORD    = var.rds_master_password
      DB_SSL_ENABLED = "true"
      S3_BUCKET      = aws_s3_bucket.medical_documents.id
      KMS_KEY_ID     = aws_kms_key.s3_encryption.id
      NODE_ENV       = var.environment
    }
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-report-service-${var.environment}"
  })

  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash
    ]
  }

  depends_on = [
    aws_db_instance.primary,
    aws_s3_bucket.medical_documents,
    aws_kms_key.s3_encryption,
    aws_iam_role_policy_attachment.lambda_report_service_basic,
    aws_iam_role_policy_attachment.lambda_report_service_vpc,
    aws_iam_role_policy.lambda_report_service_s3,
    aws_iam_role_policy.lambda_report_service_kms,
    aws_iam_role_policy.lambda_report_service_textract,
    aws_iam_role_policy.lambda_report_service_rds
  ]
}

# =============================================================================
# CloudWatch Log Group
# =============================================================================

resource "aws_cloudwatch_log_group" "report_service" {
  name              = "/aws/lambda/${aws_lambda_function.report_service.function_name}"
  retention_in_days = 7

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-report-service-logs-${var.environment}"
  })
}

# =============================================================================
# API Gateway Integration - POST /reports/upload
# =============================================================================

# POST method for /reports/upload
resource "aws_api_gateway_method" "post_reports_upload" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.reports_upload.id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt.id
}

# Lambda integration for POST /reports/upload
resource "aws_api_gateway_integration" "post_reports_upload" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.reports_upload.id
  http_method             = aws_api_gateway_method.post_reports_upload.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.report_service.invoke_arn
}

# Method response for POST /reports/upload
resource "aws_api_gateway_method_response" "post_reports_upload_200" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.reports_upload.id
  http_method = aws_api_gateway_method.post_reports_upload.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

# OPTIONS method for CORS on /reports/upload
resource "aws_api_gateway_method" "options_reports_upload" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.reports_upload.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# Mock integration for OPTIONS
resource "aws_api_gateway_integration" "options_reports_upload" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.reports_upload.id
  http_method = aws_api_gateway_method.options_reports_upload.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# Method response for OPTIONS
resource "aws_api_gateway_method_response" "options_reports_upload_200" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.reports_upload.id
  http_method = aws_api_gateway_method.options_reports_upload.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

# Integration response for OPTIONS
resource "aws_api_gateway_integration_response" "options_reports_upload" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.reports_upload.id
  http_method = aws_api_gateway_method.options_reports_upload.http_method
  status_code = aws_api_gateway_method_response.options_reports_upload_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# =============================================================================
# Lambda Permission for API Gateway
# =============================================================================

resource "aws_lambda_permission" "api_gateway_report_service" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.report_service.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

# =============================================================================
# Outputs
# =============================================================================

output "report_service_function_name" {
  description = "Name of the ReportService Lambda function"
  value       = aws_lambda_function.report_service.function_name
}

output "report_service_function_arn" {
  description = "ARN of the ReportService Lambda function"
  value       = aws_lambda_function.report_service.arn
}

output "report_service_invoke_arn" {
  description = "Invoke ARN of the ReportService Lambda function"
  value       = aws_lambda_function.report_service.invoke_arn
}
