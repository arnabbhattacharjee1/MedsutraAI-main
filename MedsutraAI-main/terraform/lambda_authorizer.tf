# Lambda Authorizer for API Gateway
# Task 3.2: Implement JWT token management
# Requirements: 13.2, 20.1

# IAM role for Lambda authorizer
resource "aws_iam_role" "lambda_authorizer" {
  name = "${var.project_name}-lambda-authorizer-role-${var.environment}"

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
    Name = "${var.project_name}-lambda-authorizer-role-${var.environment}"
  })
}

# Attach basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_authorizer_basic" {
  role       = aws_iam_role.lambda_authorizer.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda function for JWT authorization
resource "aws_lambda_function" "jwt_authorizer" {
  filename         = "${path.module}/../lambda/authorizer/authorizer.zip"
  function_name    = "${var.project_name}-jwt-authorizer-${var.environment}"
  role            = aws_iam_role.lambda_authorizer.arn
  handler         = "index.handler"
  source_code_hash = fileexists("${path.module}/../lambda/authorizer/authorizer.zip") ? filebase64sha256("${path.module}/../lambda/authorizer/authorizer.zip") : null
  runtime         = "nodejs20.x"
  timeout         = 30
  memory_size     = 256

  environment {
    variables = {
      COGNITO_USER_POOL_ID = aws_cognito_user_pool.main.id
      COGNITO_REGION       = var.aws_region
    }
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-jwt-authorizer-${var.environment}"
  })

  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash
    ]
  }
}

# CloudWatch Log Group for authorizer
resource "aws_cloudwatch_log_group" "jwt_authorizer" {
  name              = "/aws/lambda/${aws_lambda_function.jwt_authorizer.function_name}"
  retention_in_days = 7

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-jwt-authorizer-logs-${var.environment}"
  })
}

# IAM role for token refresh Lambda
resource "aws_iam_role" "lambda_token_refresh" {
  name = "${var.project_name}-lambda-token-refresh-role-${var.environment}"

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
    Name = "${var.project_name}-lambda-token-refresh-role-${var.environment}"
  })
}

# Attach basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_token_refresh_basic" {
  role       = aws_iam_role.lambda_token_refresh.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Policy for Cognito access
resource "aws_iam_role_policy" "lambda_token_refresh_cognito" {
  name = "${var.project_name}-lambda-token-refresh-cognito-${var.environment}"
  role = aws_iam_role.lambda_token_refresh.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:InitiateAuth",
          "cognito-idp:RespondToAuthChallenge"
        ]
        Resource = aws_cognito_user_pool.main.arn
      }
    ]
  })
}

# Lambda function for token refresh
resource "aws_lambda_function" "token_refresh" {
  filename         = "${path.module}/../lambda/token-refresh/token-refresh.zip"
  function_name    = "${var.project_name}-token-refresh-${var.environment}"
  role            = aws_iam_role.lambda_token_refresh.arn
  handler         = "index.handler"
  source_code_hash = fileexists("${path.module}/../lambda/token-refresh/token-refresh.zip") ? filebase64sha256("${path.module}/../lambda/token-refresh/token-refresh.zip") : null
  runtime         = "nodejs20.x"
  timeout         = 30
  memory_size     = 256

  environment {
    variables = {
      COGNITO_USER_POOL_ID = aws_cognito_user_pool.main.id
      COGNITO_CLIENT_ID    = aws_cognito_user_pool_client.web_client.id
      COGNITO_REGION       = var.aws_region
    }
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-token-refresh-${var.environment}"
  })

  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash
    ]
  }
}

# CloudWatch Log Group for token refresh
resource "aws_cloudwatch_log_group" "token_refresh" {
  name              = "/aws/lambda/${aws_lambda_function.token_refresh.function_name}"
  retention_in_days = 7

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-token-refresh-logs-${var.environment}"
  })
}

# Outputs
output "jwt_authorizer_function_name" {
  description = "Name of the JWT authorizer Lambda function"
  value       = aws_lambda_function.jwt_authorizer.function_name
}

output "jwt_authorizer_function_arn" {
  description = "ARN of the JWT authorizer Lambda function"
  value       = aws_lambda_function.jwt_authorizer.arn
}

output "jwt_authorizer_invoke_arn" {
  description = "Invoke ARN of the JWT authorizer Lambda function"
  value       = aws_lambda_function.jwt_authorizer.invoke_arn
}

output "token_refresh_function_name" {
  description = "Name of the token refresh Lambda function"
  value       = aws_lambda_function.token_refresh.function_name
}

output "token_refresh_function_arn" {
  description = "ARN of the token refresh Lambda function"
  value       = aws_lambda_function.token_refresh.arn
}
