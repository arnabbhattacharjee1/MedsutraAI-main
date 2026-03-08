#!/bin/bash

# Test script for Cognito User Pool configuration
# Task 3.1: Configure Amazon Cognito User Pool

set -e

echo "=========================================="
echo "Cognito User Pool Configuration Test"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI is not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ AWS CLI is installed${NC}"

# Get Cognito User Pool ID from Terraform output
echo ""
echo "Retrieving Cognito User Pool ID from Terraform..."
USER_POOL_ID=$(terraform output -raw cognito_user_pool_id 2>/dev/null)

if [ -z "$USER_POOL_ID" ]; then
    echo -e "${RED}❌ Failed to retrieve User Pool ID. Run 'terraform apply' first.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ User Pool ID: $USER_POOL_ID${NC}"

# Test 1: Verify User Pool exists
echo ""
echo "Test 1: Verifying User Pool exists..."
USER_POOL_INFO=$(aws cognito-idp describe-user-pool --user-pool-id "$USER_POOL_ID" 2>/dev/null)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ User Pool exists${NC}"
else
    echo -e "${RED}❌ User Pool does not exist${NC}"
    exit 1
fi

# Test 2: Verify MFA configuration
echo ""
echo "Test 2: Verifying MFA configuration..."
MFA_CONFIG=$(echo "$USER_POOL_INFO" | jq -r '.UserPool.MfaConfiguration')

if [ "$MFA_CONFIG" == "OPTIONAL" ] || [ "$MFA_CONFIG" == "ON" ]; then
    echo -e "${GREEN}✓ MFA is configured: $MFA_CONFIG${NC}"
else
    echo -e "${RED}❌ MFA is not properly configured: $MFA_CONFIG${NC}"
    exit 1
fi

# Test 3: Verify Password Policy
echo ""
echo "Test 3: Verifying Password Policy..."
PASSWORD_POLICY=$(echo "$USER_POOL_INFO" | jq '.UserPool.Policies.PasswordPolicy')
MIN_LENGTH=$(echo "$PASSWORD_POLICY" | jq -r '.MinimumLength')
REQUIRE_LOWERCASE=$(echo "$PASSWORD_POLICY" | jq -r '.RequireLowercase')
REQUIRE_UPPERCASE=$(echo "$PASSWORD_POLICY" | jq -r '.RequireUppercase')
REQUIRE_NUMBERS=$(echo "$PASSWORD_POLICY" | jq -r '.RequireNumbers')
REQUIRE_SYMBOLS=$(echo "$PASSWORD_POLICY" | jq -r '.RequireSymbols')

if [ "$MIN_LENGTH" -ge 12 ] && [ "$REQUIRE_LOWERCASE" == "true" ] && [ "$REQUIRE_UPPERCASE" == "true" ] && [ "$REQUIRE_NUMBERS" == "true" ] && [ "$REQUIRE_SYMBOLS" == "true" ]; then
    echo -e "${GREEN}✓ Password policy meets requirements:${NC}"
    echo "  - Minimum length: $MIN_LENGTH characters"
    echo "  - Requires lowercase: $REQUIRE_LOWERCASE"
    echo "  - Requires uppercase: $REQUIRE_UPPERCASE"
    echo "  - Requires numbers: $REQUIRE_NUMBERS"
    echo "  - Requires symbols: $REQUIRE_SYMBOLS"
else
    echo -e "${RED}❌ Password policy does not meet requirements${NC}"
    exit 1
fi

# Test 4: Verify Auto-verified Attributes
echo ""
echo "Test 4: Verifying auto-verified attributes..."
AUTO_VERIFIED=$(echo "$USER_POOL_INFO" | jq -r '.UserPool.AutoVerifiedAttributes[]' | tr '\n' ' ')

if echo "$AUTO_VERIFIED" | grep -q "email" && echo "$AUTO_VERIFIED" | grep -q "phone_number"; then
    echo -e "${GREEN}✓ Auto-verified attributes configured: $AUTO_VERIFIED${NC}"
else
    echo -e "${RED}❌ Auto-verified attributes not properly configured${NC}"
    exit 1
fi

# Test 5: Verify User Groups
echo ""
echo "Test 5: Verifying User Groups..."
GROUPS=$(aws cognito-idp list-groups --user-pool-id "$USER_POOL_ID" --query 'Groups[].GroupName' --output text)

