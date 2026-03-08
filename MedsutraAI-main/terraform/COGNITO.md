# Amazon Cognito User Pool Configuration

## Overview

This document describes the Amazon Cognito User Pool configuration for the AI Cancer Detection and Clinical Summarization Platform. The configuration implements secure authentication with MFA support, role-based access control, and compliance with DPDP Act and HIPAA-ready architecture requirements.

**Task**: 3.1 Configure Amazon Cognito User Pool  
**Requirements**: 1.1, 13.1, 13.4  
**Status**: ✅ Completed

## Architecture

### Components

1. **Cognito User Pool**: Central authentication service
2. **User Pool Client**: Web application client configuration
3. **User Groups**: Role-based access control (Oncologist, Doctor, Patient, Admin)
4. **IAM Roles**: Permissions for each user group
5. **User Pool Domain**: Hosted UI domain
6. **Risk Configuration**: Account lockout and security policies

### Security Features

- **MFA Support**: Optional MFA with SMS and TOTP
- **Password Policy**: 12+ characters with complexity requirements
- **Account Lockout**: Automatic lockout after 5 failed attempts via risk configuration
- **Advanced Security**: AWS Advanced Security features enabled
- **Token Expiration**: 15-minute access tokens (Requirement 13.2)
- **Email/Phone Verification**: Both email and phone number verification enabled

## Configuration Details

### Password Policy

```
Minimum Length: 12 characters
Require Lowercase: Yes
Require Uppercase: Yes
Require Numbers: Yes
Require Symbols: Yes
Temporary Password Validity: 7 days
```

### MFA Configuration

- **Mode**: OPTIONAL (users can enable, admins can enforce per user)
- **Methods**: SMS and TOTP (software tokens)
- **SMS Provider**: Amazon SNS

### Token Validity

```
ID Token: 15 minutes
Access Token: 15 minutes
Refresh Token: 7 days
```

This configuration ensures compliance with Requirement 13.2 (15-minute session timeout).

### User Groups and Roles

#### 1. Oncologist
- **Precedence**: 1
- **Access**: Full access to all patient records
- **Use Case**: Healthcare provider specializing in oncology

#### 2. Doctor
- **Precedence**: 2
- **Access**: Full access to all patient records
- **Use Case**: General healthcare provider

#### 3. Patient
- **Precedence**: 3
- **Access**: Limited to own records only
- **Use Case**: Patients accessing their own medical information

#### 4. Admin
- **Precedence**: 0 (highest)
- **Access**: System administration
- **Use Case**: Platform administrators

### Account Lockout Configuration

The risk configuration implements account lockout after 5 failed attempts:

- **High Risk**: Block sign-in, send notification
- **Medium Risk**: Require MFA, send notification
- **Low Risk**: Allow sign-in, no notification
- **Compromised Credentials**: Block sign-in automatically

### Auto-Verified Attributes

- Email address
- Phone number

Users must verify both email and phone number during registration.

## Deployment

### Prerequisites

1. AWS CLI configured with appropriate credentials
2. Terraform >= 1.5.0
3. Existing VPC and networking infrastructure (Tasks 1.1-1.4)

### Variables

Configure the following variables in `terraform.tfvars`:

```hcl
# Cognito Configuration
cognito_callback_urls = [
  "https://yourdomain.com/auth/callback",
  "http://localhost:3000/auth/callback"
]

cognito_logout_urls = [
  "https://yourdomain.com",
  "http://localhost:3000"
]

cognito_notification_email = "security@yourdomain.com"

cognito_blocked_ip_ranges = [
  # Add IP ranges to block if needed
]
```

### Deployment Steps

1. **Initialize Terraform** (if not already done):
   ```bash
   terraform init
   ```

2. **Validate Configuration**:
   ```bash
   terraform validate
   ```

3. **Plan Deployment**:
   ```bash
   terraform plan
   ```

4. **Apply Configuration**:
   ```bash
   terraform apply
   ```

5. **Verify SES Email Identity**:
   After deployment, verify the email address in AWS SES:
   ```bash
   # Check your email for verification link from AWS SES
   # Click the link to verify the email address
   ```

