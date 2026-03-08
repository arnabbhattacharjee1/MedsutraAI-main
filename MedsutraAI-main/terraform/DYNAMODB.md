# DynamoDB Tables Configuration

## Overview

This document describes the DynamoDB tables configuration for the AI Cancer Detection and Clinical Summarization platform. The tables support session management and real-time agent status updates for WebSocket-based communication.

## Architecture

### Tables

1. **Sessions Table** (`ai-cancer-detection-sessions`)
   - Purpose: Real-time session state management
   - Primary Key: `session_id` (String)
   - Use Case: Store user session data, authentication state, and session metadata

2. **Agent Status Table** (`ai-cancer-detection-agent-status`)
   - Purpose: Real-time agent status for WebSocket broadcasting
   - Primary Key: `session_id` (String) + `agent_id` (String)
   - Use Case: Track AI agent execution status and broadcast updates to frontend

## Table Schemas

### Sessions Table

```
Primary Key:
  - session_id (S) - Hash Key

Attributes:
  - session_id (S) - Unique session identifier
  - user_id (S) - User identifier (Cognito sub)
  - expires_at (N) - Session expiration timestamp (Unix epoch)
  - ttl (N) - TTL attribute for automatic cleanup
  - created_at (N) - Session creation timestamp
  - last_activity (N) - Last activity timestamp
  - persona (S) - User persona (healthcare_provider | patient)
  - language (S) - Selected language code
  - patient_id (S) - Current patient ID (optional)

Global Secondary Indexes:
  1. UserIdIndex
     - Hash Key: user_id
     - Projection: ALL
     - Use Case: Query all sessions for a user (prevent concurrent sessions)
  
  2. ExpiresAtIndex
     - Hash Key: expires_at
     - Projection: ALL
     - Use Case: Query sessions by expiration time (cleanup queries)

TTL Configuration:
  - Attribute: ttl
  - Enabled: true
  - Cleanup: Automatic deletion after 15 minutes of inactivity
```

### Agent Status Table

```
Primary Key:
  - session_id (S) - Hash Key
  - agent_id (S) - Range Key

Attributes:
  - session_id (S) - Session identifier
  - agent_id (S) - Agent identifier (retrieval | summarization | cancer_risk | explainability | voice)
  - status (S) - Agent status (pending | processing | completed | failed)
  - updated_at (N) - Last update timestamp
  - ttl (N) - TTL attribute for automatic cleanup
  - progress (N) - Progress percentage (0-100)
  - output (M) - Agent output data (Map)
  - error (S) - Error message (if failed)
  - started_at (N) - Processing start timestamp
  - completed_at (N) - Processing completion timestamp

Global Secondary Index:
  1. UpdatedAtIndex
     - Hash Key: session_id
     - Range Key: updated_at
     - Projection: ALL
     - Use Case: Query agent status updates in chronological order

DynamoDB Streams:
  - Enabled: true
  - View Type: NEW_AND_OLD_IMAGES
  - Use Case: Trigger Lambda functions to broadcast updates via WebSocket
```

## Configuration Details

### Billing Mode

Both tables use **PAY_PER_REQUEST** (on-demand) billing mode:
- No capacity planning required
- Automatic scaling based on traffic
- Cost-effective for variable workloads
- Ideal for MVP and early production stages

### Encryption

Both tables use **server-side encryption** with customer-managed KMS keys:
- KMS Key: `aws_kms_key.dynamodb_encryption`
- Encryption at rest: Enabled
- Key rotation: Automatic (yearly)
- Compliance: DPDP Act, HIPAA-ready

### TTL (Time To Live)

Both tables have TTL enabled for automatic cleanup:
- **Sessions Table**: Cleanup after 15 minutes of inactivity
- **Agent Status Table**: Cleanup after session expiration
- TTL Attribute: `ttl` (Unix timestamp)
- Cost Savings: Automatic deletion reduces storage costs

### Point-in-Time Recovery

Both tables have point-in-time recovery enabled:
- Recovery window: 35 days
- Granularity: 1 second
- Use Case: Disaster recovery, accidental deletions

### DynamoDB Streams

The **agent_status** table has DynamoDB Streams enabled:
- Stream View Type: NEW_AND_OLD_IMAGES
- Use Case: Trigger Lambda functions for WebSocket broadcasting
- Integration: API Gateway WebSocket API

## Access Patterns

### Sessions Table

1. **Create Session**
   ```
   PutItem: session_id, user_id, expires_at, ttl, created_at, ...
   ```

2. **Get Session**
   ```
   GetItem: session_id
   ```

