# Task 2.3 Completion: Set up DynamoDB Tables

## Status: ✅ COMPLETED

## Overview

Successfully created DynamoDB tables configuration for session management and real-time agent status updates. This is a **critical path task for MVP** that enables WebSocket-based real-time updates in the frontend.

## Deliverables

### 1. DynamoDB Tables Configuration (`dynamodb.tf`)

Created two DynamoDB tables with complete configuration:

#### Sessions Table (`ai-cancer-detection-sessions`)
- **Purpose**: Real-time session state management
- **Primary Key**: `session_id` (String)
- **Billing Mode**: PAY_PER_REQUEST (on-demand)
- **Encryption**: KMS encryption using `aws_kms_key.dynamodb_encryption`
- **TTL**: Enabled for automatic session cleanup after 15 minutes
- **Point-in-Time Recovery**: Enabled
- **Global Secondary Indexes**:
  - `UserIdIndex`: Query sessions by user_id (prevent concurrent sessions)
  - `ExpiresAtIndex`: Query sessions by expiration time (cleanup queries)

#### Agent Status Table (`ai-cancer-detection-agent-status`)
- **Purpose**: Real-time agent status for WebSocket broadcasting
- **Primary Key**: `session_id` (String) + `agent_id` (String)
- **Billing Mode**: PAY_PER_REQUEST (on-demand)
- **Encryption**: KMS encryption using `aws_kms_key.dynamodb_encryption`
- **TTL**: Enabled for automatic cleanup
- **Point-in-Time Recovery**: Enabled
- **DynamoDB Streams**: Enabled with NEW_AND_OLD_IMAGES view type
- **Global Secondary Index**:
  - `UpdatedAtIndex`: Query agent status by update time

### 2. Outputs Configuration (`outputs.tf`)

Added 8 outputs for DynamoDB tables:
- Table names, ARNs, and IDs for both tables
- Stream ARN and label for agent_status table

### 3. Validation Scripts

Created comprehensive validation scripts:
- `validate_dynamodb.py`: Python validation script with detailed checks
- `test_dynamodb.sh`: Bash test script for Linux/macOS
- `test_dynamodb.ps1`: PowerShell test script for Windows

### 4. Documentation (`DYNAMODB.md`)

Created comprehensive documentation covering:
- Architecture and table schemas
- Access patterns and use cases
- Integration with other services (API Gateway, Lambda, Cognito)
- Security and IAM policies
- Monitoring and alarms
- Cost optimization strategies
- Deployment steps and troubleshooting

## Requirements Satisfied

✅ **Requirement 13.2**: Session timeout implementation
- TTL configured for automatic session cleanup after 15 minutes
- Sessions table tracks session expiration

✅ **Requirement 20.1**: Session management
- Sessions table stores session state with unique identifiers
- Support for session creation, validation, and invalidation
- Prevention of concurrent sessions via UserIdIndex

## Key Features

### Security
- ✅ Encryption at rest using customer-managed KMS key
- ✅ KMS key from Task 1.3 (`aws_kms_key.dynamodb_encryption`)
- ✅ Point-in-time recovery for data protection
- ✅ VPC endpoint integration for secure access

### Scalability
- ✅ On-demand capacity mode (no capacity planning required)
- ✅ Automatic scaling based on traffic
- ✅ Global Secondary Indexes for efficient queries

### Real-Time Updates
- ✅ DynamoDB Streams enabled on agent_status table
- ✅ Stream view type: NEW_AND_OLD_IMAGES
- ✅ Integration ready for WebSocket broadcasting

### Cost Optimization
- ✅ TTL for automatic cleanup (reduces storage costs)
- ✅ On-demand billing (pay only for what you use)
- ✅ Efficient GSI design

## Integration Points

### Upstream Dependencies (Completed)
- ✅ Task 1.3: KMS encryption key for DynamoDB
- ✅ Task 1.1: VPC with DynamoDB endpoint

### Downstream Dependencies (Next Steps)
- Task 3.4: Session management logic (will use sessions table)
- Task 4.2: API Gateway WebSocket API (will use agent_status streams)
- Task 6.4: Agent Orchestrator Service (will update agent_status table)

## Files Created

```
infrastructure/terraform/
├── dynamodb.tf                    # DynamoDB tables configuration
├── outputs.tf                     # Updated with DynamoDB outputs
├── validate_dynamodb.py           # Python validation script
├── test_dynamodb.sh              # Bash test script
├── test_dynamodb.ps1             # PowerShell test script
├── DYNAMODB.md                   # Comprehensive documentation
└── TASK_2.3_COMPLETION.md        # This file
```

## Configuration Summary

