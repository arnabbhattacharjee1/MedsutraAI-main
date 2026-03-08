# Session Management Quick Start Guide

## Overview

This guide helps you quickly set up and test the session management system for the AI Cancer Detection Platform.

## Prerequisites

- AWS Account with appropriate permissions
- DynamoDB sessions table created (from Task 2.3)
- Node.js 20.x installed
- AWS CLI configured

## Quick Setup (5 minutes)

### Step 1: Verify DynamoDB Table

```bash
aws dynamodb describe-table --table-name cancer-detection-sessions
```

Expected output should show:
- Partition key: `session_id`
- GSI: `UserIdIndex` on `user_id`
- TTL enabled on `ttl` attribute

### Step 2: Install Dependencies

```bash
cd infrastructure/lambda/session-manager
npm install
```

### Step 3: Run Tests

```bash
npm test
```

All tests should pass, confirming the implementation is correct.

### Step 4: Deploy Lambda Function

```bash
# Package the function
zip -r session-manager.zip index.js package.json node_modules/

# Deploy to AWS
aws lambda create-function \
  --function-name cancer-detection-session-manager \
  --runtime nodejs20.x \
  --role arn:aws:iam::YOUR_ACCOUNT_ID:role/lambda-execution-role \
  --handler index.handler \
  --zip-file fileb://session-manager.zip \
  --environment Variables="{SESSIONS_TABLE=cancer-detection-sessions,SESSION_TIMEOUT_MINUTES=15}" \
  --timeout 30 \
  --memory-size 256
```

### Step 5: Test the Function

Create a test event:

```json
{
  "httpMethod": "POST",
  "path": "/sessions",
  "body": "{\"userId\":\"test-user-123\",\"userEmail\":\"test@example.com\",\"userGroups\":[\"Doctor\"]}"
}
```

Invoke the function:

```bash
aws lambda invoke \
  --function-name cancer-detection-session-manager \
  --payload file://test-event.json \
  response.json

cat response.json
```

Expected response:
```json
{
  "statusCode": 201,
  "body": "{\"sessionId\":\"...\",\"expiresAt\":...,\"expiresIn\":900}"
}
```

## API Endpoints

### 1. Create Session

```bash
curl -X POST https://your-api-gateway-url/sessions \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "user-123",
    "userEmail": "user@example.com",
    "userGroups": ["Doctor"]
  }'
```

### 2. Validate Session

```bash
curl -X POST https://your-api-gateway-url/sessions/validate \
  -H "Content-Type: application/json" \
  -d '{
    "sessionId": "your-session-id"
  }'
```

### 3. Update Activity

```bash
curl -X PUT https://your-api-gateway-url/sessions/activity \
  -H "Content-Type: application/json" \
  -d '{
    "sessionId": "your-session-id"
  }'
```

### 4. Logout

```bash
curl -X DELETE https://your-api-gateway-url/sessions \
  -H "Content-Type: application/json" \
  -d '{
    "sessionId": "your-session-id"
  }'
```

## Testing Scenarios

### Scenario 1: Normal Session Flow

```bash
# 1. Create session
SESSION_ID=$(curl -X POST https://your-api-gateway-url/sessions \
  -H "Content-Type: application/json" \
  -d '{"userId":"user-123","userEmail":"user@example.com","userGroups":["Doctor"]}' \
  | jq -r '.sessionId')

# 2. Validate session
curl -X POST https://your-api-gateway-url/sessions/validate \
  -H "Content-Type: application/json" \
  -d "{\"sessionId\":\"$SESSION_ID\"}"

# 3. Update activity
curl -X PUT https://your-api-gateway-url/sessions/activity \
  -H "Content-Type: application/json" \
  -d "{\"sessionId\":\"$SESSION_ID\"}"

# 4. Logout
curl -X DELETE https://your-api-gateway-url/sessions \
  -H "Content-Type: application/json" \
  -d "{\"sessionId\":\"$SESSION_ID\"}"
```

### Scenario 2: Concurrent Session Prevention

```bash
# Create first session
SESSION_1=$(curl -X POST https://your-api-gateway-url/sessions \
  -H "Content-Type: application/json" \
  -d '{"userId":"user-123","userEmail":"user@example.com","userGroups":["Doctor"]}' \
  | jq -r '.sessionId')

# Create second session for same user (should invalidate first)
SESSION_2=$(curl -X POST https://your-api-gateway-url/sessions \
  -H "Content-Type: application/json" \
  -d '{"userId":"user-123","userEmail":"user@example.com","userGroups":["Doctor"]}' \
  | jq -r '.sessionId')

# Validate first session (should fail)
curl -X POST https://your-api-gateway-url/sessions/validate \
  -H "Content-Type: application/json" \
  -d "{\"sessionId\":\"$SESSION_1\"}"
# Expected: 401 Unauthorized

# Validate second session (should succeed)
curl -X POST https://your-api-gateway-url/sessions/validate \
  -H "Content-Type: application/json" \
  -d "{\"sessionId\":\"$SESSION_2\"}"
# Expected: 200 OK
```

### Scenario 3: Session Expiration

