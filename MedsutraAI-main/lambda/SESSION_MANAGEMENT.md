# Session Management Lambda Function

## Overview

The Session Manager Lambda function provides comprehensive session management for the AI Cancer Detection and Clinical Summarization Platform. It handles session creation, validation, activity tracking, and invalidation with support for 15-minute inactivity timeouts and concurrent session prevention.

## Requirements Addressed

- **Requirement 13.3**: Automatic session timeout after 15 minutes of inactivity
- **Requirement 20.1**: Secure session with unique session identifier
- **Requirement 20.2**: Invalidate session after 15 minutes of inactivity
- **Requirement 20.3**: Redirect to authentication page when session expires
- **Requirement 20.4**: Immediately invalidate session on logout
- **Requirement 20.5**: Prevent concurrent sessions for same user account

## Architecture

### Components

1. **Session Manager Lambda** (`session-manager/index.js`)
   - Handles all session operations
   - Integrates with DynamoDB for session storage
   - Implements 15-minute inactivity timeout
   - Prevents concurrent sessions

2. **DynamoDB Sessions Table**
   - Table name: `{project_name}-sessions`
   - Partition key: `session_id` (String)
   - GSI: `UserIdIndex` on `user_id`
   - TTL enabled on `ttl` attribute

### Session Data Model

```javascript
{
  session_id: String,      // Unique session identifier (UUID)
  user_id: String,         // User identifier from Cognito
  user_email: String,      // User email
  user_groups: Array,      // User groups/roles
  created_at: Number,      // Timestamp (milliseconds)
  last_activity: Number,   // Timestamp (milliseconds)
  expires_at: Number,      // Expiration timestamp (milliseconds)
  ttl: Number,            // TTL for DynamoDB (seconds)
  is_active: Boolean      // Session active status
}
```

## API Endpoints

### 1. Create Session

**POST /sessions**

Creates a new session for a user. Automatically invalidates any existing active sessions for the same user (Requirement 20.5).

**Request Body:**
```json
{
  "userId": "string",
  "userEmail": "string",
  "userGroups": ["string"]
}
```

**Response (201 Created):**
```json
{
  "sessionId": "uuid",
  "expiresAt": 1234567890000,
  "expiresIn": 900
}
```

**Error Responses:**
- `400 Bad Request`: Missing userId
- `500 Internal Server Error`: Server error

### 2. Validate Session

**POST /sessions/validate**

Validates a session and returns session details if valid. Automatically invalidates expired sessions (Requirement 20.2).

**Request Body:**
```json
{
  "sessionId": "string"
}
```

**Response (200 OK):**
```json
{
  "valid": true,
  "session": {
    "sessionId": "uuid",
    "userId": "string",
    "userEmail": "string",
    "userGroups": ["string"],
    "lastActivity": 1234567890000,
    "expiresAt": 1234567890000
  }
}
```

**Error Responses:**
- `400 Bad Request`: Missing sessionId
- `401 Unauthorized`: Session not found, expired, or inactive
- `500 Internal Server Error`: Server error

### 3. Update Session Activity

**PUT /sessions/activity**

Updates the last activity timestamp and extends the session expiration by 15 minutes (Requirement 13.3).

**Request Body:**
```json
{
  "sessionId": "string"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "expiresAt": 1234567890000,
  "expiresIn": 900
}
```

**Error Responses:**
- `400 Bad Request`: Missing sessionId
- `404 Not Found`: Session not found or inactive
- `500 Internal Server Error`: Server error

### 4. Invalidate Session (Logout)

**DELETE /sessions**

Immediately invalidates a session (Requirement 20.4).

**Request Body:**
```json
{
  "sessionId": "string"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Session invalidated successfully"
}
```