### Sessions Table Schema
```
Primary Key: session_id (S)
Attributes:
  - session_id (S)
  - user_id (S)
  - expires_at (N)
  - ttl (N)
  - created_at (N)
  - last_activity (N)
  - persona (S)
  - language (S)
  - patient_id (S)

GSIs:
  - UserIdIndex (user_id)
  - ExpiresAtIndex (expires_at)
```

### Agent Status Table Schema
```
Primary Key: session_id (S) + agent_id (S)
Attributes:
  - session_id (S)
  - agent_id (S)
  - status (S)
  - updated_at (N)
  - ttl (N)
  - progress (N)
  - output (M)
  - error (S)
  - started_at (N)
  - completed_at (N)

GSI:
  - UpdatedAtIndex (session_id + updated_at)

Streams: Enabled (NEW_AND_OLD_IMAGES)
```

## Testing

### Validation Tests

The validation scripts check:
1. ✅ Terraform syntax validation
2. ✅ Required resources present
3. ✅ Encryption configuration (KMS)
4. ✅ TTL configuration (both tables)
5. ✅ Billing mode (on-demand)
6. ✅ DynamoDB Streams (agent_status)
7. ✅ Global Secondary Indexes (3 total)
8. ✅ Point-in-time recovery (both tables)

### Running Tests

```bash
# Linux/macOS
chmod +x test_dynamodb.sh
./test_dynamodb.sh

# Windows PowerShell
.\test_dynamodb.ps1

# Python validation
python3 validate_dynamodb.py
```

## Deployment Steps

1. **Review Configuration**
   ```bash
   cat dynamodb.tf
   ```

2. **Validate Terraform**
   ```bash
   terraform fmt dynamodb.tf
   terraform validate
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
   aws dynamodb describe-table --table-name ai-cancer-detection-sessions
   aws dynamodb describe-table --table-name ai-cancer-detection-agent-status
   ```

## Cost Estimate

### On-Demand Pricing (ap-south-1 region)
- Write requests: $1.25 per million write request units
- Read requests: $0.25 per million read request units
- Storage: $0.25 per GB-month

### Estimated Monthly Cost (MVP)
Assuming:
- 10,000 sessions/day
- 5 agents per session
- Average session: 5 minutes

**Sessions Table**:
- Writes: ~10,000/day × 30 = 300,000/month = $0.38
- Reads: ~50,000/day × 30 = 1,500,000/month = $0.38
- Storage: ~1 GB = $0.25

**Agent Status Table**:
- Writes: ~50,000/day × 30 = 1,500,000/month = $1.88
- Reads: ~100,000/day × 30 = 3,000,000/month = $0.75
- Storage: ~2 GB = $0.50

**Total Estimated Cost**: ~$4.14/month (MVP scale)

## Security Considerations

### Encryption
- ✅ Server-side encryption with customer-managed KMS key
- ✅ Automatic key rotation enabled
- ✅ Encryption in transit via HTTPS/TLS

### Access Control
- ✅ IAM policies required for Lambda access
- ✅ VPC endpoint for private subnet access
- ✅ Least privilege access patterns

### Compliance
- ✅ DPDP Act: Encryption at rest and in transit
- ✅ HIPAA-ready: Audit trails via CloudWatch
- ✅ Session timeout: 15-minute inactivity

## Monitoring

### CloudWatch Metrics
- ConsumedReadCapacityUnits
- ConsumedWriteCapacityUnits
- SuccessfulRequestLatency
- UserErrors / SystemErrors
- TimeToLiveDeletedItemCount

### Recommended Alarms
1. High error rate (> 10 errors in 5 minutes)
2. High latency (> 50ms p99)
3. Stream processing lag (> 60 seconds)

## Next Steps

1. **Task 2.4**: Implement database migration scripts
2. **Task 3.4**: Implement session management logic
   - Create session on authentication
   - Validate session tokens
   - Enforce 15-minute timeout
   - Prevent concurrent sessions

3. **Task 4.2**: Set up API Gateway WebSocket API
   - Configure WebSocket routes
   - Set up Lambda integrations
   - Connect to DynamoDB Streams

4. **Task 6.4**: Implement Agent Orchestrator Service
   - Update agent_status table
   - Track agent progress
   - Handle agent failures

## References

- Design Document: Section on DynamoDB tables
- Requirements: 13.2 (Session timeout), 20.1 (Session management)
- Task 1.3: KMS encryption key setup
- Task 1.1: VPC and DynamoDB endpoint

## Notes

- **MVP Critical Path**: This task is on the critical path for MVP delivery
- **WebSocket Integration**: DynamoDB Streams enable real-time updates
- **Cost-Effective**: On-demand billing is ideal for MVP and early production
- **Scalable**: No capacity planning required, automatic scaling
- **Secure**: Encryption at rest with customer-managed KMS key

---

**Task Completed**: 2024-01-XX
**Completed By**: Kiro AI Assistant
**Validated**: Configuration validated, ready for deployment
