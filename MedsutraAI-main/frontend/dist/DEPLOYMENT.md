# MedSutra AI Frontend - Complete Deployment Guide

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [AWS S3 + CloudFront Deployment](#aws-s3--cloudfront-deployment)
3. [Configuration](#configuration)
4. [GitHub Setup](#github-setup)
5. [CI/CD Pipeline](#cicd-pipeline)
6. [Testing](#testing)
7. [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Tools

- AWS CLI v2.x or higher
- Git
- AWS Account with appropriate permissions
- (Optional) Node.js for local testing

### AWS Permissions Required

Your IAM user/role needs:
- `s3:PutObject`, `s3:GetObject`, `s3:DeleteObject`
- `s3:ListBucket`
- `cloudfront:CreateInvalidation` (if using CloudFront)
- `s3:PutBucketWebsite`, `s3:PutBucketPolicy`

## AWS S3 + CloudFront Deployment

### Step 1: Create S3 Bucket

```bash
# Create bucket
aws s3 mb s3://medsutra-ai-frontend --region us-east-1

# Enable static website hosting
aws s3 website s3://medsutra-ai-frontend \
  --index-document index.html \
  --error-document index.html
```

### Step 2: Configure Bucket Policy

Create `bucket-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::medsutra-ai-frontend/*"
    }
  ]
}
```

Apply policy:

```bash
aws s3api put-bucket-policy \
  --bucket medsutra-ai-frontend \
  --policy file://bucket-policy.json
```

### Step 3: Deploy Files

#### Using Deployment Script (Recommended)

**Linux/Mac:**
```bash
chmod +x deploy-s3.sh
./deploy-s3.sh medsutra-ai-frontend
```

**Windows:**
```powershell
.\deploy-s3.ps1 -BucketName medsutra-ai-frontend
```

#### Manual Deployment

```bash
aws s3 sync . s3://medsutra-ai-frontend/ \
  --exclude "*.md" \
  --exclude "*.sh" \
  --exclude "*.ps1" \
  --exclude "buildspec.yml" \
  --delete
```

### Step 4: Set Up CloudFront (Recommended for Production)

1. **Create CloudFront Distribution:**

```bash
aws cloudfront create-distribution \
  --origin-domain-name medsutra-ai-frontend.s3.amazonaws.com \
  --default-root-object index.html
```

2. **Configure Custom Error Responses:**
   - 403 → /index.html (for SPA routing)
   - 404 → /index.html (for SPA routing)

3. **Enable HTTPS:**
   - Request ACM certificate
   - Attach to CloudFront distribution

4. **Deploy with CloudFront Invalidation:**

```bash
./deploy-s3.sh medsutra-ai-frontend d1234567890abc
```

## Configuration

### 1. Update API Endpoint

Edit `app.js`:

```javascript
const CONFIG = {
    API_ENDPOINT: 'https://your-api-gateway-url.amazonaws.com/prod',
    // ... rest of config
};
```

### 2. Configure CORS on API Gateway

Add to your API Gateway:

```json
{
  "Access-Control-Allow-Origin": "https://your-cloudfront-domain.cloudfront.net",
  "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type,Authorization"
}
```

### 3. Update Demo Credentials (Optional)

Edit `app.js`:

```javascript
DEMO_CREDENTIALS: {
    userId: 'your-user-id',
    password: 'your-password',
    role: 'Oncologist'
}
```

## GitHub Setup

### 1. Initialize Repository

```bash
cd MedsutraAI-main/frontend/dist
git init
git add .
git commit -m "Initial commit: MedSutra AI Frontend"
```

### 2. Create GitHub Repository

```bash
# Create repo on GitHub, then:
git remote add origin https://github.com/yourusername/medsutra-ai-frontend.git
git branch -M main
git push -u origin main
```

### 3. Add GitHub Secrets (for CI/CD)

In GitHub repository settings → Secrets and variables → Actions:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION` (e.g., us-east-1)
- `S3_BUCKET` (e.g., medsutra-ai-frontend)
- `CLOUDFRONT_DISTRIBUTION_ID` (optional)

## CI/CD Pipeline

### Option 1: GitHub Actions

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to AWS S3

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Configure AWS Credentials
      uses: aws-actions/configure-aws-credentials@v2
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ secrets.AWS_REGION }}
    
    - name: Deploy to S3
      run: |
        aws s3 sync . s3://${{ secrets.S3_BUCKET }}/ \
          --exclude "*.md" --exclude "*.sh" --exclude "*.ps1" \
          --exclude ".git/*" --exclude ".github/*" --delete
    
    - name: Invalidate CloudFront
      if: ${{ secrets.CLOUDFRONT_DISTRIBUTION_ID }}
      run: |
        aws cloudfront create-invalidation \
          --distribution-id ${{ secrets.CLOUDFRONT_DISTRIBUTION_ID }} \
          --paths "/*"
```

### Option 2: AWS CodeBuild

1. Create CodeBuild project in AWS Console
2. Connect to GitHub repository
3. Use included `buildspec.yml`
4. Set environment variables:
   - `S3_BUCKET`
   - `CLOUDFRONT_DISTRIBUTION_ID` (optional)

### Option 3: AWS Amplify

```bash
# Install Amplify CLI
npm install -g @aws-amplify/cli

# Initialize Amplify
amplify init

# Add hosting
amplify add hosting

# Publish
amplify publish
```

## Testing

### Local Testing

```bash
# Using Python
python -m http.server 8000

# Using Node.js
npx serve .

# Using PHP
php -S localhost:8000
```

Open http://localhost:8000

### Test Checklist

- [ ] Login functionality works
- [ ] Patient dashboard displays correctly
- [ ] Patient reports open in modal
- [ ] AI analysis works in all languages
- [ ] Language switching functions properly
- [ ] Responsive design on mobile
- [ ] All links and buttons work
- [ ] No console errors

### Production Testing

1. **Test S3 Website URL:**
   ```
   http://medsutra-ai-frontend.s3-website-us-east-1.amazonaws.com
   ```

2. **Test CloudFront URL:**
   ```
   https://d1234567890abc.cloudfront.net
   ```

3. **Test Custom Domain (if configured):**
   ```
   https://app.medsutra.ai
   ```

## Troubleshooting

### Issue: 403 Forbidden

**Solution:**
- Check bucket policy allows public read
- Verify S3 website hosting is enabled
- Check CloudFront origin settings

### Issue: 404 Not Found

**Solution:**
- Verify index.html exists in bucket root
- Check CloudFront default root object
- Configure custom error responses

### Issue: CORS Errors

**Solution:**
- Add CORS headers to API Gateway
- Update allowed origins in API configuration
- Check preflight OPTIONS requests

### Issue: Stale Content

**Solution:**
```bash
# Invalidate CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id YOUR_DIST_ID \
  --paths "/*"
```

### Issue: Slow Loading

**Solution:**
- Enable CloudFront compression
- Set appropriate cache headers
- Optimize images and assets
- Use CloudFront edge locations

## Security Best Practices

1. **Always use HTTPS in production**
2. **Enable CloudFront signed URLs for sensitive content**
3. **Implement AWS WAF rules**
4. **Use AWS Cognito for authentication**
5. **Enable S3 access logging**
6. **Set up CloudWatch alarms**
7. **Regular security audits**

## Monitoring

### CloudWatch Metrics

- S3 bucket size
- Request count
- Error rates
- CloudFront cache hit ratio

### Logging

```bash
# Enable S3 access logging
aws s3api put-bucket-logging \
  --bucket medsutra-ai-frontend \
  --bucket-logging-status file://logging.json
```

## Cost Optimization

- Use CloudFront to reduce S3 requests
- Set appropriate cache TTLs
- Enable compression
- Use S3 Intelligent-Tiering for logs
- Monitor and set billing alarms

## Support

For issues or questions:
- Email: support@medsutra.ai
- GitHub Issues: https://github.com/yourusername/medsutra-ai-frontend/issues

## License

See main project LICENSE file.