**Error Responses:**
- `400 Bad Request`: Missing sessionId
- `404 Not Found`: Session not found
- `500 Internal Server Error`: Server error

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SESSIONS_TABLE` | DynamoDB sessions table name | Required |
| `SESSION_TIMEOUT_MINUTES` | Session timeout in minutes | 15 |
| `AWS_REGION` | AWS region | us-east-1 |

## Session Lifecycle

### 1. Session Creation

```
User Login
    ↓
Create Session Request
    ↓
Query Existing Sessions (UserIdIndex)
    ↓
Invalidate Existing Sessions (Requirement 20.5)
    ↓
Generate Unique Session ID (UUID)
    ↓
Calculate Expiration (now + 15 minutes)
    ↓
Store in DynamoDB
    ↓
Return Session ID
```

### 2. Session Validation

```
API Request
    ↓
Validate Session Request
    ↓
Query Session by ID
    ↓
Check if Active
    ↓
Check if Expired (Requirement 20.2)
    ↓
If Expired: Invalidate Session
    ↓
Return Validation Result
```

### 3. Activity Tracking

```
User Activity
    ↓
Update Activity Request
    ↓
Update last_activity Timestamp
    ↓
Extend expires_at (now + 15 minutes)
    ↓
Update TTL
    ↓
Return Success
```

### 4. Session Invalidation

```
User Logout
    ↓
Invalidate Session Request
    ↓
Set is_active = false
    ↓
Return Success
```

## Security Features

### 1. Unique Session Identifiers (Requirement 20.1)

- Uses cryptographically secure UUID v4
- Unpredictable and unique across all sessions
- Prevents session hijacking through guessing

### 2. Automatic Timeout (Requirements 13.3, 20.2)

- 15-minute inactivity timeout
- Automatic expiration checking on validation
- TTL-based cleanup in DynamoDB

### 3. Concurrent Session Prevention (Requirement 20.5)

- Queries existing sessions by user_id
- Invalidates all existing sessions before creating new one
- Ensures only one active session per user

### 4. Immediate Logout (Requirement 20.4)

- Instant session invalidation on logout
- Sets is_active flag to false
- Prevents further use of session

## Integration with Frontend

### Session Creation (After Login)

```javascript
// After successful Cognito authentication
const response = await fetch('/sessions', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    userId: cognitoUser.sub,
    userEmail: cognitoUser.email,
    userGroups: cognitoUser['cognito:groups']
  })
});

const { sessionId, expiresAt } = await response.json();
// Store sessionId in secure cookie or localStorage
```

### Session Validation (On Page Load)

```javascript
const sessionId = getSessionId(); // From cookie/localStorage

const response = await fetch('/sessions/validate', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ sessionId })
});

if (response.status === 401) {
  // Session expired - redirect to login (Requirement 20.3)
  window.location.href = '/login';
}
```

### Activity Tracking (On User Interaction)

```javascript
// Call on user interactions (clicks, API calls, etc.)
const updateActivity = async () => {
  const sessionId = getSessionId();
  
  await fetch('/sessions/activity', {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ sessionId })
  });
};

