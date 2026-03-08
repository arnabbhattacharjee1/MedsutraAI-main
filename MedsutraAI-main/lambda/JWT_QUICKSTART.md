# JWT Token Management - Quick Start Guide

## 5-Minute Setup

### Prerequisites
- ✅ Task 3.1 completed (Cognito User Pool configured)
- ✅ Node.js 20.x installed
- ✅ AWS CLI configured
- ✅ Terraform initialized

### Step 1: Package Lambda Functions (2 minutes)

```bash
cd infrastructure/lambda

# Linux/Mac
chmod +x deploy.sh
./deploy.sh

# Windows
.\deploy.ps1
```

**Expected output:**
```
✓ Created authorizer/authorizer.zip
✓ Created token-refresh/token-refresh.zip
```

### Step 2: Deploy with Terraform (2 minutes)

```bash
cd ../terraform

terraform apply -auto-approve
```

**Expected output:**
```
Apply complete! Resources: 8 added, 0 changed, 0 destroyed.

Outputs:
jwt_authorizer_function_arn = "arn:aws:lambda:us-east-1:123456789012:function:cancer-detection-jwt-authorizer-dev"
token_refresh_function_arn = "arn:aws:lambda:us-east-1:123456789012:function:cancer-detection-token-refresh-dev"
```

### Step 3: Test Token Validation (1 minute)

```bash
# Get Cognito details
USER_POOL_ID=$(terraform output -raw cognito_user_pool_id)
CLIENT_ID=$(terraform output -raw cognito_user_pool_client_id)

# Create test user
aws cognito-idp admin-create-user \
  --user-pool-id $USER_POOL_ID \
  --username testdoctor@example.com \
  --user-attributes Name=email,Value=testdoctor@example.com \
  --temporary-password "TempPass123!" \
  --message-action SUPPRESS

# Add to Doctor group
aws cognito-idp admin-add-user-to-group \
  --user-pool-id $USER_POOL_ID \
  --username testdoctor@example.com \
  --group-name Doctor

# Set permanent password
aws cognito-idp admin-set-user-password \
  --user-pool-id $USER_POOL_ID \
  --username testdoctor@example.com \
  --password "SecurePass123!" \
  --permanent

# Authenticate and get tokens
aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id $CLIENT_ID \
  --auth-parameters USERNAME=testdoctor@example.com,PASSWORD=SecurePass123!
```

**Save the tokens from the output:**
- `IdToken` - Use for API requests
- `AccessToken` - Use for AWS resource access
- `RefreshToken` - Use for token refresh

### Step 4: Test Token Refresh

```bash
# Test token refresh (replace <REFRESH_TOKEN> with actual token)
REFRESH_TOKEN="<REFRESH_TOKEN>"

# Invoke Lambda directly
aws lambda invoke \
  --function-name cancer-detection-token-refresh-dev \
  --payload "{\"httpMethod\":\"POST\",\"body\":\"{\\\"refreshToken\\\":\\\"$REFRESH_TOKEN\\\"}\"}" \
  response.json

# View response
cat response.json
```

## Quick Validation

### ✅ Checklist

- [ ] Lambda functions deployed
- [ ] Test user created
- [ ] Authentication successful
- [ ] Token refresh working
- [ ] CloudWatch logs visible

### Verify Deployment

```bash
# Check Lambda functions exist
aws lambda list-functions --query "Functions[?contains(FunctionName, 'jwt-authorizer')]"
aws lambda list-functions --query "Functions[?contains(FunctionName, 'token-refresh')]"

# Check CloudWatch logs
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/cancer-detection"
```

## Common Issues

### Issue: "authorizer.zip not found"
**Solution:** Run `./deploy.sh` first to create the zip files

### Issue: "User does not exist"
**Solution:** Create test user using the commands in Step 3

### Issue: "Invalid password"
**Solution:** Ensure password meets requirements (12+ chars, uppercase, lowercase, number, symbol)

### Issue: "NotAuthorizedException"
**Solution:** Check that user password is set to permanent

## Next Steps

1. ✅ **Task 3.2 Complete** - JWT token management implemented
2. ⏭️ **Task 3.3** - Set up role-based access control (RBAC)
3. ⏭️ **Task 3.4** - Implement session management
4. ⏭️ **Task 4.1** - Set up API Gateway with authorizer

## Integration Example

### Frontend (React/Next.js)

```javascript
// lib/auth.js
export async function refreshTokens(refreshToken) {
  const response = await fetch('/api/auth/refresh', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ refreshToken })
  });
  
  if (!response.ok) {
    throw new Error('Token refresh failed');
  }
  
  return response.json();
}

// lib/api.js
export async function fetchWithAuth(url, options = {}) {
  const idToken = localStorage.getItem('idToken');
  
  const response = await fetch(url, {
    ...options,
    headers: {
      ...options.headers,
      'Authorization': `Bearer ${idToken}`
    }
  });
  
  // Handle 401 - token expired
  if (response.status === 401) {
    const refreshToken = localStorage.getItem('refreshToken');
    const tokens = await refreshTokens(refreshToken);
    
    localStorage.setItem('idToken', tokens.idToken);
    localStorage.setItem('accessToken', tokens.accessToken);
    
    // Retry request
    return fetch(url, {
      ...options,
      headers: {
        ...options.headers,
        'Authorization': `Bearer ${tokens.idToken}`
      }
    });
  }
  
  return response;
}
```

### Backend (Lambda)

```javascript
// Access user context from authorizer
exports.handler = async (event) => {
  const userId = event.requestContext.authorizer.userId;
  const email = event.requestContext.authorizer.email;
  const groups = JSON.parse(event.requestContext.authorizer.groups);
  
  console.log('User:', userId, email, groups);
  
  // Your business logic here
  return {
    statusCode: 200,
    body: JSON.stringify({ message: 'Success' })
  };
};
```

## Documentation

- 📖 [Full Documentation](./JWT_TOKEN_MANAGEMENT.md)
- 📖 [Cognito Setup](../terraform/COGNITO.md)
- 📖 [API Gateway Integration](../terraform/API_GATEWAY.md) (coming soon)

## Support

For detailed information, see [JWT_TOKEN_MANAGEMENT.md](./JWT_TOKEN_MANAGEMENT.md)