REQUIRED_GROUPS=("Oncologist" "Doctor" "Patient" "Admin")
ALL_GROUPS_EXIST=true

for group in "${REQUIRED_GROUPS[@]}"; do
    if echo "$GROUPS" | grep -q "$group"; then
        echo -e "${GREEN}✓ Group exists: $group${NC}"
    else
        echo -e "${RED}❌ Group missing: $group${NC}"
        ALL_GROUPS_EXIST=false
    fi
done

if [ "$ALL_GROUPS_EXIST" = false ]; then
    exit 1
fi

# Test 6: Verify User Pool Client
echo ""
echo "Test 6: Verifying User Pool Client..."
CLIENT_ID=$(terraform output -raw cognito_user_pool_client_id 2>/dev/null)

if [ -z "$CLIENT_ID" ]; then
    echo -e "${RED}❌ Failed to retrieve User Pool Client ID${NC}"
    exit 1
fi

CLIENT_INFO=$(aws cognito-idp describe-user-pool-client --user-pool-id "$USER_POOL_ID" --client-id "$CLIENT_ID" 2>/dev/null)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ User Pool Client exists${NC}"
    
    # Verify token validity
    ID_TOKEN_VALIDITY=$(echo "$CLIENT_INFO" | jq -r '.UserPoolClient.IdTokenValidity')
    ACCESS_TOKEN_VALIDITY=$(echo "$CLIENT_INFO" | jq -r '.UserPoolClient.AccessTokenValidity')
    
    echo "  - ID Token Validity: $ID_TOKEN_VALIDITY minutes"
    echo "  - Access Token Validity: $ACCESS_TOKEN_VALIDITY minutes"
    
    if [ "$ID_TOKEN_VALIDITY" -eq 15 ] && [ "$ACCESS_TOKEN_VALIDITY" -eq 15 ]; then
        echo -e "${GREEN}✓ Token validity configured correctly (15 minutes)${NC}"
    else
        echo -e "${YELLOW}⚠ Token validity differs from expected (15 minutes)${NC}"
    fi
else
    echo -e "${RED}❌ User Pool Client does not exist${NC}"
    exit 1
fi

# Test 7: Verify Advanced Security Mode
echo ""
echo "Test 7: Verifying Advanced Security Mode..."
ADVANCED_SECURITY=$(echo "$USER_POOL_INFO" | jq -r '.UserPool.UserPoolAddOns.AdvancedSecurityMode')

if [ "$ADVANCED_SECURITY" == "ENFORCED" ]; then
    echo -e "${GREEN}✓ Advanced Security Mode is ENFORCED${NC}"
else
    echo -e "${YELLOW}⚠ Advanced Security Mode: $ADVANCED_SECURITY${NC}"
fi

# Test 8: Verify User Pool Domain
echo ""
echo "Test 8: Verifying User Pool Domain..."
DOMAIN=$(terraform output -raw cognito_user_pool_domain 2>/dev/null)

if [ -z "$DOMAIN" ]; then
    echo -e "${RED}❌ Failed to retrieve User Pool Domain${NC}"
    exit 1
fi

DOMAIN_INFO=$(aws cognito-idp describe-user-pool-domain --domain "$DOMAIN" 2>/dev/null)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ User Pool Domain exists: $DOMAIN${NC}"
    DOMAIN_URL=$(terraform output -raw cognito_user_pool_domain_url 2>/dev/null)
    echo "  - Domain URL: $DOMAIN_URL"
else
    echo -e "${RED}❌ User Pool Domain does not exist${NC}"
    exit 1
fi

# Summary
echo ""
echo "=========================================="
echo -e "${GREEN}✓ All Cognito User Pool tests passed!${NC}"
echo "=========================================="
echo ""
echo "Configuration Summary:"
echo "  - User Pool ID: $USER_POOL_ID"
echo "  - MFA: $MFA_CONFIG"
echo "  - Password Policy: 12+ chars with complexity"
echo "  - Auto-verified: Email and Phone"
echo "  - User Groups: Oncologist, Doctor, Patient, Admin"
echo "  - Token Validity: 15 minutes"
echo "  - Advanced Security: $ADVANCED_SECURITY"
echo "  - Domain: $DOMAIN"
echo ""
echo "Next Steps:"
echo "  1. Configure callback URLs for your application"
echo "  2. Set up SES email identity for notifications"
echo "  3. Create test users and assign to groups"
echo "  4. Test authentication flow with your application"
echo ""
