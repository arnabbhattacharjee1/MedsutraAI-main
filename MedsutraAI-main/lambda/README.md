# Lambda Functions

This directory contains AWS Lambda functions for the AI Cancer Detection and Clinical Summarization Platform.

## Directory Structure

```
lambda/
├── authorizer/              # JWT Lambda Authorizer
│   ├── index.js            # Main handler
│   ├── index.test.js       # Unit tests
│   ├── package.json        # Dependencies
│   └── authorizer.zip      # Deployment package (generated)
│
├── token-refresh/          # Token Refresh Lambda
│   ├── index.js            # Main handler
│   ├── index.test.js       # Unit tests
│   ├── package.json        # Dependencies
│   └── token-refresh.zip   # Deployment package (generated)
│
├── deploy.sh               # Deployment script (Linux/Mac)
├── deploy.ps1              # Deployment script (Windows)
├── JWT_TOKEN_MANAGEMENT.md # Comprehensive documentation
├── JWT_QUICKSTART.md       # Quick start guide
├── TASK_3.2_COMPLETION.md  # Task completion report
└── README.md               # This file
```

## Quick Start

### 1. Package Lambda Functions

```bash
# Linux/Mac
./deploy.sh

# Windows
.\deploy.ps1
```

### 2. Deploy with Terraform

```bash
cd ../terraform
terraform apply
```

### 3. Test

```bash
# Run unit tests
cd authorizer
npm install
npm test

cd ../token-refresh
npm install
npm test
```

## Lambda Functions

### JWT Authorizer
- **Purpose**: Validates JWT tokens from Amazon Cognito
- **Runtime**: Node.js 20.x
- **Trigger**: API Gateway (TOKEN authorizer)
- **Requirements**: 13.2, 20.1

### Token Refresh
- **Purpose**: Refreshes expired JWT tokens
- **Runtime**: Node.js 20.x
- **Trigger**: API Gateway (HTTP POST)
- **Requirements**: 13.2, 20.1

## Documentation

- 📖 [JWT Token Management](./JWT_TOKEN_MANAGEMENT.md) - Comprehensive guide
- 📖 [Quick Start Guide](./JWT_QUICKSTART.md) - 5-minute setup
- 📖 [Task Completion Report](./TASK_3.2_COMPLETION.md) - Implementation details

## Requirements

- Node.js 20.x
- npm
- AWS CLI configured
- Terraform

## Testing

```bash
# JWT Authorizer
cd authorizer
npm install
npm test

# Token Refresh
cd token-refresh
npm install
npm test
```

## Deployment

See [JWT_QUICKSTART.md](./JWT_QUICKSTART.md) for deployment instructions.

## Support

For questions or issues, see [JWT_TOKEN_MANAGEMENT.md](./JWT_TOKEN_MANAGEMENT.md).
