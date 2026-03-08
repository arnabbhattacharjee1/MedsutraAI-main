# JWT Token Management

## Overview

This document describes the JWT token management implementation for the AI Cancer Detection and Clinical Summarization Platform. The implementation includes:

1. **Lambda Authorizer** - Validates JWT tokens from Amazon Cognito
2. **Token Refresh Lambda** - Handles automatic token refresh
3. **Token Validation Middleware** - Ensures secure API access
4. **Automatic Token Refresh Logic** - Maintains user sessions

## Requirements

- **Requirement 13.2**: Automatic session timeout after 15 minutes of inactivity
- **Requirement 20.1**: Secure session with unique session identifier

## Architecture

```
┌─────────────┐
│   Client    │
│  (Browser)  │
└──────┬──────┘
       │
       │ 1. Request with JWT token
       │    Authorization: Bearer <token>
       │
       ▼
┌─────────────────────────────────────┐
│         API Gateway                 │
│  ┌───────────────────────────────┐ │
│  │   Lambda Authorizer           │ │
│  │   - Validates JWT signature   │ │
│  │   - Checks expiration         │ │
│  │   - Extracts user claims      │ │
│  └───────────────────────────────┘ │
└──────┬──────────────────────────────┘
       │
       │ 2. Authorized request with context
       │    (userId, email, groups)
       │
       ▼
┌─────────────────────────────────────┐
│      Backend Lambda Functions       │
│   (PatientService, ReportService)   │
└─────────────────────────────────────┘
```

## Token Configuration

### ID Token (15-minute expiration)
- **Purpose**: Authentication and authorization
- **Expiration**: 900 seconds (15 minutes)
- **Contains**: User identity, email, groups
- **Usage**: Sent with every API request

### Access Token (15-minute expiration)
- **Purpose**: Access AWS resources
- **Expiration**: 900 seconds (15 minutes)
- **Contains**: Scopes and permissions
- **Usage**: AWS service access

### Refresh Token (7-day expiration)
- **Purpose**: Obtain new ID and Access tokens
- **Expiration**: 604800 seconds (7 days)
- **Contains**: Refresh credentials
- **Usage**: Token refresh endpoint

## Lambda Authorizer

### Function Details
- **Runtime**: Node.js 20.x
- **Memory**: 256 MB
- **Timeout**: 30 seconds
- **Handler**: index.handler

### Validation Process

1. **Extract Token**: Parse Authorization header
2. **Fetch JWKS**: Get public keys from Cognito
3. **Verify Signature**: Validate token signature using RS256
4. **Check Issuer**: Verify token issuer matches Cognito User Pool
5. **Check Expiration**: Ensure token is not expired
6. **Extract Claims**: Get user information (sub, email, groups)
7. **Generate Policy**: Create IAM policy with user context

### Token Claims

```json
{
  "sub": "user-123",                    // Unique user ID (Requirement 20.1)
  "email": "doctor@example.com",
  "cognito:username": "doctor",
  "cognito:groups": ["Doctor"],
  "exp": 1234567890,                    // Expiration timestamp
  "iss": "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_ABC123"
}
```

### Authorization Context

The authorizer passes the following context to backend Lambda functions:

```json
{
  "userId": "user-123",
  "email": "doctor@example.com",
  "username": "doctor",
  "groups": "[\"Doctor\"]",
  "tokenExp": "1234567890"
}
```

### Error Handling

| Error | Status | Description |
|-------|--------|-------------|
| Missing Authorization header | 401 | No token provided |
| Invalid header format | 401 | Not "Bearer <token>" |
| Invalid signature | 401 | Token signature verification failed |
| Token expired | 401 | Token expiration time passed |
| Invalid issuer | 401 | Token not from configured Cognito |

## Token Refresh Lambda

### Function Details
- **Runtime**: Node.js 20.x
- **Memory**: 256 MB
- **Timeout**: 30 seconds
- **Handler**: index.handler

### Endpoint
```
POST /auth/refresh
Content-Type: application/json

{
  "refreshToken": "eyJjdHk..."
}
```

### Response (Success)
```json
{
  "idToken": "eyJraWQ...",
  "accessToken": "eyJraWQ...",
  "expiresIn": 900,
  "tokenType": "Bearer"
}
```

### Response (Error)
```json
{
  "error": "NotAuthorizedException",
  "message": "Invalid or expired refresh token"
}
```

### Error Codes

| Status | Error | Description |
|--------|-------|-------------|
| 400 | Bad Request | Missing refreshToken in body |
| 401 | NotAuthorizedException | Invalid or expired refresh token |
| 404 | UserNotFoundException | User not found |
| 429 | TooManyRequestsException | Rate limit exceeded |
| 500 | Internal Server Error | Unknown error |

## Automatic Token Refresh Logic

### Client-Side Implementation

