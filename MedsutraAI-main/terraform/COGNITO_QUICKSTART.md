# Cognito User Pool - Quick Start Guide

## 🚀 Quick Deployment (5 minutes)

### Prerequisites
- ✅ AWS CLI configured
- ✅ Terraform installed
- ✅ VPC infrastructure deployed (Tasks 1.1-1.4)

### Step 1: Configure Variables

Edit `terraform.tfvars` or create `terraform.tfvars.cognito`:

```hcl
# Required: Update with your domain
cognito_callback_urls = [
  "https://yourdomain.com/auth/callback",
  "http://localhost:3000/auth/callback"
]

cognito_logout_urls = [
  "https://yourdomain.com",
  "http://localhost:3000"
]

# Required: Update with your email
cognito_notification_email = "security@yourdomain.com"
```

### Step 2: Deploy

```bash
# Validate configuration
terraform validate

# Deploy Cognito User Pool
terraform apply -target=aws_cognito_user_pool.main \
                -target=aws_cognito_user_pool_client.web_client \
                -target=aws_cognito_user_group.oncologist \
                -target=aws_cognito_user_group.doctor \
                -target=aws_cognito_user_group.patient \
                -target=aws_cognito_user_group.admin

# Or deploy everything
terraform apply
```

### Step 3: Verify Email in SES

```bash
# Check your email for AWS SES verification link
# Click the link to verify your email address
```

### Step 4: Test Configuration

```bash
# Linux/Mac
chmod +x test_cognito.sh
./test_cognito.sh

# Windows
.\test_cognito.ps1
```

### Step 5: Get Outputs

```bash
# Get User Pool ID
terraform output cognito_user_pool_id

# Get Client ID
terraform output cognito_user_pool_client_id

# Get Domain URL
terraform output cognito_user_pool_domain_url
```

## 🧪 Create Test User

```bash
# Set variables
USER_POOL_ID=$(terraform output -raw cognito_user_pool_id)

# Create test doctor
aws cognito-idp admin-create-user \
  --user-pool-id $USER_POOL_ID \
  --username doctor@example.com \
  --user-attributes Name=email,Value=doctor@example.com Name=name,Value="Dr. Test" \
  --temporary-password "TempPass123!" \
  --message-action SUPPRESS

# Add to Doctor group
aws cognito-idp admin-add-user-to-group \
  --user-pool-id $USER_POOL_ID \
  --username doctor@example.com \
  --group-name Doctor

# Create test patient
aws cognito-idp admin-create-user \
  --user-pool-id $USER_POOL_ID \
  --username patient@example.com \
  --user-attributes Name=email,Value=patient@example.com Name=name,Value="Test Patient" \
  --temporary-password "TempPass123!" \
  --message-action SUPPRESS

# Add to Patient group
aws cognito-idp admin-add-user-to-group \
  --user-pool-id $USER_POOL_ID \
  --username patient@example.com \
  --group-name Patient
```

## 🔐 Key Features Configured

✅ **MFA Support**: Optional MFA with SMS and TOTP  
✅ **Password Policy**: 12+ chars, complexity required  
✅ **Account Lockout**: After 5 failed attempts  
✅ **User Groups**: Oncologist, Doctor, Patient, Admin  
✅ **Email/Phone Verification**: Both enabled  
✅ **Token Expiration**: 15 minutes (HIPAA-ready)  
✅ **Advanced Security**: Enabled  

## 📱 Frontend Integration

### Next.js with AWS Amplify

```bash
npm install aws-amplify @aws-amplify/ui-react
```

```javascript
// app/lib/amplify.ts
import { Amplify } from 'aws-amplify';

Amplify.configure({
  Auth: {
    region: 'ap-south-1',
    userPoolId: process.env.NEXT_PUBLIC_USER_POOL_ID,
    userPoolWebClientId: process.env.NEXT_PUBLIC_CLIENT_ID,
    oauth: {
      domain: process.env.NEXT_PUBLIC_COGNITO_DOMAIN,
      scope: ['email', 'openid', 'profile', 'phone'],
      redirectSignIn: process.env.NEXT_PUBLIC_REDIRECT_SIGN_IN,
      redirectSignOut: process.env.NEXT_PUBLIC_REDIRECT_SIGN_OUT,
      responseType: 'code'
    }
  }
});
```

```javascript
// app/components/AuthButton.tsx
import { withAuthenticator } from '@aws-amplify/ui-react';

function App({ signOut, user }) {
  return (
    <div>
      <h1>Hello {user.username}</h1>
      <button onClick={signOut}>Sign out</button>
    </div>
  );
}

export default withAuthenticator(App);
```

### Environment Variables

Create `.env.local`:

```bash
NEXT_PUBLIC_USER_POOL_ID=<from terraform output>
NEXT_PUBLIC_CLIENT_ID=<from terraform output>
NEXT_PUBLIC_COGNITO_DOMAIN=<from terraform output>
NEXT_PUBLIC_REDIRECT_SIGN_IN=http://localhost:3000/auth/callback
NEXT_PUBLIC_REDIRECT_SIGN_OUT=http://localhost:3000
```

## 🔧 Common Tasks

### Enable MFA for User

```bash
aws cognito-idp admin-set-user-mfa-preference \
  --user-pool-id $USER_POOL_ID \
  --username user@example.com \
  --software-token-mfa-settings Enabled=true,PreferredMfa=true
```

### Reset User Password

```bash
aws cognito-idp admin-set-user-password \
  --user-pool-id $USER_POOL_ID \
  --username user@example.com \
  --password "NewPass123!" \
  --permanent
```

### List Users in Group

```bash
aws cognito-idp list-users-in-group \
  --user-pool-id $USER_POOL_ID \
  --group-name Doctor
```

### Delete User

```bash
aws cognito-idp admin-delete-user \
  --user-pool-id $USER_POOL_ID \
  --username user@example.com
```

## 📊 Monitoring

### View Sign-in Logs

```bash
aws logs tail /aws/cognito/userpools/$USER_POOL_ID --follow
```

### Check User Status

```bash
aws cognito-idp admin-get-user \
  --user-pool-id $USER_POOL_ID \
  --username user@example.com
```

## 🐛 Troubleshooting

### Issue: Email not verified in SES

```bash
# Check SES verification status
aws ses get-identity-verification-attributes \
  --identities security@yourdomain.com

# Resend verification
aws ses verify-email-identity \
  --email-address security@yourdomain.com
```

### Issue: User locked out

```bash
# Unlock user
aws cognito-idp admin-reset-user-password \
  --user-pool-id $USER_POOL_ID \
  --username user@example.com
```

### Issue: Token expired

This is expected behavior (15-minute timeout). Use refresh token to get new access token.

## 📚 Next Steps

1. ✅ Cognito configured
2. ⏭️ Integrate with frontend (Task 15.1)
3. ⏭️ Implement JWT validation in Lambda (Task 3.2)
4. ⏭️ Set up RBAC policies (Task 3.3)
5. ⏭️ Implement session management (Task 3.4)

## 💰 Cost Estimate

For 10,000 monthly active users:
- MAU: Free (under 50,000)
- Advanced Security: $500/month
- SMS MFA (20% adoption): ~$52/month
- **Total**: ~$552/month

## 📖 Full Documentation

See [COGNITO.md](./COGNITO.md) for complete documentation.
