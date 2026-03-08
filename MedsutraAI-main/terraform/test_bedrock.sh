#!/bin/bash
# Test Amazon Bedrock configuration
# Task 7.3: Configure Amazon Bedrock access

set -e

echo "=========================================="
echo "Amazon Bedrock Configuration Test"
echo "Task 7.3: Configure Amazon Bedrock Access"
echo "=========================================="
echo ""

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is required but not installed"
    exit 1
fi

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS CLI is not configured or credentials are invalid"
    echo "Run: aws configure"
    exit 1
fi

echo "✅ AWS CLI configured"
echo ""

# Install required Python packages if needed
if ! python3 -c "import boto3" 2>/dev/null; then
    echo "Installing boto3..."
    pip install boto3
fi

# Run the Python test script
python3 test_bedrock.py

exit $?
