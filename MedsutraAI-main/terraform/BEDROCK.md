# Amazon Bedrock Configuration

## Overview

This document describes the Amazon Bedrock configuration for the AI-powered Cancer Detection and Clinical Summarization platform. Bedrock provides foundation models for clinical summarization, multilingual translation, explainability, and embeddings generation.

## Task Reference

- **Task ID**: 7.3
- **Task**: Configure Amazon Bedrock access
- **Requirements**: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 6.8

## Architecture

### Foundation Models Used

1. **Claude 3 Sonnet** (`anthropic.claude-3-sonnet-20240229-v1:0`)
   - **Purpose**: Clinical summarization and explainability
   - **Max Tokens**: 4096 (summarization), 2048 (explainability)
   - **Temperature**: 0.7 (summarization), 0.5 (explainability)
   - **Use Cases**:
     - Extracting chief complaints, medical history, medications
     - Identifying abnormal findings and pending actions
     - Generating step-by-step reasoning for AI outputs
     - Providing evidence citations and confidence levels

2. **Claude 3 Haiku** (`anthropic.claude-3-haiku-20240307-v1:0`)
   - **Purpose**: Multilingual translation
   - **Max Tokens**: 2048
   - **Temperature**: 0.3 (for accuracy)
   - **Supported Languages**: English, Hindi, Tamil, Bengali, Marathi, Telugu
   - **Use Cases**:
     - Contextual translation preserving medical accuracy
     - Medical jargon simplification for patient persona
     - Real-time language switching

3. **Titan Embeddings v2** (`amazon.titan-embed-text-v2:0`)
   - **Purpose**: Vector embeddings for RAG
   - **Dimensions**: 1024
   - **Use Cases**:
     - Semantic search across patient reports
     - Document similarity for retrieval
     - Medical entity clustering

## IAM Configuration

### EKS Service Account Role

The `bedrock-eks-role` allows AI agent pods running in EKS to invoke Bedrock models using IRSA (IAM Roles for Service Accounts).

**Role ARN**: Output as `bedrock_eks_role_arn`

**Permissions**:
- `bedrock:InvokeModel` - Invoke foundation models
- `bedrock:InvokeModelWithResponseStream` - Stream responses for real-time updates
- `bedrock:ListFoundationModels` - List available models
- `bedrock:GetFoundationModel` - Get model details
- `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents` - CloudWatch logging

**Trust Policy**: Assumes role via OIDC provider for Kubernetes service account `bedrock-service-account` in namespace `ai-agents`

### Lambda Execution Role

The `bedrock-lambda-role` allows Lambda functions to invoke Bedrock models.

**Role ARN**: Output as `bedrock_lambda_role_arn`

**Permissions**: Same as EKS role plus basic Lambda execution permissions

## Configuration Storage

Bedrock configuration is stored in AWS Systems Manager Parameter Store:

**Parameter Name**: `/${project_name}/${environment}/bedrock/config`

**Configuration Structure**:
```json
{
  "models": {
    "clinical_summarization": {
      "model_id": "anthropic.claude-3-sonnet-20240229-v1:0",
      "max_tokens": 4096,
      "temperature": 0.7,
      "top_p": 0.9
    },
    "explainability": {
      "model_id": "anthropic.claude-3-sonnet-20240229-v1:0",
      "max_tokens": 2048,
      "temperature": 0.5,
      "top_p": 0.9
    },
    "translation": {
      "model_id": "anthropic.claude-3-haiku-20240307-v1:0",
      "max_tokens": 2048,
      "temperature": 0.3,
      "top_p": 0.9
    },
    "embeddings": {
      "model_id": "amazon.titan-embed-text-v2:0",
      "dimensions": 1024
    }
  },
  "region": "us-east-1",
  "logging": {
    "enabled": true,
    "log_group": "/aws/bedrock/project-env"
  },
  "rate_limits": {
    "requests_per_minute": 100,
    "tokens_per_minute": 100000
  }
}
```

