#!/usr/bin/env python3
"""
Test script for Amazon Bedrock configuration

Task 7.3: Configure Amazon Bedrock access
This script validates that Bedrock is properly configured and accessible.
"""

import sys
import json
import boto3
from botocore.exceptions import ClientError
from typing import Tuple


class Colors:
    """ANSI color codes for terminal output"""
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    END = '\033[0m'


def print_success(message: str):
    """Print success message in green"""
    print(f"{Colors.GREEN}✅ {message}{Colors.END}")


def print_error(message: str):
    """Print error message in red"""
    print(f"{Colors.RED}❌ {message}{Colors.END}")


def print_info(message: str):
    """Print info message in blue"""
    print(f"{Colors.BLUE}ℹ️  {message}{Colors.END}")


def print_warning(message: str):
    """Print warning message in yellow"""
    print(f"{Colors.YELLOW}⚠️  {message}{Colors.END}")


def test_ssm_parameter(region: str = 'us-east-1') -> Tuple[bool, dict]:
    """Test SSM parameter retrieval"""
    print_info("Testing SSM Parameter Store configuration...")
    
    try:
        ssm = boto3.client('ssm', region_name=region)
        parameter_name = "/cancer-detection-platform/mvp/bedrock/config"
        
        response = ssm.get_parameter(Name=parameter_name)
        config = json.loads(response['Parameter']['Value'])
        
        print_success(f"SSM parameter '{parameter_name}' retrieved successfully")
        print_info(f"Configuration contains {len(config.get('models', {}))} model configs")
        
        return True, config
    except ClientError as e:
        print_error(f"Failed to retrieve SSM parameter: {e}")
        return False, {}


def test_iam_roles(region: str = 'us-east-1') -> bool:
    """Test IAM roles existence"""
    print_info("Testing IAM roles...")
    
    iam = boto3.client('iam', region_name=region)
    roles_to_check = [
        'cancer-detection-platform-bedrock-eks-role-mvp',
        'cancer-detection-platform-bedrock-lambda-role-mvp'
    ]
    
    all_exist = True
    for role_name in roles_to_check:
        try:
            iam.get_role(RoleName=role_name)
            print_success(f"IAM role '{role_name}' exists")
        except ClientError:
            print_error(f"IAM role '{role_name}' not found")
            all_exist = False
    
    return all_exist


def test_cloudwatch_logs(region: str = 'us-east-1') -> bool:
    """Test CloudWatch log groups"""
    print_info("Testing CloudWatch log groups...")
    
    logs = boto3.client('logs', region_name=region)
    log_groups_to_check = [
        '/aws/bedrock/cancer-detection-platform-mvp',
        '/aws/bedrock/cancer-detection-platform-mvp/metrics'
    ]
    
    all_exist = True
    for log_group in log_groups_to_check:
        try:
            logs.describe_log_groups(logGroupNamePrefix=log_group)
            print_success(f"Log group '{log_group}' exists")
        except ClientError:
            print_error(f"Log group '{log_group}' not found")
            all_exist = False
    
    return all_exist


def test_model_access(region: str = 'us-east-1') -> bool:
    """Test Bedrock model access"""
    print_info("Testing Bedrock model access...")
    
    bedrock = boto3.client('bedrock', region_name=region)
    
    try:
        response = bedrock.list_foundation_models(byProvider='Anthropic')
        anthropic_models = response.get('modelSummaries', [])
        
        if anthropic_models:
            print_success(f"Found {len(anthropic_models)} Anthropic models")
            return True
        else:
            print_warning("No Anthropic models found - model access may not be enabled")
            return False
    except ClientError as e:
        print_error(f"Failed to list models: {e}")
        return False


def test_claude_invocation(region: str = 'us-east-1') -> bool:
    """Test Claude 3 Sonnet invocation"""
    print_info("Testing Claude 3 Sonnet invocation...")
    
    bedrock_runtime = boto3.client('bedrock-runtime', region_name=region)
    
    try:
        body = json.dumps({
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 100,
            "messages": [
                {
                    "role": "user",
                    "content": "Say 'Bedrock access successful' if you can read this."
                }
            ]
        })
        
        response = bedrock_runtime.invoke_model(
            modelId='anthropic.claude-3-sonnet-20240229-v1:0',
            body=body
        )
        
        response_body = json.loads(response['body'].read())
        response_text = response_body['content'][0]['text']
        
        print_success(f"Claude 3 Sonnet response: {response_text}")
        return True
    except ClientError as e:
        error_code = e.response.get('Error', {}).get('Code', '')
        if error_code == 'AccessDeniedException':
            print_error("Access denied - enable model access in AWS Console")
            print_info("Go to: https://console.aws.amazon.com/bedrock/home#/modelaccess")
        else:
            print_error(f"Failed to invoke Claude: {e}")
        return False


