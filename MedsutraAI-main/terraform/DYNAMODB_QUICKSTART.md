# DynamoDB Tables Quick Start Guide

## Overview

Quick reference for deploying and using DynamoDB tables for session management and real-time agent status updates.

## Prerequisites

✅ Task 1.3 completed (KMS encryption key)
✅ Task 1.1 completed (VPC with DynamoDB endpoint)

## Quick Deploy

### 1. Validate Configuration

```bash
# Run validation script
python3 validate_dynamodb.py

# Or use test script
./test_dynamodb.sh  # Linux/macOS
.\test_dynamodb.ps1  # Windows
```

### 2. Deploy Tables

```bash
# Initialize Terraform (if not done)
terraform init

# Format and validate
terraform fmt dynamodb.tf
terraform validate

# Preview changes
terraform plan

# Deploy
terraform apply -auto-approve
```

### 3. Verify Deployment

```bash
# List tables
aws dynamodb list-tables --region ap-south-1

# Check sessions table
aws dynamodb describe-table \
  --table-name ai-cancer-detection-sessions \
  --region ap-south-1

# Check agent_status table
aws dynamodb describe-table \
  --table-name ai-cancer-detection-agent-status \
  --region ap-south-1

# Verify encryption
aws dynamodb describe-table \
  --table-name ai-cancer-detection-sessions \
  --query 'Table.SSEDescription' \
  --region ap-south-1

# Verify streams
aws dynamodb describe-table \
  --table-name ai-cancer-detection-agent-status \
  --query 'Table.StreamSpecification' \
  --region ap-south-1
```

## Table Schemas

### Sessions Table

```json
{
  "session_id": "uuid-v4",
  "user_id": "cognito-sub",
  "expires_at": 1234567890,
  "ttl": 1234567890,
  "created_at": 1234567890,
  "last_activity": 1234567890,
  "persona": "healthcare_provider",
  "language": "en",
  "patient_id": "P12345"
}
```

### Agent Status Table

```json
{
  "session_id": "uuid-v4",
  "agent_id": "retrieval",
  "status": "processing",
  "updated_at": 1234567890,
  "ttl": 1234567890,
  "progress": 50,
  "output": {},
  "error": null,
  "started_at": 1234567890,
  "completed_at": null
}
```

## Common Operations

### Create Session

```python
import boto3
import time
import uuid

dynamodb = boto3.resource('dynamodb', region_name='ap-south-1')
table = dynamodb.Table('ai-cancer-detection-sessions')

session_id = str(uuid.uuid4())
current_time = int(time.time())
expires_at = current_time + 900  # 15 minutes

table.put_item(
    Item={
        'session_id': session_id,
        'user_id': 'user-123',
        'expires_at': expires_at,
        'ttl': expires_at,
        'created_at': current_time,
        'last_activity': current_time,
        'persona': 'healthcare_provider',
        'language': 'en'
    }
)
```

### Update Agent Status

```python
import boto3
import time

dynamodb = boto3.resource('dynamodb', region_name='ap-south-1')
table = dynamodb.Table('ai-cancer-detection-agent-status')

table.put_item(
    Item={
        'session_id': 'session-uuid',
        'agent_id': 'retrieval',
        'status': 'processing',
        'updated_at': int(time.time()),
        'ttl': int(time.time()) + 3600,  # 1 hour
        'progress': 50
    }
)
```

### Query Sessions by User

```python
import boto3

dynamodb = boto3.resource('dynamodb', region_name='ap-south-1')
table = dynamodb.Table('ai-cancer-detection-sessions')

response = table.query(
    IndexName='UserIdIndex',
    KeyConditionExpression='user_id = :user_id',
    ExpressionAttributeValues={
        ':user_id': 'user-123'
    }
)

sessions = response['Items']
```

### Get All Agents for Session

```python
import boto3

dynamodb = boto3.resource('dynamodb', region_name='ap-south-1')
table = dynamodb.Table('ai-cancer-detection-agent-status')

response = table.query(
    KeyConditionExpression='session_id = :session_id',
    ExpressionAttributeValues={
        ':session_id': 'session-uuid'
    }
)

agents = response['Items']
```

## IAM Policy for Lambda

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
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ],
      "Resource": "arn:aws:kms:ap-south-1:*:key/*",
      "Condition": {
        "StringEquals": {
          "kms:ViaService": "dynamodb.ap-south-1.amazonaws.com"
        }
      }
    }
  ]
}
```

## Monitoring

### CloudWatch Metrics

```bash
# View consumed capacity
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name ConsumedReadCapacityUnits \
  --dimensions Name=TableName,Value=ai-cancer-detection-sessions \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --period 3600 \
  --statistics Sum \
  --region ap-south-1

# View latency
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name SuccessfulRequestLatency \
  --dimensions Name=TableName,Value=ai-cancer-detection-sessions \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --period 3600 \
  --statistics Average \
  --region ap-south-1
```

### Create CloudWatch Alarm

```bash
# High error rate alarm
aws cloudwatch put-metric-alarm \
  --alarm-name dynamodb-sessions-high-errors \
  --alarm-description "Alert when DynamoDB sessions table has high error rate" \
  --metric-name UserErrors \
  --namespace AWS/DynamoDB \
  --statistic Sum \
  --period 300 \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1 \
  --dimensions Name=TableName,Value=ai-cancer-detection-sessions \
  --region ap-south-1
```

## Troubleshooting

### Issue: Items not being deleted by TTL

**Solution**: Ensure `ttl` attribute is set to Unix timestamp (seconds since epoch)

```python
import time
ttl = int(time.time()) + 900  # 15 minutes from now
```

### Issue: Cannot query by user_id

**Solution**: Use the UserIdIndex GSI

```python
response = table.query(
    IndexName='UserIdIndex',  # Important!
    KeyConditionExpression='user_id = :user_id',
    ExpressionAttributeValues={':user_id': 'user-123'}
)
```

### Issue: Streams not triggering Lambda

**Solution**: Check Lambda event source mapping

```bash
# List event source mappings
aws lambda list-event-source-mappings \
  --function-name your-function-name \
  --region ap-south-1

# Create event source mapping
aws lambda create-event-source-mapping \
  --function-name your-function-name \
  --event-source-arn arn:aws:dynamodb:ap-south-1:*:table/ai-cancer-detection-agent-status/stream/* \
  --starting-position LATEST \
  --region ap-south-1
```

## Cost Optimization

### Monitor Costs

```bash
# Get cost estimate
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --filter file://filter.json \
  --region us-east-1

# filter.json
{
  "Dimensions": {
    "Key": "SERVICE",
    "Values": ["Amazon DynamoDB"]
  }
}
```

### Tips
- Use TTL to automatically delete old data
- Monitor read/write patterns
- Consider reserved capacity for predictable workloads
- Use sparse indexes to reduce storage costs

## Next Steps

1. **Task 3.4**: Implement session management logic
2. **Task 4.2**: Set up API Gateway WebSocket API
3. **Task 6.4**: Implement Agent Orchestrator Service

## Resources

- [DynamoDB Documentation](https://docs.aws.amazon.com/dynamodb/)
- [DynamoDB Best Practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)
- [DynamoDB Streams](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Streams.html)
- Full documentation: `DYNAMODB.md`