```bash
# Create session
SESSION_ID=$(curl -X POST https://your-api-gateway-url/sessions \
  -H "Content-Type: application/json" \
  -d '{"userId":"user-123","userEmail":"user@example.com","userGroups":["Doctor"]}' \
  | jq -r '.sessionId')

# Wait 16 minutes (or modify SESSION_TIMEOUT_MINUTES for testing)
sleep 960

# Validate session (should fail due to expiration)
curl -X POST https://your-api-gateway-url/sessions/validate \
  -H "Content-Type: application/json" \
  -d "{\"sessionId\":\"$SESSION_ID\"}"
# Expected: 401 Unauthorized with reason "Session expired"
```

## Frontend Integration Example

### React Hook for Session Management

```javascript
import { useState, useEffect, useCallback } from 'react';

const API_BASE_URL = 'https://your-api-gateway-url';

export function useSession() {
  const [sessionId, setSessionId] = useState(
    localStorage.getItem('sessionId')
  );
  const [isValid, setIsValid] = useState(false);

  // Create session after login
  const createSession = useCallback(async (userId, userEmail, userGroups) => {
    const response = await fetch(`${API_BASE_URL}/sessions`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ userId, userEmail, userGroups })
    });

    if (response.ok) {
      const { sessionId } = await response.json();
      localStorage.setItem('sessionId', sessionId);
      setSessionId(sessionId);
      setIsValid(true);
      return sessionId;
    }
    throw new Error('Failed to create session');
  }, []);

  // Validate session
  const validateSession = useCallback(async () => {
    if (!sessionId) {
      setIsValid(false);
      return false;
    }

    const response = await fetch(`${API_BASE_URL}/sessions/validate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ sessionId })
    });

    if (response.ok) {
      setIsValid(true);
      return true;
    } else {
      setIsValid(false);
      localStorage.removeItem('sessionId');
      setSessionId(null);
      return false;
    }
  }, [sessionId]);

  // Update activity
  const updateActivity = useCallback(async () => {
    if (!sessionId) return;

    await fetch(`${API_BASE_URL}/sessions/activity`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ sessionId })
    });
  }, [sessionId]);

  // Logout
  const logout = useCallback(async () => {
    if (!sessionId) return;

    await fetch(`${API_BASE_URL}/sessions`, {
      method: 'DELETE',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ sessionId })
    });

    localStorage.removeItem('sessionId');
    setSessionId(null);
    setIsValid(false);
  }, [sessionId]);

  // Validate on mount and set up activity tracking
  useEffect(() => {
    validateSession();

    // Update activity every minute
    const interval = setInterval(updateActivity, 60000);
    return () => clearInterval(interval);
  }, [validateSession, updateActivity]);

  return {
    sessionId,
    isValid,
    createSession,
    validateSession,
    updateActivity,
    logout
  };
}
```

### Usage in Component

```javascript
import { useSession } from './hooks/useSession';
import { useNavigate } from 'react-router-dom';

function Dashboard() {
  const { isValid, logout } = useSession();
  const navigate = useNavigate();

  useEffect(() => {
    if (!isValid) {
      navigate('/login');
    }
  }, [isValid, navigate]);

  const handleLogout = async () => {
    await logout();
    navigate('/login');
  };

  return (
    <div>
      <h1>Dashboard</h1>
      <button onClick={handleLogout}>Logout</button>
    </div>
  );
}
```

## Monitoring

### CloudWatch Logs

View logs:
```bash
aws logs tail /aws/lambda/cancer-detection-session-manager --follow
```

### CloudWatch Metrics

View metrics:
```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value=cancer-detection-session-manager \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --period 3600 \
  --statistics Sum
```

## Troubleshooting

### Issue: Session not found after creation

**Solution:**
1. Check DynamoDB table name in environment variables
2. Verify Lambda has permissions to write to DynamoDB
3. Check CloudWatch logs for errors

### Issue: Concurrent sessions not prevented

**Solution:**
1. Verify UserIdIndex exists on DynamoDB table
2. Check Lambda has permissions to query the index
3. Review query logic in CloudWatch logs

### Issue: Sessions not expiring

**Solution:**
1. Verify TTL is enabled on DynamoDB table
2. Check `ttl` attribute is being set correctly
3. Wait for TTL cleanup (can take up to 48 hours)

## Next Steps

1. **Integrate with Cognito** (Task 3.1, 3.2)
   - Use Cognito user attributes for session creation
   - Validate JWT tokens before creating sessions

2. **Set up API Gateway** (Task 4.1)
   - Create REST API endpoints
   - Configure Lambda integrations
   - Enable CORS

3. **Implement Frontend** (Task 15)
   - Use session management hooks
   - Handle session expiration
   - Implement activity tracking

4. **Add Monitoring** (Task 32)
   - Set up CloudWatch alarms
   - Create dashboards
   - Configure notifications

## Support

For issues or questions:
- Check CloudWatch logs
- Review SESSION_MANAGEMENT.md for detailed documentation
- Verify all prerequisites are met
- Test with provided scenarios

## Requirements Checklist

- [x] **Requirement 13.3**: 15-minute inactivity timeout implemented
- [x] **Requirement 20.1**: Unique session identifiers (UUID)
- [x] **Requirement 20.2**: Automatic session invalidation on expiration
- [x] **Requirement 20.3**: Frontend redirects on expiration (integration needed)
- [x] **Requirement 20.4**: Immediate invalidation on logout
- [x] **Requirement 20.5**: Concurrent session prevention
