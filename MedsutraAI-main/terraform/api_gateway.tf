# API Gateway REST API Configuration
# Task 4.1: Set up API Gateway REST API
# Requirements: 26.1
# MVP Scope: Regional endpoint, CORS, logging, throttling, Lambda authorizer integration

# =============================================================================
# API Gateway REST API
# =============================================================================

resource "aws_api_gateway_rest_api" "main" {
  name        = "${var.project_name}-api-${var.environment}"
  description = "REST API for AI Cancer Detection and Clinical Summarization Platform"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-api-${var.environment}"
  })
}

# =============================================================================
# API Gateway Authorizer (JWT Lambda Authorizer)
# =============================================================================

resource "aws_api_gateway_authorizer" "jwt" {
  name                   = "${var.project_name}-jwt-authorizer-${var.environment}"
  rest_api_id            = aws_api_gateway_rest_api.main.id
  authorizer_uri         = aws_lambda_function.jwt_authorizer.invoke_arn
  authorizer_credentials = aws_iam_role.api_gateway_authorizer_invocation.arn
  type                   = "TOKEN"
  identity_source        = "method.request.header.Authorization"
  authorizer_result_ttl_in_seconds = 300 # Cache authorization for 5 minutes
}

# IAM role for API Gateway to invoke Lambda authorizer
resource "aws_iam_role" "api_gateway_authorizer_invocation" {
  name = "${var.project_name}-api-gateway-auth-invocation-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-api-gateway-auth-invocation-${var.environment}"
  })
}

# Policy to allow API Gateway to invoke Lambda authorizer
resource "aws_iam_role_policy" "api_gateway_authorizer_invocation" {
  name = "${var.project_name}-api-gateway-auth-invocation-${var.environment}"
  role = aws_iam_role.api_gateway_authorizer_invocation.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "lambda:InvokeFunction"
        Resource = aws_lambda_function.jwt_authorizer.arn
      }
    ]
  })
}

# =============================================================================
# API Gateway Resources (Endpoints)
# =============================================================================

# /patients resource
resource "aws_api_gateway_resource" "patients" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "patients"
}

# /patients/{patientId} resource
resource "aws_api_gateway_resource" "patient_by_id" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.patients.id
  path_part   = "{patientId}"
}

# /reports resource
resource "aws_api_gateway_resource" "reports" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "reports"
}

# /reports/upload resource
resource "aws_api_gateway_resource" "reports_upload" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.reports.id
  path_part   = "upload"
}

# /health resource (no auth required)
resource "aws_api_gateway_resource" "health" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "health"
}

# =============================================================================
# CloudWatch Log Group for API Gateway
# =============================================================================

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.project_name}-${var.environment}"
  retention_in_days = 7

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-api-gateway-logs-${var.environment}"
  })
}

# =============================================================================
# API Gateway Account Settings (for CloudWatch Logging)
# =============================================================================

resource "aws_api_gateway_account" "main" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch.arn
}

# IAM role for API Gateway to write to CloudWatch
resource "aws_iam_role" "api_gateway_cloudwatch" {
  name = "${var.project_name}-api-gateway-cloudwatch-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-api-gateway-cloudwatch-${var.environment}"
  })
}

# Attach managed policy for CloudWatch logging
resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch" {
  role       = aws_iam_role.api_gateway_cloudwatch.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

# =============================================================================
# API Gateway Deployment
# =============================================================================

resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  # Force new deployment on any change
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_rest_api.main.body,
      aws_api_gateway_resource.patients.id,
      aws_api_gateway_resource.patient_by_id.id,
      aws_api_gateway_resource.reports.id,
      aws_api_gateway_resource.reports_upload.id,
      aws_api_gateway_resource.health.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_rest_api.main,
    aws_api_gateway_resource.patients,
    aws_api_gateway_resource.patient_by_id,
    aws_api_gateway_resource.reports,
    aws_api_gateway_resource.reports_upload,
    aws_api_gateway_resource.health,
  ]
}

# =============================================================================
# API Gateway Stage
# =============================================================================

resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.environment

  # Enable access logging
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      caller         = "$context.identity.caller"
      user           = "$context.identity.user"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
      errorMessage   = "$context.error.message"
      errorType      = "$context.error.messageString"
    })
  }

  # Enable X-Ray tracing
  xray_tracing_enabled = true

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-api-stage-${var.environment}"
  })
}

