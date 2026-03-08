# Configuration Directory

This directory contains configuration files for different environments.

## Environment Variables

The application uses environment variables for configuration. Create a `.env` file in the root directory with the following variables:

```bash
# Application Settings
APP_NAME="Clinical AI Capabilities"
ENVIRONMENT=development
DEBUG=false

# Logging Settings
LOG_LEVEL=INFO
LOG_FORMAT=json

# AI Model Settings
CLINICAL_LLM_MODEL=clinical-llm-v1
VISION_MODEL=vision-transformer-v1
MODEL_TIMEOUT_SECONDS=30

# Performance Settings
SUMMARIZATION_TIMEOUT_SECONDS=30
RADIOLOGY_TEXT_TIMEOUT_SECONDS=10
RADIOLOGY_MULTIMODAL_TIMEOUT_SECONDS=30
DOCUMENTATION_TIMEOUT_SECONDS=20
WORKFLOW_TIMEOUT_SECONDS=5

# EMR Integration Settings
EMR_FHIR_BASE_URL=https://emr.example.com/fhir
EMR_API_TIMEOUT_SECONDS=10
EMR_RETRY_ATTEMPTS=3
EMR_CIRCUIT_BREAKER_THRESHOLD=5
EMR_CIRCUIT_BREAKER_TIMEOUT_SECONDS=60

# RAG System Settings
VECTOR_STORE_URL=https://vectorstore.example.com
EMBEDDING_MODEL=clinical-embeddings-v1
RAG_CHUNK_SIZE=512
RAG_CHUNK_OVERLAP=50
RAG_TOP_K=5

# Security Settings
ENCRYPTION_KEY=your-encryption-key-here
TLS_VERSION=1.3
AUDIT_LOG_RETENTION_DAYS=2555

# Performance Monitoring
METRICS_COLLECTION_INTERVAL_SECONDS=604800
PERFORMANCE_DEGRADATION_THRESHOLD=0.10
BIAS_DETECTION_THRESHOLD=0.15

# Compliance Settings
HIPAA_COMPLIANCE_ENABLED=true
DPDP_COMPLIANCE_ENABLED=true
DATA_BREACH_ALERT_TIMEOUT_SECONDS=60
```

## Environment-Specific Configuration

- **Development**: Use `.env.development` for local development
- **Testing**: Use `.env.testing` for test environments
- **Staging**: Use `.env.staging` for staging environments
- **Production**: Use `.env.production` for production environments

## Security Notes

- Never commit `.env` files to version control
- Use secure key management systems for production encryption keys
- Rotate encryption keys regularly
- Ensure EMR API credentials are stored securely
