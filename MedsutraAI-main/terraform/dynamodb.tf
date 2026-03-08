# DynamoDB Tables for AI Cancer Detection Platform
# Tables for session management and real-time agent status updates
# Supports WebSocket-based real-time updates in the frontend

# Sessions Table - Real-time Session State Management
resource "aws_dynamodb_table" "sessions" {
  name           = "${var.project_name}-sessions"
  billing_mode   = "PAY_PER_REQUEST" # On-demand capacity mode
  hash_key       = "session_id"
  
  attribute {
    name = "session_id"
    type = "S"
  }
  
  attribute {
    name = "user_id"
    type = "S"
  }
  
  attribute {
    name = "expires_at"
    type = "N"
  }
  
  # Global Secondary Index for querying sessions by user_id
  global_secondary_index {
    name            = "UserIdIndex"
    hash_key        = "user_id"
    projection_type = "ALL"
  }
  
  # Global Secondary Index for querying sessions by expiration time
  global_secondary_index {
    name            = "ExpiresAtIndex"
    hash_key        = "expires_at"
    projection_type = "ALL"
  }
  
  # TTL configuration for automatic session cleanup
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }
  
  # Server-side encryption with customer-managed KMS key
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb_encryption.arn
  }
  
  # Point-in-time recovery for data protection
  point_in_time_recovery {
    enabled = true
  }
  
  tags = {
    Name            = "${var.project_name}-sessions-table"
    Service         = "DynamoDB"
    DataType        = "SessionState"
    Environment     = var.environment
  }
}

# Agent Status Table - Real-time Agent Status for WebSocket Broadcasting
resource "aws_dynamodb_table" "agent_status" {
  name           = "${var.project_name}-agent-status"
  billing_mode   = "PAY_PER_REQUEST" # On-demand capacity mode
  hash_key       = "session_id"
  range_key      = "agent_id"
  
  attribute {
    name = "session_id"
    type = "S"
  }
  
  attribute {
    name = "agent_id"
    type = "S"
  }
  
  attribute {
    name = "updated_at"
    type = "N"
  }
  
  # Global Secondary Index for querying agent status by update time
  global_secondary_index {
    name            = "UpdatedAtIndex"
    hash_key        = "session_id"
    range_key       = "updated_at"
    projection_type = "ALL"
  }
  
  # TTL configuration for automatic cleanup of old agent status records
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }
  
  # Server-side encryption with customer-managed KMS key
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb_encryption.arn
  }
  
  # Point-in-time recovery for data protection
  point_in_time_recovery {
    enabled = true
  }
  
  # DynamoDB Streams for real-time change capture (used by WebSocket handlers)
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"
  
  tags = {
    Name            = "${var.project_name}-agent-status-table"
    Service         = "DynamoDB"
    DataType        = "AgentStatus"
    Environment     = var.environment
  }
}