// Throttle to avoid excessive calls
const throttledUpdate = throttle(updateActivity, 60000); // Every minute
```

### Logout

```javascript
const logout = async () => {
  const sessionId = getSessionId();
  
  await fetch('/sessions', {
    method: 'DELETE',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ sessionId })
  });
  
  // Clear local session data
  clearSessionId();
  
  // Redirect to login
  window.location.href = '/login';
};
```

## Testing

### Unit Tests

The session manager includes comprehensive unit tests covering:

1. **Session Creation**
   - Successful session creation
   - Concurrent session prevention (Requirement 20.5)
   - Missing userId validation

2. **Session Validation**
   - Valid active session
   - Expired session handling (Requirement 20.2)
   - Non-existent session
   - Inactive session

3. **Activity Updates**
   - Successful activity update (Requirement 13.3)
   - Non-existent session handling
   - Missing sessionId validation

4. **Session Invalidation**
   - Successful logout (Requirement 20.4)
   - Non-existent session handling
   - Missing sessionId validation

5. **Error Handling**
   - CORS preflight requests
   - Unknown endpoints
   - Internal errors

### Running Tests

```bash
cd infrastructure/lambda/session-manager
npm install
npm test
```

### Test Coverage

- All core functions tested
- Edge cases covered
- Error scenarios validated
- AWS SDK calls mocked

## Deployment

### Prerequisites

1. DynamoDB sessions table created (Task 2.3)
2. Lambda execution role with DynamoDB permissions
3. API Gateway configured

### Deployment Steps

1. **Package Lambda Function**
   ```bash
   cd infrastructure/lambda/session-manager
   npm install --production
   zip -r session-manager.zip .
   ```

2. **Deploy to AWS Lambda**
   ```bash
   aws lambda create-function \
     --function-name session-manager \
     --runtime nodejs20.x \
     --role arn:aws:iam::ACCOUNT_ID:role/lambda-execution-role \
     --handler index.handler \
     --zip-file fileb://session-manager.zip \
     --environment Variables="{SESSIONS_TABLE=cancer-detection-sessions,SESSION_TIMEOUT_MINUTES=15}" \
     --timeout 30 \
     --memory-size 256
   ```

3. **Configure API Gateway**
   - Create REST API endpoints
   - Integrate with Lambda function
   - Enable CORS
   - Deploy to stage

### IAM Permissions

The Lambda execution role requires:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:UpdateItem",
        "dynamodb:Query"
      ],
      "Resource": [
        "arn:aws:dynamodb:REGION:ACCOUNT_ID:table/SESSIONS_TABLE",
        "arn:aws:dynamodb:REGION:ACCOUNT_ID:table/SESSIONS_TABLE/index/UserIdIndex"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
```

## Monitoring and Logging

### CloudWatch Metrics

Monitor the following metrics:

- Lambda invocations
- Error rate
- Duration
- Concurrent executions

### CloudWatch Logs

The function logs:

- Session creation events
- Session validation results
- Activity updates
- Invalidation events
- Errors and exceptions

### Alarms

Set up CloudWatch alarms for:

- High error rate (> 5%)
- Long duration (> 5 seconds)
- Throttling events

## Performance Considerations

### DynamoDB Optimization

- On-demand capacity mode for variable load
- GSI on user_id for efficient concurrent session queries
- TTL for automatic cleanup of expired sessions

### Lambda Configuration

- Memory: 256 MB (sufficient for DynamoDB operations)
- Timeout: 30 seconds
- Concurrent executions: Auto-scaling based on load

### Caching

Consider implementing:

- Session validation caching (short TTL)
- Connection pooling for DynamoDB
- Lambda warm-up for reduced cold starts

## Troubleshooting

### Common Issues

1. **Session Not Found**
   - Verify sessionId is correct
   - Check if session expired (TTL cleanup)
   - Verify DynamoDB table name

2. **Concurrent Session Not Prevented**
   - Verify UserIdIndex exists
   - Check query permissions
   - Review invalidation logic

3. **Session Not Expiring**
   - Verify TTL is enabled on table
   - Check expires_at calculation
   - Review SESSION_TIMEOUT_MINUTES setting

4. **High Latency**
   - Check DynamoDB capacity
   - Review Lambda memory allocation
   - Optimize query patterns

## Future Enhancements

1. **Session Refresh Tokens**
   - Long-lived refresh tokens
   - Automatic session renewal

2. **Multi-Device Support**
   - Allow multiple sessions per user
   - Device fingerprinting
   - Session management UI

3. **Advanced Security**
   - IP address validation
   - Geolocation checks
   - Anomaly detection

4. **Analytics**
   - Session duration tracking
   - User activity patterns
   - Login frequency analysis

## References

- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/)
- [DynamoDB TTL](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/TTL.html)
- [API Gateway Integration](https://docs.aws.amazon.com/apigateway/latest/developerguide/getting-started.html)
- [Session Management Best Practices](https://owasp.org/www-community/Session_Management_Cheat_Sheet)
