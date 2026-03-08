# MedSutra AI Frontend - AWS S3 Deployment Script (PowerShell)
# Usage: .\deploy-s3.ps1 -BucketName <bucket-name> [-CloudFrontId <distribution-id>]

param(
    [Parameter(Mandatory=$true)]
    [string]$BucketName,
    
    [Parameter(Mandatory=$false)]
    [string]$CloudFrontId
)

Write-Host "🚀 Starting deployment to S3..." -ForegroundColor Green
Write-Host "Bucket: $BucketName"

# Check if AWS CLI is installed
try {
    aws --version | Out-Null
} catch {
    Write-Host "Error: AWS CLI is not installed" -ForegroundColor Red
    Write-Host "Install it from: https://aws.amazon.com/cli/"
    exit 1
}

# Check AWS credentials
try {
    aws sts get-caller-identity | Out-Null
} catch {
    Write-Host "Error: AWS credentials not configured" -ForegroundColor Red
    Write-Host "Run: aws configure"
    exit 1
}

Write-Host "📦 Syncing files to S3..." -ForegroundColor Yellow

# Sync files to S3
aws s3 sync . "s3://$BucketName/" `
    --exclude "*.md" `
    --exclude "*.sh" `
    --exclude "*.ps1" `
    --exclude "buildspec.yml" `
    --exclude ".git/*" `
    --delete

Write-Host "🔧 Setting content types..." -ForegroundColor Yellow

# Set correct content types
aws s3 cp "s3://$BucketName/index.html" "s3://$BucketName/index.html" `
    --content-type "text/html" `
    --metadata-directive REPLACE `
    --cache-control "max-age=300"

aws s3 cp "s3://$BucketName/styles.css" "s3://$BucketName/styles.css" `
    --content-type "text/css" `
    --metadata-directive REPLACE `
    --cache-control "max-age=86400"

aws s3 cp "s3://$BucketName/app.js" "s3://$BucketName/app.js" `
    --content-type "application/javascript" `
    --metadata-directive REPLACE `
    --cache-control "max-age=86400"

Write-Host "✅ Files uploaded successfully!" -ForegroundColor Green

# Invalidate CloudFront cache if distribution ID provided
if ($CloudFrontId) {
    Write-Host "🔄 Invalidating CloudFront cache..." -ForegroundColor Yellow
    aws cloudfront create-invalidation `
        --distribution-id $CloudFrontId `
        --paths "/*"
    Write-Host "✅ CloudFront cache invalidated!" -ForegroundColor Green
}

# Get S3 website URL
$Region = aws s3api get-bucket-location --bucket $BucketName --query 'LocationConstraint' --output text
if ($Region -eq "None") {
    $Region = "us-east-1"
}

Write-Host ""
Write-Host "🎉 Deployment complete!" -ForegroundColor Green
Write-Host ""
Write-Host "S3 Website URL: http://$BucketName.s3-website-$Region.amazonaws.com"
if ($CloudFrontId) {
    Write-Host "CloudFront URL: Check your CloudFront distribution"
}
Write-Host ""
Write-Host "⚠️  Remember to:" -ForegroundColor Yellow
Write-Host "  1. Configure API endpoint in app.js"
Write-Host "  2. Enable S3 static website hosting"
Write-Host "  3. Set up CloudFront for HTTPS"
Write-Host "  4. Configure CORS on API Gateway"