6. **Run Validation Tests**:
   ```bash
   # Linux/Mac
   chmod +x test_cognito.sh
   ./test_cognito.sh

   # Windows
   .\test_cognito.ps1
   ```

## Testing

### Validation Script

The `test_cognito.sh` (Linux/Mac) and `test_cognito.ps1` (Windows) scripts validate:

1. ✅ User Pool exists
2. ✅ MFA configuration
3. ✅ Password policy (12+ chars, complexity)
4. ✅ Auto-verified attributes (email, phone)
5. ✅ User groups (Oncologist, Doctor, Patient, Admin)
6. ✅ User Pool Client configuration
7. ✅ Advanced Security Mode
8. ✅ User Pool Domain

### Manual Testing

#### Create Test User

```bash
# Create a test user
aws cognito-idp admin-create-user \
  --user-pool-id <USER_POOL_ID> \
  --username testuser@example.com \
  --user-attributes Name=email,Value=testuser@example.com Name=name,Value="Test User" \
  --temporary-password "TempPass123!" \
  --message-action SUPPRESS

# Add user to a group
aws cognito-idp admin-add-user-to-group \
  --user-pool-id <USER_POOL_ID> \
  --username testuser@example.com \
  --group-name Doctor
```

#### Test Authentication

```bash
# Initiate authentication
aws cognito-idp admin-initiate-auth \
  --user-pool-id <USER_POOL_ID> \
  --client-id <CLIENT_ID> \
  --auth-flow ADMIN_NO_SRP_AUTH \
  --auth-parameters USERNAME=testuser@example.com,PASSWORD="TempPass123!"
```

#### Test Password Policy

Try creating a user with a weak password to verify policy enforcement:

```bash
# This should fail due to password policy
aws cognito-idp admin-create-user \
  --user-pool-id <USER_POOL_ID> \
  --username weakpass@example.com \
  --temporary-password "weak" \
  --message-action SUPPRESS
```

## Outputs

After deployment, the following outputs are available:

```bash
# Get User Pool ID
terraform output cognito_user_pool_id

# Get User Pool Client ID (sensitive)
terraform output cognito_user_pool_client_id

# Get User Pool Domain URL
terraform output cognito_user_pool_domain_url

# Get all User Groups
terraform output cognito_user_groups

# Get IAM Roles for groups
terraform output cognito_iam_roles
```

## Integration with Application

### Frontend Integration

Use AWS Amplify or AWS SDK for JavaScript to integrate with your Next.js application:

```javascript
import { Amplify } from 'aws-amplify';

Amplify.configure({
  Auth: {
    region: 'ap-south-1',
    userPoolId: '<USER_POOL_ID>',
    userPoolWebClientId: '<CLIENT_ID>',
    oauth: {
      domain: '<DOMAIN>.auth.ap-south-1.amazoncognito.com',
      scope: ['email', 'openid', 'profile', 'phone'],
      redirectSignIn: 'https://yourdomain.com/auth/callback',
      redirectSignOut: 'https://yourdomain.com',
      responseType: 'code'
    }
  }
});
```

### Backend Integration

Use AWS SDK to verify JWT tokens in Lambda functions:

```python
import boto3
from jose import jwt, JWTError

def verify_token(token, user_pool_id, region):
    # Get JWKS from Cognito
    keys_url = f'https://cognito-idp.{region}.amazonaws.com/{user_pool_id}/.well-known/jwks.json'
    
    # Verify and decode token
    try:
        claims = jwt.decode(token, keys_url, algorithms=['RS256'])
        return claims
    except JWTError:
        return None
```

## Security Considerations

### 1. Account Lockout

The risk configuration automatically locks accounts after 5 failed sign-in attempts. High-risk activities trigger:
- Immediate account block
- Email notification to user
- Security event logged

### 2. MFA Enforcement

While MFA is optional by default, administrators can enforce MFA for specific users or groups:

```bash
aws cognito-idp admin-set-user-mfa-preference \
  --user-pool-id <USER_POOL_ID> \
  --username user@example.com \
  --software-token-mfa-settings Enabled=true,PreferredMfa=true
```

### 3. Token Security

- Tokens expire after 15 minutes (Requirement 13.2)
- Refresh tokens valid for 7 days
- Token revocation enabled
- Prevent user existence errors enabled