```javascript
// Token refresh utility
class TokenManager {
  constructor() {
    this.idToken = null;
    this.accessToken = null;
    this.refreshToken = null;
    this.expiresAt = null;
    this.refreshTimer = null;
  }

  // Set tokens after login
  setTokens(idToken, accessToken, refreshToken, expiresIn) {
    this.idToken = idToken;
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
    this.expiresAt = Date.now() + (expiresIn * 1000);
    
    // Schedule automatic refresh 1 minute before expiration
    this.scheduleRefresh(expiresIn - 60);
  }

  // Schedule automatic token refresh
  scheduleRefresh(delaySeconds) {
    if (this.refreshTimer) {
      clearTimeout(this.refreshTimer);
    }
    
    this.refreshTimer = setTimeout(() => {
      this.refreshTokens();
    }, delaySeconds * 1000);
  }

  // Refresh tokens
  async refreshTokens() {
    try {
      const response = await fetch('/auth/refresh', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          refreshToken: this.refreshToken
        })
      });

      if (!response.ok) {
        throw new Error('Token refresh failed');
      }

      const data = await response.json();
      this.setTokens(
        data.idToken,
        data.accessToken,
        this.refreshToken, // Refresh token doesn't change
        data.expiresIn
      );

      console.log('Tokens refreshed successfully');
    } catch (error) {
      console.error('Token refresh error:', error);
      // Redirect to login
      window.location.href = '/login';
    }
  }

  // Get current ID token
  getIdToken() {
    // Check if token is expired
    if (Date.now() >= this.expiresAt) {
      throw new Error('Token expired');
    }
    return this.idToken;
  }

  // Clear tokens on logout
  clearTokens() {
    this.idToken = null;
    this.accessToken = null;
    this.refreshToken = null;
    this.expiresAt = null;
    if (this.refreshTimer) {
      clearTimeout(this.refreshTimer);
    }
  }
}

// Usage
const tokenManager = new TokenManager();

// After login
tokenManager.setTokens(idToken, accessToken, refreshToken, 900);

// Make API request
const response = await fetch('/api/patients', {
  headers: {
    'Authorization': `Bearer ${tokenManager.getIdToken()}`
  }
});
```

### API Request Interceptor

```javascript
// Axios interceptor for automatic token refresh
axios.interceptors.request.use(
  async (config) => {
    const token = tokenManager.getIdToken();
    config.headers.Authorization = `Bearer ${token}`;
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Response interceptor for handling 401 errors
axios.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config;

    // If 401 and not already retried
    if (error.response?.status === 401 && !originalRequest._retry) {
      originalRequest._retry = true;

      try {
        // Refresh tokens
        await tokenManager.refreshTokens();

        // Retry original request with new token
        originalRequest.headers.Authorization = `Bearer ${tokenManager.getIdToken()}`;
        return axios(originalRequest);
      } catch (refreshError) {
        // Redirect to login
        window.location.href = '/login';
        return Promise.reject(refreshError);
      }
    }

    return Promise.reject(error);
  }
);
```

## Deployment

### Prerequisites
- Node.js 20.x
- npm
- AWS CLI configured
- Terraform

### Step 1: Package Lambda Functions

```bash
# Linux/Mac
cd infrastructure/lambda
./deploy.sh

# Windows
cd infrastructure/lambda
.\deploy.ps1
```

This creates:
- `authorizer/authorizer.zip`
- `token-refresh/token-refresh.zip`

### Step 2: Deploy with Terraform

```bash
cd infrastructure/terraform

# Initialize Terraform (if not already done)
terraform init

# Plan deployment
terraform plan

# Apply changes
terraform apply
```

### Step 3: Configure API Gateway

The Lambda authorizer is automatically configured in Terraform. To use it with API Gateway:

```hcl
# In your API Gateway configuration
resource "aws_api_gateway_authorizer" "jwt" {
  name                   = "jwt-authorizer"
  rest_api_id           = aws_api_gateway_rest_api.main.id
  authorizer_uri        = aws_lambda_function.jwt_authorizer.invoke_arn
  authorizer_credentials = aws_iam_role.api_gateway_authorizer.arn
  type                  = "TOKEN"
  identity_source       = "method.request.header.Authorization"
}

# Apply to API methods
resource "aws_api_gateway_method" "get_patients" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.patients.id
  http_method   = "GET"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt.id
}
```

### Step 4: Test Token Validation

```bash
# Get tokens from Cognito
USER_POOL_ID=$(terraform output -raw cognito_user_pool_id)
CLIENT_ID=$(terraform output -raw cognito_user_pool_client_id)

# Authenticate user
aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id $CLIENT_ID \
  --auth-parameters USERNAME=doctor@example.com,PASSWORD=YourPassword123!

# Test API with token
curl -X GET https://your-api.execute-api.us-east-1.amazonaws.com/prod/patients \
  -H "Authorization: Bearer <ID_TOKEN>"
```

### Step 5: Test Token Refresh

```bash
# Get function URL
REFRESH_URL=$(terraform output -raw token_refresh_function_url)

# Refresh tokens
curl -X POST $REFRESH_URL \
  -H "Content-Type: application/json" \
  -d '{"refreshToken": "<REFRESH_TOKEN>"}'
```