## Logging and Monitoring

### CloudWatch Log Groups

1. **Invocation Logs**: `/aws/bedrock/${project_name}-${environment}`
   - Retention: 30 days
   - Encrypted with KMS
   - Contains model invocation requests and responses

2. **Metrics Logs**: `/aws/bedrock/${project_name}-${environment}/metrics`
   - Retention: 90 days
   - Encrypted with KMS
   - Contains performance metrics and usage statistics

### Key Metrics to Monitor

- **Invocation Count**: Number of model invocations per agent
- **Latency**: Time to first token and total response time
- **Token Usage**: Input and output tokens per request
- **Error Rate**: Failed invocations and throttling events
- **Cost**: Estimated cost per model and per agent

## Rate Limits

Default rate limits (can be increased via AWS Support):
- **Requests per minute**: 100
- **Tokens per minute**: 100,000

**Mitigation Strategies**:
- Implement exponential backoff for throttled requests
- Cache frequently requested summaries
- Use streaming responses for better user experience
- Monitor usage and request limit increases proactively

## Security Best Practices

1. **Least Privilege**: IAM roles grant only necessary Bedrock permissions
2. **Encryption**: All logs encrypted with KMS
3. **Audit Trail**: All invocations logged to CloudWatch
4. **Network Isolation**: Bedrock accessed via VPC endpoints (when available)
5. **Model Versioning**: Specific model versions pinned to avoid unexpected changes

## Model Access Requirements

### Prerequisites

Before deploying, ensure:

1. **Model Access Enabled**: Request access to Anthropic Claude models in AWS Console
   - Navigate to Amazon Bedrock → Model access
   - Request access to Claude 3 Sonnet and Claude 3 Haiku
   - Request access to Titan Embeddings v2
   - Wait for approval (usually instant for most regions)

2. **Region Availability**: Verify models are available in your deployment region
   - Recommended regions: `us-east-1`, `us-west-2`, `eu-west-1`

3. **Service Quotas**: Check and request increases if needed
   - Navigate to Service Quotas → Amazon Bedrock
   - Review default quotas for your use case

## Deployment

### Step 1: Enable Model Access

```bash
# Check available models
aws bedrock list-foundation-models --region us-east-1

# Request model access (via AWS Console - no CLI command available)
# Go to: https://console.aws.amazon.com/bedrock/home?region=us-east-1#/modelaccess
```

### Step 2: Deploy Terraform Configuration

```bash
cd infrastructure/terraform

# Initialize Terraform (if not already done)
terraform init

# Plan the deployment
terraform plan -var-file=terraform.tfvars.mvp

# Apply the configuration
terraform apply -var-file=terraform.tfvars.mvp
```

### Step 3: Verify Configuration

```bash
# Check IAM roles
aws iam get-role --role-name <project>-bedrock-eks-role-<env>
aws iam get-role --role-name <project>-bedrock-lambda-role-<env>

# Check SSM parameter
aws ssm get-parameter --name "/<project>/<env>/bedrock/config" --region us-east-1

# Check CloudWatch log groups
aws logs describe-log-groups --log-group-name-prefix "/aws/bedrock/<project>"
```

### Step 4: Test Model Invocation

```bash
# Test Claude 3 Sonnet invocation
aws bedrock-runtime invoke-model \
  --model-id anthropic.claude-3-sonnet-20240229-v1:0 \
  --body '{"anthropic_version":"bedrock-2023-05-31","max_tokens":100,"messages":[{"role":"user","content":"Hello"}]}' \
  --region us-east-1 \
  output.json

# Check response
cat output.json
```

## Integration with AI Agents

### Python SDK Example

