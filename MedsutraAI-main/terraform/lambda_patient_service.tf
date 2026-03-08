# PatientService Lambda Function Configuration
# Task 4.3: Implement PatientService Lambda (Node.js 20)
# Requirements: 2.6, 14.1, 14.4, 22.1

# =============================================================================
# IAM Role for PatientService Lambda
# =============================================================================

resource "aws_iam_role" "lambda_patient_service" {
  name = "${var.project_name}-lambda-patient-service-${var.environment}"

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
    Name = "${var.project_name}-lambda-patient-service-${var.environment}"
  })
}

# Attach basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_patient_service_basic" {
  role       = aws_iam_role.lambda_patient_service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Attach VPC execution policy (for RDS access)
resource "aws_iam_role_policy_attachment" "lambda_patient_service_vpc" {
  role       = aws_iam_role.lambda_patient_service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Policy for RDS access
resource "aws_iam_role_policy" "lambda_patient_service_rds" {
  name = "${var.project_name}-lambda-patient-service-rds-${var.environment}"
  role = aws_iam_role.lambda_patient_service.id

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

resource "aws_lambda_function" "patient_service" {
  filename         = "${path.module}/../lambda/patient-service/patient-service.zip"
  function_name    = "${var.project_name}-patient-service-${var.environment}"
  role            = aws_iam_role.lambda_patient_service.arn
  handler         = "index.handler"
  source_code_hash = fileexists("${path.module}/../lambda/patient-service/patient-service.zip") ? filebase64sha256("${path.module}/../lambda/patient-service/patient-service.zip") : null
  runtime         = "nodejs20.x"
  timeout         = 30
  memory_size     = 512

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
      NODE_ENV       = var.environment
    }
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-patient-service-${var.environment}"
  })

  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash
    ]
  }

  depends_on = [
    aws_db_instance.primary,
    aws_iam_role_policy_attachment.lambda_patient_service_basic,
    aws_iam_role_policy_attachment.lambda_patient_service_vpc
  ]
}

# =============================================================================
# CloudWatch Log Group
# =============================================================================

resource "aws_cloudwatch_log_group" "patient_service" {
  name              = "/aws/lambda/${aws_lambda_function.patient_service.function_name}"
  retention_in_days = 7

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-patient-service-logs-${var.environment}"
  })
}

# =============================================================================
# API Gateway Integration - GET /patients/{patientId}
# =============================================================================

# GET method for /patients/{patientId}
resource "aws_api_gateway_method" "get_patient_by_id" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.patient_by_id.id
  http_method   = "GET"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt.id

  request_parameters = {
    "method.request.path.patientId" = true
  }
}

# Lambda integration for GET /patients/{patientId}
resource "aws_api_gateway_integration" "get_patient_by_id" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.patient_by_id.id
  http_method             = aws_api_gateway_method.get_patient_by_id.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.patient_service.invoke_arn
}

# Method response for GET /patients/{patientId}
resource "aws_api_gateway_method_response" "get_patient_by_id_200" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.patient_by_id.id
  http_method = aws_api_gateway_method.get_patient_by_id.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

# OPTIONS method for CORS on /patients/{patientId}
resource "aws_api_gateway_method" "options_patient_by_id" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.patient_by_id.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# Mock integration for OPTIONS
resource "aws_api_gateway_integration" "options_patient_by_id" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.patient_by_id.id
  http_method = aws_api_gateway_method.options_patient_by_id.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# Method response for OPTIONS
resource "aws_api_gateway_method_response" "options_patient_by_id_200" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.patient_by_id.id
  http_method = aws_api_gateway_method.options_patient_by_id.http_method
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
resource "aws_api_gateway_integration_response" "options_patient_by_id" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.patient_by_id.id
  http_method = aws_api_gateway_method.options_patient_by_id.http_method
  status_code = aws_api_gateway_method_response.options_patient_by_id_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# =============================================================================
# Lambda Permission for API Gateway
# =============================================================================

resource "aws_lambda_permission" "api_gateway_patient_service" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.patient_service.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

# =============================================================================
# Outputs
# =============================================================================

output "patient_service_function_name" {
  description = "Name of the PatientService Lambda function"
  value       = aws_lambda_function.patient_service.function_name
}

output "patient_service_function_arn" {
  description = "ARN of the PatientService Lambda function"
  value       = aws_lambda_function.patient_service.arn
}

output "patient_service_invoke_arn" {
  description = "Invoke ARN of the PatientService Lambda function"
  value       = aws_lambda_function.patient_service.invoke_arn
}
