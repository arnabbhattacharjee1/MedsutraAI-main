# Amazon Bedrock Quick Start Guide

## Task 7.3: Configure Amazon Bedrock Access

This guide provides step-by-step instructions to configure Amazon Bedrock for the AI-powered Cancer Detection platform.

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform installed (v1.0+)
- Access to AWS Console
- Existing VPC, KMS, and IAM infrastructure (Tasks 1.1-1.3 completed)

## Quick Setup (5 minutes)

### Step 1: Enable Model Access (AWS Console)

1. Navigate to [Amazon Bedrock Console](https://console.aws.amazon.com/bedrock/)
2. Select your region (e.g., `us-east-1`)
3. Click **Model access** in the left sidebar
4. Click **Manage model access**
5. Enable the following models:
   - ✅ **Anthropic Claude 3 Sonnet**
   - ✅ **Anthropic Claude 3 Haiku**
   - ✅ **Amazon Titan Embeddings G1 - Text v2**
6. Click **Request model access**
7. Wait for approval (usually instant)

### Step 2: Deploy Bedrock Configuration

```bash
cd infrastructure/terraform

# Deploy Bedrock resources
terraform apply -target=aws_iam_role.bedrock_eks_role \
                -target=aws_iam_role.bedrock_lambda_role \
                -target=aws_iam_policy.bedrock_invoke_policy \
                -target=aws_cloudwatch_log_group.bedrock_invocations \
                -target=aws_ssm_parameter.bedrock_config \
                -var-file=terraform.tfvars.mvp

# Confirm with 'yes'
```

### Step 3: Verify Configuration

```bash
# Get Bedrock configuration
aws ssm get-parameter \
  --name "/cancer-detection-platform/mvp/bedrock/config" \
  --region us-east-1 \
  --query 'Parameter.Value' \
  --output text | jq .

# Expected output:
# {
#   "models": {
#     "clinical_summarization": { ... },
#     "explainability": { ... },
#     "translation": { ... },
#     "embeddings": { ... }
#   },
#   "region": "us-east-1",
#   "logging": { ... },
#   "rate_limits": { ... }
# }
```

### Step 4: Test Model Invocation

```bash
# Test Claude 3 Sonnet
aws bedrock-runtime invoke-model \
  --model-id anthropic.claude-3-sonnet-20240229-v1:0 \
  --region us-east-1 \
  --body '{
    "anthropic_version": "bedrock-2023-05-31",
    "max_tokens": 100,
    "messages": [
      {
        "role": "user",
        "content": "Summarize: Patient presents with fever and cough for 3 days."
      }
    ]
  }' \
  bedrock-test-output.json

# View response
cat bedrock-test-output.json | jq .
```

## Configuration Details

### IAM Roles Created

1. **EKS Role**: `cancer-detection-platform-bedrock-eks-role-mvp`
   - For AI agent pods in EKS cluster
   - Uses IRSA (IAM Roles for Service Accounts)

2. **Lambda Role**: `cancer-detection-platform-bedrock-lambda-role-mvp`
   - For Lambda functions that need Bedrock access
   - Includes basic Lambda execution permissions

### Models Configured

| Model | Model ID | Purpose | Max Tokens | Temperature |
|-------|----------|---------|------------|-------------|
| Claude 3 Sonnet | `anthropic.claude-3-sonnet-20240229-v1:0` | Clinical Summarization | 4096 | 0.7 |
| Claude 3 Sonnet | `anthropic.claude-3-sonnet-20240229-v1:0` | Explainability | 2048 | 0.5 |
| Claude 3 Haiku | `anthropic.claude-3-haiku-20240307-v1:0` | Translation | 2048 | 0.3 |
| Titan Embeddings v2 | `amazon.titan-embed-text-v2:0` | Vector Embeddings | N/A | N/A |

### CloudWatch Log Groups

- **Invocations**: `/aws/bedrock/cancer-detection-platform-mvp`
- **Metrics**: `/aws/bedrock/cancer-detection-platform-mvp/metrics`

## Testing Bedrock Access

### Test Script (Python)

Create `test_bedrock.py`:

```python
#!/usr/bin/env python3
import boto3
import json

def test_bedrock_access():
    """Test Amazon Bedrock model access"""
    
    bedrock = boto3.client('bedrock-runtime', region_name='us-east-1')
    
    # Test 1: Claude 3 Sonnet
    print("Testing Claude 3 Sonnet...")
    try:
        response = bedrock.invoke_model(
            modelId='anthropic.claude-3-sonnet-20240229-v1:0',
            body=json.dumps({
                "anthropic_version": "bedrock-2023-05-31",
                "max_tokens": 100,
                "messages": [
                    {
                        "role": "user",
                        "content": "Say 'Bedrock access successful' if you can read this."
                    }
                ]
            })
        )
        result = json.loads(response['body'].read())
        print(f"✅ Claude 3 Sonnet: {result['content'][0]['text']}")
    except Exception as e:
        print(f"❌ Claude 3 Sonnet failed: {e}")
    
    # Test 2: Claude 3 Haiku
    print("\nTesting Claude 3 Haiku...")
    try:
        response = bedrock.invoke_model(
            modelId='anthropic.claude-3-haiku-20240307-v1:0',
            body=json.dumps({
                "anthropic_version": "bedrock-2023-05-31",
                "max_tokens": 50,
                "messages": [
                    {
                        "role": "user",
                        "content": "Translate 'Hello' to Hindi."
                    }
                ]
            })
        )
        result = json.loads(response['body'].read())
        print(f"✅ Claude 3 Haiku: {result['content'][0]['text']}")
    except Exception as e:
        print(f"❌ Claude 3 Haiku failed: {e}")
    
    # Test 3: Titan Embeddings
    print("\nTesting Titan Embeddings...")
    try:
        response = bedrock.invoke_model(
            modelId='amazon.titan-embed-text-v2:0',
            body=json.dumps({
                "inputText": "Patient presents with fever and cough."
            })
        )
        result = json.loads(response['body'].read())
        embedding_length = len(result['embedding'])
        print(f"✅ Titan Embeddings: Generated {embedding_length}-dimensional vector")
    except Exception as e:
        print(f"❌ Titan Embeddings failed: {e}")

if __name__ == "__main__":
    test_bedrock_access()
```

Run the test:

```bash
python test_bedrock.py
```

Expected output:
```
Testing Claude 3 Sonnet...
✅ Claude 3 Sonnet: Bedrock access successful

Testing Claude 3 Haiku...
✅ Claude 3 Haiku: नमस्ते (Namaste)

Testing Titan Embeddings...
✅ Titan Embeddings: Generated 1024-dimensional vector
```

## Common Issues and Solutions

### Issue 1: Model Access Denied

**Error**:
```
AccessDeniedException: You don't have access to the model with the specified model ID.
```

**Solution**:
1. Go to AWS Console → Bedrock → Model access
2. Verify models are enabled and status is "Access granted"
3. Wait 5 minutes for permissions to propagate

### Issue 2: Region Not Supported

**Error**:
```
ValidationException: Bedrock is not available in the specified region.
```

**Solution**:
- Use supported regions: `us-east-1`, `us-west-2`, `eu-west-1`, `ap-southeast-1`
- Update `terraform.tfvars.mvp` with supported region

### Issue 3: IAM Permission Denied

**Error**:
```
AccessDeniedException: User: arn:aws:iam::xxx:user/xxx is not authorized to perform: bedrock:InvokeModel
```

**Solution**:
```bash
# Attach Bedrock policy to your IAM user/role
aws iam attach-user-policy \
  --user-name YOUR_USERNAME \
  --policy-arn arn:aws:iam::aws:policy/AmazonBedrockFullAccess
```

### Issue 4: Throttling

**Error**:
```
ThrottlingException: Rate exceeded
```

**Solution**:
- Implement exponential backoff in your code
- Request quota increase via AWS Support
- Use caching to reduce API calls

## Verification Checklist

- [ ] Model access enabled in AWS Console
- [ ] Terraform resources deployed successfully
- [ ] IAM roles created (`bedrock-eks-role`, `bedrock-lambda-role`)
- [ ] SSM parameter contains configuration
- [ ] CloudWatch log groups created
- [ ] Test invocation successful for Claude 3 Sonnet
- [ ] Test invocation successful for Claude 3 Haiku
- [ ] Test invocation successful for Titan Embeddings

## Next Steps

After completing this task:

1. ✅ **Task 7.3 Complete**: Bedrock access configured
2. ⏭️ **Task 9.1**: Create Clinical Summarization Agent
3. ⏭️ **Task 9.2**: Implement multilingual translation
4. ⏭️ **Task 11.1**: Create Explainability Agent

## Cost Estimate

**Monthly cost for MVP** (assuming 1000 patient summaries):

| Service | Usage | Cost |
|---------|-------|------|
| Claude 3 Sonnet (Summarization) | 1000 requests × 2K input + 1K output tokens | ~$50 |
| Claude 3 Haiku (Translation) | 1000 requests × 1K input + 1K output tokens | ~$2.50 |
| Titan Embeddings | 1000 requests × 500 tokens | ~$0.01 |
| **Total** | | **~$52.51/month** |

## Support

For issues or questions:
- AWS Bedrock Documentation: https://docs.aws.amazon.com/bedrock/
- AWS Support: https://console.aws.amazon.com/support/
- Project Issues: [GitHub Issues](https://github.com/your-repo/issues)

## Task Completion

Mark task as complete in `tasks.md`:
```markdown
- [x] 7.3 Configure Amazon Bedrock access
```

Update MVP_PLAN.md:
```markdown
- [x] **7.3** Configure Amazon Bedrock access
```