## Testing

### Run Unit Tests

```bash
# JWT Authorizer tests
cd infrastructure/lambda/authorizer
npm install
npm test

# Token Refresh tests
cd infrastructure/lambda/token-refresh
npm install
npm test
```

### Test Coverage

- ✅ Valid token authorization
- ✅ Invalid token rejection
- ✅ Expired token rejection
- ✅ Missing Authorization header
- ✅ Invalid header format
- ✅ Token expiration validation (15 minutes)
- ✅ Unique session identifier extraction
- ✅ Multiple user groups handling
- ✅ Token refresh success
- ✅ Token refresh errors (401, 404, 429, 500)
- ✅ CORS preflight handling

## Security Considerations

### Token Storage
- **Never** store tokens in localStorage (vulnerable to XSS)
- **Use** httpOnly cookies for refresh tokens
- **Use** memory or sessionStorage for ID/Access tokens
- **Clear** tokens on logout

### Token Transmission
- **Always** use HTTPS
- **Never** include tokens in URLs
- **Use** Authorization header: `Bearer <token>`

### Token Validation
- **Verify** signature using JWKS
- **Check** issuer matches Cognito
- **Validate** expiration time
- **Enforce** 15-minute timeout (Requirement 13.2)

### Rate Limiting
- **Implement** rate limiting on token refresh endpoint
- **Monitor** for suspicious refresh patterns
- **Alert** on excessive refresh attempts

## Monitoring

### CloudWatch Metrics

```bash
# Authorizer invocations
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value=cancer-detection-jwt-authorizer-dev \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --period 3600 \
  --statistics Sum

# Authorizer errors
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Errors \
  --dimensions Name=FunctionName,Value=cancer-detection-jwt-authorizer-dev \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --period 3600 \
  --statistics Sum
```

### CloudWatch Logs

```bash
# View authorizer logs
aws logs tail /aws/lambda/cancer-detection-jwt-authorizer-dev --follow

# View token refresh logs
aws logs tail /aws/lambda/cancer-detection-token-refresh-dev --follow
```

### Alarms

Set up CloudWatch alarms for:
- High error rate (>5%)
- High latency (>1000ms)
- Excessive unauthorized attempts
- Token refresh failures

## Troubleshooting

### Issue: "Unauthorized" error

**Possible causes:**
1. Token expired (>15 minutes old)
2. Invalid token signature
3. Token from wrong Cognito User Pool
4. Missing Authorization header

**Solution:**
- Check token expiration time
- Verify COGNITO_USER_POOL_ID environment variable
- Ensure token is from correct User Pool
- Check Authorization header format

### Issue: Token refresh fails

**Possible causes:**
1. Refresh token expired (>7 days old)
2. User deleted or disabled
3. Refresh token revoked

**Solution:**
- Re-authenticate user
- Check user status in Cognito
- Verify refresh token validity

### Issue: "Token expired" immediately after refresh

**Possible causes:**
1. Clock skew between client and server
2. Token expiration not configured correctly

**Solution:**
- Sync system clock
- Verify Cognito token expiration settings
- Check token exp claim

## Cost Estimation

### Lambda Authorizer
- **Invocations**: 1 per API request
- **Duration**: ~100ms average
- **Memory**: 256 MB
- **Cost**: $0.20 per 1M requests + $0.0000166667 per GB-second

### Token Refresh Lambda
- **Invocations**: ~1 per user per 15 minutes
- **Duration**: ~200ms average
- **Memory**: 256 MB
- **Cost**: $0.20 per 1M requests + $0.0000166667 per GB-second

### Example (10,000 active users)
- API requests: 1M/month
- Token refreshes: 40K/month
- **Total cost**: ~$0.50/month

## Compliance

### DPDP Act (India)
- ✅ Secure session management
- ✅ Automatic timeout after 15 minutes
- ✅ Audit logging of authentication events

### HIPAA-Ready
- ✅ Unique session identifiers (Requirement 20.1)
- ✅ Automatic session timeout (Requirement 13.2)
- ✅ Secure token transmission (HTTPS)
- ✅ Token revocation support

### ABDM Alignment
- ✅ Standards-compliant authentication
- ✅ Secure API access control

## Next Steps

1. **Task 3.3**: Set up role-based access control (RBAC)
2. **Task 3.4**: Implement session management
3. **Task 4.1**: Set up API Gateway REST API
4. **Task 4.2**: Set up API Gateway WebSocket API

## References

- [Amazon Cognito JWT Tokens](https://docs.aws.amazon.com/cognito/latest/developerguide/amazon-cognito-user-pools-using-tokens-with-identity-providers.html)
- [Lambda Authorizers](https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-use-lambda-authorizer.html)
- [JWT Best Practices](https://tools.ietf.org/html/rfc8725)
- [OWASP Token Storage](https://cheatsheetseries.owasp.org/cheatsheets/JSON_Web_Token_for_Java_Cheat_Sheet.html)