3. **Update Session Activity**
   ```
   UpdateItem: session_id
   Set: last_activity, expires_at, ttl
   ```

4. **Check Concurrent Sessions**
   ```
   Query: UserIdIndex
   KeyCondition: user_id = :user_id
   FilterExpression: expires_at > :current_time
   ```

5. **Delete Session (Logout)**
   ```
   DeleteItem: session_id
   ```

### Agent Status Table

1. **Create Agent Status**
   ```
   PutItem: session_id, agent_id, status, updated_at, ttl, ...
   ```

2. **Update Agent Status**
   ```
   UpdateItem: session_id, agent_id
   Set: status, progress, updated_at, output, ...
   ```

3. **Get Agent Status**
   ```
   GetItem: session_id, agent_id
   ```

4. **Get All Agents for Session**
   ```
   Query: session_id
   ```

5. **Get Agent Updates (Chronological)**
   ```
   Query: UpdatedAtIndex
   KeyCondition: session_id = :session_id AND updated_at > :timestamp
   ```

## Integration with Other Services

### API Gateway WebSocket API

The agent_status table integrates with API Gateway WebSocket API:

1. **DynamoDB Stream** → **Lambda Function** → **WebSocket API**
2. When agent status changes, DynamoDB Stream triggers Lambda
3. Lambda function broadcasts update to connected WebSocket clients
4. Frontend receives real-time agent status updates

### Lambda Functions

Lambda functions interact with DynamoDB tables:

1. **Session Management Lambda**
   - Create/update/delete sessions
   - Validate session tokens
   - Enforce 15-minute timeout

2. **Agent Orchestrator Lambda**
   - Update agent status
   - Track agent progress
   - Handle agent failures

3. **WebSocket Handler Lambda**
   - Process DynamoDB Stream events
   - Broadcast updates to WebSocket clients
   - Manage WebSocket connections

### Amazon Cognito

Sessions table stores Cognito user information:
- `user_id`: Cognito user sub
- Session creation on successful authentication
- Session invalidation on logout

## Security

### IAM Policies

Lambda functions require IAM policies for DynamoDB access:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query"
      ],
      "Resource": [
        "arn:aws:dynamodb:ap-south-1:*:table/ai-cancer-detection-sessions",
        "arn:aws:dynamodb:ap-south-1:*:table/ai-cancer-detection-sessions/index/*",
        "arn:aws:dynamodb:ap-south-1:*:table/ai-cancer-detection-agent-status",
        "arn:aws:dynamodb:ap-south-1:*:table/ai-cancer-detection-agent-status/index/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetRecords",
        "dynamodb:GetShardIterator",
        "dynamodb:DescribeStream",
        "dynamodb:ListStreams"
      ],
      "Resource": [
        "arn:aws:dynamodb:ap-south-1:*:table/ai-cancer-detection-agent-status/stream/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ],
      "Resource": [
        "arn:aws:kms:ap-south-1:*:key/*"
      ],
      "Condition": {
        "StringEquals": {
          "kms:ViaService": "dynamodb.ap-south-1.amazonaws.com"
        }
      }
    }
  ]
}
```

### VPC Endpoints

Lambda functions in private subnets access DynamoDB via VPC endpoints:
- Endpoint: `aws_vpc_endpoint.dynamodb`
- No internet gateway required
- Reduced latency and improved security

## Monitoring and Alarms

### CloudWatch Metrics

Monitor DynamoDB table metrics:

1. **Read/Write Capacity**
   - ConsumedReadCapacityUnits
   - ConsumedWriteCapacityUnits
   - (Not applicable for on-demand mode, but useful for cost tracking)

2. **Latency**
   - SuccessfulRequestLatency
   - Target: < 10ms for GetItem/PutItem

3. **Errors**
   - UserErrors (4xx)
   - SystemErrors (5xx)
   - ThrottledRequests

4. **TTL Deletions**
   - TimeToLiveDeletedItemCount
   - Monitor automatic cleanup

### CloudWatch Alarms

Set up alarms for critical metrics:

1. **High Error Rate**
   - Metric: UserErrors + SystemErrors
   - Threshold: > 10 errors in 5 minutes
   - Action: SNS notification

2. **High Latency**
   - Metric: SuccessfulRequestLatency
   - Threshold: > 50ms (p99)
   - Action: SNS notification

3. **Stream Processing Lag**
   - Metric: IteratorAge (for DynamoDB Streams)
   - Threshold: > 60 seconds
   - Action: SNS notification

## Cost Optimization

### On-Demand Billing

On-demand mode is cost-effective for:
- Variable workloads
- Unpredictable traffic patterns
- MVP and early production stages

Cost calculation:
- Write: $1.25 per million write request units
- Read: $0.25 per million read request units
- Storage: $0.25 per GB-month

### TTL for Automatic Cleanup

TTL reduces storage costs:
- Automatic deletion of expired sessions
- No manual cleanup required
- No additional cost for TTL deletions

### Reserved Capacity (Future)

For predictable workloads, consider reserved capacity:
- Up to 76% cost savings
- 1-year or 3-year commitment
- Switch from on-demand to provisioned mode

## Testing

### Validation Scripts

Run validation scripts to verify configuration:

```bash
# Linux/macOS
chmod +x test_dynamodb.sh
./test_dynamodb.sh