```python
import boto3
import json

# Initialize Bedrock client
bedrock_runtime = boto3.client('bedrock-runtime', region_name='us-east-1')

# Invoke Claude 3 Sonnet for clinical summarization
def summarize_clinical_data(patient_data: dict) -> str:
    prompt = f"""Summarize the following patient data:
    
    Chief Complaint: {patient_data.get('chief_complaint')}
    Medical History: {patient_data.get('medical_history')}
    Current Medications: {patient_data.get('medications')}
    Lab Results: {patient_data.get('lab_results')}
    
    Provide a structured clinical summary."""
    
    body = json.dumps({
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 4096,
        "temperature": 0.7,
        "top_p": 0.9,
        "messages": [
            {
                "role": "user",
                "content": prompt
            }
        ]
    })
    
    response = bedrock_runtime.invoke_model(
        modelId='anthropic.claude-3-sonnet-20240229-v1:0',
        body=body
    )
    
    response_body = json.loads(response['body'].read())
    return response_body['content'][0]['text']

# Invoke Titan Embeddings for vector generation
def generate_embeddings(text: str) -> list:
    body = json.dumps({
        "inputText": text
    })
    
    response = bedrock_runtime.invoke_model(
        modelId='amazon.titan-embed-text-v2:0',
        body=body
    )
    
    response_body = json.loads(response['body'].read())
    return response_body['embedding']
```

### Kubernetes Service Account Configuration

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: bedrock-service-account
  namespace: ai-agents
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::<account-id>:role/<project>-bedrock-eks-role-<env>
```

## Cost Optimization

### Pricing (as of 2024)

**Claude 3 Sonnet**:
- Input: $3.00 per 1M tokens
- Output: $15.00 per 1M tokens

**Claude 3 Haiku**:
- Input: $0.25 per 1M tokens
- Output: $1.25 per 1M tokens

**Titan Embeddings v2**:
- $0.02 per 1K tokens

### Cost Reduction Strategies

1. **Use Haiku for Translation**: 12x cheaper than Sonnet
2. **Cache Embeddings**: Store in OpenSearch to avoid regeneration
3. **Optimize Prompts**: Reduce input token count with concise prompts
4. **Batch Processing**: Process multiple requests together when possible
5. **Monitor Usage**: Set up CloudWatch alarms for cost thresholds

## Troubleshooting

### Common Issues

1. **Model Access Denied**
   - **Error**: `AccessDeniedException: You don't have access to the model`
   - **Solution**: Request model access in AWS Console → Bedrock → Model access

2. **Throttling Errors**
   - **Error**: `ThrottlingException: Rate exceeded`
   - **Solution**: Implement exponential backoff, request quota increase

3. **Invalid Model ID**
   - **Error**: `ValidationException: The provided model identifier is invalid`
   - **Solution**: Verify model ID and region availability

4. **IAM Permission Issues**
   - **Error**: `AccessDeniedException: User is not authorized`
   - **Solution**: Verify IAM role has `bedrock:InvokeModel` permission

### Debug Commands

```bash
# Check model availability
aws bedrock list-foundation-models --by-provider Anthropic --region us-east-1

# Test IAM permissions
aws bedrock-runtime invoke-model \
  --model-id anthropic.claude-3-sonnet-20240229-v1:0 \
  --body '{"anthropic_version":"bedrock-2023-05-31","max_tokens":10,"messages":[{"role":"user","content":"test"}]}' \
  --region us-east-1 \
  test-output.json

# Check CloudWatch logs
aws logs tail /aws/bedrock/<project>-<env> --follow
```

## Next Steps

After completing this task:

1. **Task 9.1**: Create Clinical Summarization Agent using Bedrock
2. **Task 9.2**: Implement multilingual translation with Bedrock
3. **Task 11.1**: Create Explainability Agent using Bedrock
4. **Task 7.2**: Implement vector embeddings with Bedrock Titan

## References

- [Amazon Bedrock Documentation](https://docs.aws.amazon.com/bedrock/)
- [Claude 3 Model Guide](https://docs.anthropic.com/claude/docs/models-overview)
- [Bedrock Pricing](https://aws.amazon.com/bedrock/pricing/)
- [IAM Roles for Service Accounts (IRSA)](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