### 4. Advanced Security Features

AWS Advanced Security Mode provides:
- Adaptive authentication
- Compromised credentials detection
- Risk-based authentication
- Account takeover protection

## Compliance

### DPDP Act (India)

- ✅ Explicit consent required for data processing (Requirement 12.2)
- ✅ User data deletion capability (Requirement 12.3)
- ✅ Encryption at rest and in transit (Requirements 12.4, 12.5)
- ✅ Audit logging of all access (Requirement 12.6)

### HIPAA-Ready Architecture

- ✅ Role-based access control (Requirement 13.1)
- ✅ Access logging with timestamps (Requirement 13.2)
- ✅ 15-minute session timeout (Requirement 13.3)
- ✅ Multi-factor authentication support (Requirement 13.4)

### ABDM Alignment

- ✅ Support for ABHA number as Patient ID (Requirement 14.4)
- ✅ ABDM-compliant patient identification (Requirement 14.1)

## Monitoring and Logging

### CloudWatch Logs

Cognito automatically logs to CloudWatch:
- Sign-in attempts
- MFA challenges
- Password changes
- Account lockouts
- Risk events

### Metrics to Monitor

1. **Sign-in Success Rate**: Track authentication success/failure
2. **MFA Usage**: Monitor MFA adoption
3. **Account Lockouts**: Alert on unusual lockout patterns
4. **Token Refresh Rate**: Monitor session activity

### CloudWatch Alarms

Set up alarms for:
- High number of failed sign-ins
- Unusual account lockout patterns
- Compromised credential detections
- High-risk sign-in attempts

## Troubleshooting

### Issue: User Pool Domain Already Exists

**Error**: `Domain already exists`

**Solution**: The domain name must be globally unique. The configuration uses a random suffix to ensure uniqueness. If you encounter this error, run `terraform destroy` and `terraform apply` again to generate a new random suffix.

### Issue: SES Email Not Verified

**Error**: `Email address not verified`

**Solution**: 
1. Check your email for verification link from AWS SES
2. Click the verification link
3. Verify the email is verified in SES console
4. Re-run `terraform apply`

### Issue: SMS MFA Not Working

**Error**: `Unable to send SMS`

**Solution**:
1. Verify SNS has permission to send SMS in your region
2. Check SNS spending limits
3. Verify the IAM role for Cognito SMS has correct permissions
4. Check CloudWatch Logs for detailed error messages

### Issue: Token Expiration Too Short

**Concern**: 15-minute tokens expire too quickly

**Solution**: This is by design for security (Requirement 13.2). Use refresh tokens to obtain new access tokens without re-authentication. Refresh tokens are valid for 7 days.

## Cost Estimation

### Cognito Pricing (ap-south-1 region)

- **Monthly Active Users (MAU)**: First 50,000 free, then $0.0055 per MAU
- **Advanced Security**: $0.05 per MAU
- **SMS MFA**: $0.00645 per SMS (SNS pricing)

### Example Cost Calculation

For 10,000 active users with 20% using SMS MFA:
- MAU: Free (under 50,000)
- Advanced Security: 10,000 × $0.05 = $500/month
- SMS MFA: 2,000 users × 4 SMS/month × $0.00645 = $51.60/month
- **Total**: ~$551.60/month

## Next Steps

1. ✅ **Task 3.1 Complete**: Cognito User Pool configured
2. ⏭️ **Task 3.2**: Implement JWT token management
3. ⏭️ **Task 3.3**: Set up role-based access control (RBAC)
4. ⏭️ **Task 3.4**: Implement session management

## References

- [AWS Cognito Documentation](https://docs.aws.amazon.com/cognito/)
- [Cognito User Pool Best Practices](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pool-settings.html)
- [HIPAA Compliance on AWS](https://aws.amazon.com/compliance/hipaa-compliance/)
- [DPDP Act Compliance](https://www.meity.gov.in/writereaddata/files/Digital%20Personal%20Data%20Protection%20Act%202023.pdf)

## Support

For issues or questions:
1. Check CloudWatch Logs for detailed error messages
2. Review AWS Cognito documentation
3. Contact AWS Support for service-specific issues
4. Review this documentation for common troubleshooting steps