# Windows PowerShell
.\test_dynamodb.ps1
```

### Python Validation

Run Python validation script:

```bash
python3 validate_dynamodb.py
```

### Terraform Commands

```bash
# Format Terraform files
terraform fmt dynamodb.tf

# Validate configuration
terraform validate

# Plan changes
terraform plan

# Apply changes
terraform apply

# Verify outputs
terraform output | grep dynamodb
```

## Deployment

### Prerequisites

1. KMS key for DynamoDB encryption (Task 1.3)
2. VPC with private subnets (Task 1.1)
3. VPC endpoint for DynamoDB (Task 1.1)

### Deployment Steps

1. **Review Configuration**
   ```bash
   cat dynamodb.tf
   ```

2. **Run Validation**
   ```bash
   ./test_dynamodb.sh
   ```

3. **Plan Changes**
   ```bash
   terraform plan -out=dynamodb.tfplan
   ```

4. **Apply Changes**
   ```bash
   terraform apply dynamodb.tfplan
   ```

5. **Verify Tables**
   ```bash
   aws dynamodb list-tables --region ap-south-1
   aws dynamodb describe-table --table-name ai-cancer-detection-sessions --region ap-south-1
   aws dynamodb describe-table --table-name ai-cancer-detection-agent-status --region ap-south-1
   ```

6. **Verify Encryption**
   ```bash
   aws dynamodb describe-table --table-name ai-cancer-detection-sessions \
     --query 'Table.SSEDescription' --region ap-south-1
   ```

7. **Verify Streams**
   ```bash
   aws dynamodb describe-table --table-name ai-cancer-detection-agent-status \
     --query 'Table.StreamSpecification' --region ap-south-1
   ```

## Troubleshooting

### Common Issues

1. **KMS Key Not Found**
   - Error: `InvalidParameterException: KMS key not found`
   - Solution: Ensure Task 1.3 (KMS setup) is completed
   - Verify: `terraform output kms_dynamodb_key_arn`

2. **VPC Endpoint Not Configured**
   - Error: `Unable to connect to DynamoDB`
   - Solution: Ensure VPC endpoint for DynamoDB is created (Task 1.1)
   - Verify: `terraform output vpc_endpoint_dynamodb_id`

3. **TTL Not Working**
   - Issue: Items not being deleted automatically
   - Solution: Ensure `ttl` attribute is set to Unix timestamp
   - Verify: Check CloudWatch metric `TimeToLiveDeletedItemCount`

4. **Streams Not Triggering Lambda**
   - Issue: Lambda not receiving stream events
   - Solution: Verify Lambda event source mapping
   - Check: Lambda function has correct IAM permissions for streams

### Debug Commands

```bash
# Check table status
aws dynamodb describe-table --table-name ai-cancer-detection-sessions \
  --query 'Table.TableStatus' --region ap-south-1

# Check TTL status
aws dynamodb describe-time-to-live --table-name ai-cancer-detection-sessions \
  --region ap-south-1

# Check stream status
aws dynamodb describe-table --table-name ai-cancer-detection-agent-status \
  --query 'Table.LatestStreamArn' --region ap-south-1

# List GSIs
aws dynamodb describe-table --table-name ai-cancer-detection-sessions \
  --query 'Table.GlobalSecondaryIndexes[*].IndexName' --region ap-south-1
```

## Next Steps

After completing this task:

1. **Task 2.4**: Implement database migration scripts
2. **Task 3.1**: Configure Amazon Cognito User Pool
3. **Task 3.4**: Implement session management logic
4. **Task 4.2**: Set up API Gateway WebSocket API
5. **Task 6.4**: Implement Agent Orchestrator Service

## References

- [AWS DynamoDB Documentation](https://docs.aws.amazon.com/dynamodb/)
- [DynamoDB Best Practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)
- [DynamoDB Streams](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Streams.html)
- [DynamoDB TTL](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/TTL.html)
- Requirements: 13.2 (Session timeout), 20.1 (Session management)