def test_haiku_invocation(region: str = 'us-east-1') -> bool:
    """Test Claude 3 Haiku invocation"""
    print_info("Testing Claude 3 Haiku invocation...")
    
    bedrock_runtime = boto3.client('bedrock-runtime', region_name=region)
    
    try:
        body = json.dumps({
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 50,
            "messages": [
                {
                    "role": "user",
                    "content": "Translate 'Hello' to Hindi. Respond with only the translation."
                }
            ]
        })
        
        response = bedrock_runtime.invoke_model(
            modelId='anthropic.claude-3-haiku-20240307-v1:0',
            body=body
        )
        
        response_body = json.loads(response['body'].read())
        response_text = response_body['content'][0]['text']
        
        print_success(f"Claude 3 Haiku response: {response_text}")
        return True
    except ClientError as e:
        print_error(f"Failed to invoke Haiku: {e}")
        return False


def test_titan_embeddings(region: str = 'us-east-1') -> bool:
    """Test Titan Embeddings invocation"""
    print_info("Testing Titan Embeddings v2...")
    
    bedrock_runtime = boto3.client('bedrock-runtime', region_name=region)
    
    try:
        body = json.dumps({
            "inputText": "Patient presents with fever and cough for 3 days."
        })
        
        response = bedrock_runtime.invoke_model(
            modelId='amazon.titan-embed-text-v2:0',
            body=body
        )
        
        response_body = json.loads(response['body'].read())
        embedding = response_body['embedding']
        
        print_success(f"Titan Embeddings: Generated {len(embedding)}-dimensional vector")
        return True
    except ClientError as e:
        print_error(f"Failed to generate embeddings: {e}")
        return False


def main():
    """Run all Bedrock configuration tests"""
    print("\n" + "="*60)
    print("Amazon Bedrock Configuration Test Suite")
    print("Task 7.3: Configure Amazon Bedrock Access")
    print("="*60 + "\n")
    
    region = 'us-east-1'
    results = {}
    
    # Test 1: SSM Parameter
    print("\n[Test 1/7] SSM Parameter Store")
    print("-" * 60)
    results['ssm'], config = test_ssm_parameter(region)
    
    # Test 2: IAM Roles
    print("\n[Test 2/7] IAM Roles")
    print("-" * 60)
    results['iam'] = test_iam_roles(region)
    
    # Test 3: CloudWatch Logs
    print("\n[Test 3/7] CloudWatch Log Groups")
    print("-" * 60)
    results['logs'] = test_cloudwatch_logs(region)
    
    # Test 4: Model Access
    print("\n[Test 4/7] Bedrock Model Access")
    print("-" * 60)
    results['model_access'] = test_model_access(region)
    
    # Test 5: Claude Sonnet
    print("\n[Test 5/7] Claude 3 Sonnet Invocation")
    print("-" * 60)
    results['claude_sonnet'] = test_claude_invocation(region)
    
    # Test 6: Claude Haiku
    print("\n[Test 6/7] Claude 3 Haiku Invocation")
    print("-" * 60)
    results['claude_haiku'] = test_haiku_invocation(region)
    
    # Test 7: Titan Embeddings
    print("\n[Test 7/7] Titan Embeddings v2")
    print("-" * 60)
    results['titan'] = test_titan_embeddings(region)
    
    # Summary
    print("\n" + "="*60)
    print("Test Summary")
    print("="*60)
    
    passed = sum(1 for v in results.values() if v)
    total = len(results)
    
    for test_name, result in results.items():
        status = "PASS" if result else "FAIL"
        color = Colors.GREEN if result else Colors.RED
        print(f"{color}{status}{Colors.END} - {test_name}")
    
    print(f"\nTotal: {passed}/{total} tests passed")
    
    if passed == total:
        print_success("\n🎉 All tests passed! Bedrock is properly configured.")
        return 0
    else:
        print_error(f"\n⚠️  {total - passed} test(s) failed. Review errors above.")
        return 1


if __name__ == "__main__":
    sys.exit(main())