# =============================================================================
# API Gateway Method Settings (Throttling and Logging)
# =============================================================================

resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  stage_name  = aws_api_gateway_stage.main.stage_name
  method_path = "*/*"

  settings {
    # Enable CloudWatch metrics
    metrics_enabled = true
    
    # Enable detailed CloudWatch metrics
    logging_level = "INFO"
    
    # Enable data trace logging (disable in production for sensitive data)
    data_trace_enabled = var.environment != "production"
    
    # Throttling settings
    throttling_burst_limit = 5000  # Maximum concurrent requests
    throttling_rate_limit  = 10000 # Requests per second
    
    # Caching disabled for MVP (can be enabled later)
    caching_enabled = false
  }
}

# =============================================================================
# API Gateway Usage Plan (Rate Limiting)
# =============================================================================

resource "aws_api_gateway_usage_plan" "main" {
  name        = "${var.project_name}-usage-plan-${var.environment}"
  description = "Usage plan for AI Cancer Detection API"

  api_stages {
    api_id = aws_api_gateway_rest_api.main.id
    stage  = aws_api_gateway_stage.main.stage_name
  }

  # Quota settings (requests per day)
  quota_settings {
    limit  = 1000000 # 1 million requests per day
    period = "DAY"
  }

  # Throttle settings (requests per second)
  throttle_settings {
    burst_limit = 5000  # Maximum concurrent requests
    rate_limit  = 10000 # Requests per second
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-usage-plan-${var.environment}"
  })
}

# =============================================================================
# CORS Configuration (Gateway Responses)
# =============================================================================

# CORS for 4XX responses
resource "aws_api_gateway_gateway_response" "response_4xx" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  response_type = "DEFAULT_4XX"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'GET,POST,PUT,DELETE,OPTIONS'"
  }
}

# CORS for 5XX responses
resource "aws_api_gateway_gateway_response" "response_5xx" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  response_type = "DEFAULT_5XX"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'GET,POST,PUT,DELETE,OPTIONS'"
  }
}

# CORS for Unauthorized responses
resource "aws_api_gateway_gateway_response" "unauthorized" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  response_type = "UNAUTHORIZED"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'GET,POST,PUT,DELETE,OPTIONS'"
  }

  response_templates = {
    "application/json" = jsonencode({
      message = "$context.error.messageString"
      type    = "Unauthorized"
    })
  }
}

# =============================================================================
# Outputs
# =============================================================================

output "api_gateway_id" {
  description = "ID of the API Gateway REST API"
  value       = aws_api_gateway_rest_api.main.id
}

output "api_gateway_root_resource_id" {
  description = "Root resource ID of the API Gateway"
  value       = aws_api_gateway_rest_api.main.root_resource_id
}

output "api_gateway_execution_arn" {
  description = "Execution ARN of the API Gateway"
  value       = aws_api_gateway_rest_api.main.execution_arn
}

output "api_gateway_invoke_url" {
  description = "Invoke URL of the API Gateway"
  value       = aws_api_gateway_stage.main.invoke_url
}

output "api_gateway_stage_name" {
  description = "Name of the API Gateway stage"
  value       = aws_api_gateway_stage.main.stage_name
}

output "api_gateway_authorizer_id" {
  description = "ID of the JWT authorizer"
  value       = aws_api_gateway_authorizer.jwt.id
}

output "api_gateway_patients_resource_id" {
  description = "Resource ID for /patients endpoint"
  value       = aws_api_gateway_resource.patients.id
}

output "api_gateway_patient_by_id_resource_id" {
  description = "Resource ID for /patients/{patientId} endpoint"
  value       = aws_api_gateway_resource.patient_by_id.id
}

output "api_gateway_reports_resource_id" {
  description = "Resource ID for /reports endpoint"
  value       = aws_api_gateway_resource.reports.id
}

output "api_gateway_reports_upload_resource_id" {
  description = "Resource ID for /reports/upload endpoint"
  value       = aws_api_gateway_resource.reports_upload.id
}

output "api_gateway_health_resource_id" {
  description = "Resource ID for /health endpoint"
  value       = aws_api_gateway_resource.health.id
}
