#!/bin/bash

# MedSutra AI Frontend - AWS S3 Deployment Script
# Usage: ./deploy-s3.sh <bucket-name> [cloudfront-distribution-id]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if bucket name is provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: Bucket name is required${NC}"
    echo "Usage: ./deploy-s3.sh <bucket-name> [cloudfront-distribution-id]"
    exit 1
fi

BUCKET_NAME=$1
CLOUDFRONT_ID=$2

echo -e "${GREEN}🚀 Starting deployment to S3...${NC}"
echo "Bucket: $BUCKET_NAME"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    echo "Install it from: https://aws.amazon.com/cli/"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Error: AWS credentials not configured${NC}"
    echo "Run: aws configure"
    exit 1
fi

echo -e "${YELLOW}📦 Syncing files to S3...${NC}"

# Sync files to S3
aws s3 sync . s3://$BUCKET_NAME/ \
    --exclude "*.md" \
    --exclude "*.sh" \
    --exclude "*.ps1" \
    --exclude "buildspec.yml" \
    --exclude ".git/*" \
    --delete

echo -e "${YELLOW}🔧 Setting content types...${NC}"

# Set correct content types
aws s3 cp s3://$BUCKET_NAME/index.html s3://$BUCKET_NAME/index.html \
    --content-type "text/html" \
    --metadata-directive REPLACE \
    --cache-control "max-age=300"

aws s3 cp s3://$BUCKET_NAME/styles.css s3://$BUCKET_NAME/styles.css \
    --content-type "text/css" \
    --metadata-directive REPLACE \
    --cache-control "max-age=86400"

aws s3 cp s3://$BUCKET_NAME/app.js s3://$BUCKET_NAME/app.js \
    --content-type "application/javascript" \
    --metadata-directive REPLACE \
    --cache-control "max-age=86400"

echo -e "${GREEN}✅ Files uploaded successfully!${NC}"

# Invalidate CloudFront cache if distribution ID provided
if [ ! -z "$CLOUDFRONT_ID" ]; then
    echo -e "${YELLOW}🔄 Invalidating CloudFront cache...${NC}"
    aws cloudfront create-invalidation \
        --distribution-id $CLOUDFRONT_ID \
        --paths "/*"
    echo -e "${GREEN}✅ CloudFront cache invalidated!${NC}"
fi

# Get S3 website URL
REGION=$(aws s3api get-bucket-location --bucket $BUCKET_NAME --query 'LocationConstraint' --output text)
if [ "$REGION" == "None" ]; then
    REGION="us-east-1"
fi

echo ""
echo -e "${GREEN}🎉 Deployment complete!${NC}"
echo ""
echo "S3 Website URL: http://$BUCKET_NAME.s3-website-$REGION.amazonaws.com"
if [ ! -z "$CLOUDFRONT_ID" ]; then
    echo "CloudFront URL: Check your CloudFront distribution"
fi
echo ""
echo -e "${YELLOW}⚠️  Remember to:${NC}"
echo "  1. Configure API endpoint in app.js"
echo "  2. Enable S3 static website hosting"
echo "  3. Set up CloudFront for HTTPS"
echo "  4. Configure CORS on API Gateway"
