#!/bin/bash
# Test script to verify VPC infrastructure deployment

set -e

echo "=========================================="
echo "VPC Infrastructure Validation Tests"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to print test result
print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $2"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: $2"
        ((TESTS_FAILED++))
    fi
}

# Get VPC ID from Terraform output
VPC_ID=$(terraform output -raw vpc_id 2>/dev/null)

if [ -z "$VPC_ID" ]; then
    echo -e "${RED}ERROR: Could not get VPC ID from Terraform output${NC}"
    echo "Please ensure Terraform has been applied successfully"
    exit 1
fi

echo "Testing VPC: $VPC_ID"
echo ""

# Test 1: VPC exists and is available
echo "Test 1: VPC Existence and State"
VPC_STATE=$(aws ec2 describe-vpcs --vpc-ids $VPC_ID --query 'Vpcs[0].State' --output text 2>/dev/null)
if [ "$VPC_STATE" == "available" ]; then
    print_result 0 "VPC exists and is available"
else
    print_result 1 "VPC state is not available (current: $VPC_STATE)"
fi
echo ""

# Test 2: VPC CIDR block
echo "Test 2: VPC CIDR Block"
VPC_CIDR=$(aws ec2 describe-vpcs --vpc-ids $VPC_ID --query 'Vpcs[0].CidrBlock' --output text)
EXPECTED_CIDR=$(terraform output -raw vpc_cidr)
if [ "$VPC_CIDR" == "$EXPECTED_CIDR" ]; then
    print_result 0 "VPC CIDR block is correct ($VPC_CIDR)"
else
    print_result 1 "VPC CIDR block mismatch (expected: $EXPECTED_CIDR, got: $VPC_CIDR)"
fi
echo ""

# Test 3: DNS support enabled
echo "Test 3: DNS Configuration"
DNS_SUPPORT=$(aws ec2 describe-vpc-attribute --vpc-id $VPC_ID --attribute enableDnsSupport --query 'EnableDnsSupport.Value' --output text)
DNS_HOSTNAMES=$(aws ec2 describe-vpc-attribute --vpc-id $VPC_ID --attribute enableDnsHostnames --query 'EnableDnsHostnames.Value' --output text)

if [ "$DNS_SUPPORT" == "True" ]; then
    print_result 0 "DNS support is enabled"
else
    print_result 1 "DNS support is not enabled"
fi

if [ "$DNS_HOSTNAMES" == "True" ]; then
    print_result 0 "DNS hostnames are enabled"
else
    print_result 1 "DNS hostnames are not enabled"
fi
echo ""

# Test 4: Public subnets
echo "Test 4: Public Subnets"
PUBLIC_SUBNET_COUNT=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=*public*" --query 'length(Subnets)' --output text)
if [ "$PUBLIC_SUBNET_COUNT" -eq 3 ]; then
    print_result 0 "Correct number of public subnets (3)"
else
    print_result 1 "Incorrect number of public subnets (expected: 3, got: $PUBLIC_SUBNET_COUNT)"
fi

# Check if public subnets have map_public_ip_on_launch enabled
PUBLIC_SUBNETS=$(terraform output -json public_subnet_ids | jq -r '.[]')
for subnet in $PUBLIC_SUBNETS; do
    MAP_PUBLIC_IP=$(aws ec2 describe-subnets --subnet-ids $subnet --query 'Subnets[0].MapPublicIpOnLaunch' --output text)
    if [ "$MAP_PUBLIC_IP" == "True" ]; then
        print_result 0 "Public subnet $subnet has auto-assign public IP enabled"
    else
        print_result 1 "Public subnet $subnet does not have auto-assign public IP enabled"
    fi
done
echo ""

# Test 5: Private subnets
echo "Test 5: Private Subnets"
PRIVATE_SUBNET_COUNT=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=*private*" --query 'length(Subnets)' --output text)
if [ "$PRIVATE_SUBNET_COUNT" -eq 3 ]; then
    print_result 0 "Correct number of private subnets (3)"
else
    print_result 1 "Incorrect number of private subnets (expected: 3, got: $PRIVATE_SUBNET_COUNT)"
fi
echo ""

# Test 6: Internet Gateway
echo "Test 6: Internet Gateway"
IGW_COUNT=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query 'length(InternetGateways)' --output text)
if [ "$IGW_COUNT" -eq 1 ]; then
    print_result 0 "Internet Gateway exists and is attached"
else
    print_result 1 "Internet Gateway not found or multiple IGWs exist (count: $IGW_COUNT)"
fi
echo ""

# Test 7: NAT Gateways
echo "Test 7: NAT Gateways"
NAT_GW_COUNT=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available" --query 'length(NatGateways)' --output text)
EXPECTED_NAT_COUNT=$(terraform output -json nat_gateway_ids | jq 'length')

if [ "$NAT_GW_COUNT" -eq "$EXPECTED_NAT_COUNT" ]; then
    print_result 0 "Correct number of NAT Gateways ($NAT_GW_COUNT)"
else
    print_result 1 "Incorrect number of NAT Gateways (expected: $EXPECTED_NAT_COUNT, got: $NAT_GW_COUNT)"
fi

# Check NAT Gateway state
NAT_GATEWAYS=$(terraform output -json nat_gateway_ids | jq -r '.[]')
for nat_gw in $NAT_GATEWAYS; do
    NAT_STATE=$(aws ec2 describe-nat-gateways --nat-gateway-ids $nat_gw --query 'NatGateways[0].State' --output text)
    if [ "$NAT_STATE" == "available" ]; then
        print_result 0 "NAT Gateway $nat_gw is available"
    else
        print_result 1 "NAT Gateway $nat_gw is not available (state: $NAT_STATE)"
    fi
done
echo ""

# Test 8: Route Tables
echo "Test 8: Route Tables"
PUBLIC_RT_COUNT=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=*public*" --query 'length(RouteTables)' --output text)
PRIVATE_RT_COUNT=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=*private*" --query 'length(RouteTables)' --output text)

if [ "$PUBLIC_RT_COUNT" -eq 1 ]; then
    print_result 0 "Public route table exists"
else
    print_result 1 "Incorrect number of public route tables (expected: 1, got: $PUBLIC_RT_COUNT)"
fi

if [ "$PRIVATE_RT_COUNT" -eq 3 ]; then
    print_result 0 "Correct number of private route tables (3)"
else
    print_result 1 "Incorrect number of private route tables (expected: 3, got: $PRIVATE_RT_COUNT)"
fi
echo ""

# Test 9: VPC Endpoints
echo "Test 9: VPC Endpoints"

# S3 Gateway Endpoint
S3_ENDPOINT=$(aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$VPC_ID" "Name=service-name,Values=com.amazonaws.*.s3" --query 'VpcEndpoints[0].State' --output text)
if [ "$S3_ENDPOINT" == "available" ]; then
    print_result 0 "S3 VPC endpoint is available"
else
    print_result 1 "S3 VPC endpoint is not available (state: $S3_ENDPOINT)"
fi

# DynamoDB Gateway Endpoint
DYNAMODB_ENDPOINT=$(aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$VPC_ID" "Name=service-name,Values=com.amazonaws.*.dynamodb" --query 'VpcEndpoints[0].State' --output text)
if [ "$DYNAMODB_ENDPOINT" == "available" ]; then
    print_result 0 "DynamoDB VPC endpoint is available"
else
    print_result 1 "DynamoDB VPC endpoint is not available (state: $DYNAMODB_ENDPOINT)"
fi

# KMS Interface Endpoint
KMS_ENDPOINT=$(aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$VPC_ID" "Name=service-name,Values=com.amazonaws.*.kms" --query 'VpcEndpoints[0].State' --output text)
if [ "$KMS_ENDPOINT" == "available" ]; then
    print_result 0 "KMS VPC endpoint is available"
else
    print_result 1 "KMS VPC endpoint is not available (state: $KMS_ENDPOINT)"
fi
echo ""

# Test 10: Availability Zones
echo "Test 10: Multi-AZ Distribution"
SUBNET_AZS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[].AvailabilityZone' --output text | tr '\t' '\n' | sort -u | wc -l)
if [ "$SUBNET_AZS" -eq 3 ]; then
    print_result 0 "Subnets are distributed across 3 availability zones"
else
    print_result 1 "Subnets are not distributed across 3 AZs (found: $SUBNET_AZS AZs)"
fi
echo ""

# Test 11: Tags
echo "Test 11: Resource Tagging"
VPC_PROJECT_TAG=$(aws ec2 describe-vpcs --vpc-ids $VPC_ID --query 'Vpcs[0].Tags[?Key==`Project`].Value' --output text)
if [ "$VPC_PROJECT_TAG" == "AI-Cancer-Detection" ]; then
    print_result 0 "VPC has correct Project tag"
else
    print_result 1 "VPC Project tag is incorrect (expected: AI-Cancer-Detection, got: $VPC_PROJECT_TAG)"
fi
echo ""

# Summary
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "${GREEN}Tests Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Tests Failed: $TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed! VPC infrastructure is correctly configured.${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠ Some tests failed. Please review the output above.${NC}"
    exit 1
fi
