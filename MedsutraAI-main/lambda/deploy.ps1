# Lambda Deployment Script (PowerShell)
# Packages Lambda functions for deployment

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Lambda Function Deployment Script" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

function Print-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Print-Warning {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
}

function Print-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

# Check if Node.js is installed
try {
    $nodeVersion = node --version
    Print-Success "Node.js version: $nodeVersion"
} catch {
    Print-Error "Node.js is not installed. Please install Node.js 20.x"
    exit 1
}

# Check if npm is installed
try {
    $npmVersion = npm --version
    Print-Success "npm version: $npmVersion"
} catch {
    Print-Error "npm is not installed. Please install npm"
    exit 1
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Packaging JWT Authorizer Lambda" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Set-Location authorizer

# Install dependencies
Write-Host "Installing dependencies..."
npm install --production

# Run tests (optional)
if ($args[0] -ne "--skip-tests") {
    Write-Host "Running tests..."
    npm install --save-dev
    try {
        npm test
    } catch {
        Print-Warning "Tests failed, but continuing with deployment"
    }
}

# Create deployment package
Write-Host "Creating deployment package..."
if (Test-Path authorizer.zip) {
    Remove-Item authorizer.zip
}

Compress-Archive -Path index.js, node_modules -DestinationPath authorizer.zip -Force

$size = (Get-Item authorizer.zip).Length / 1MB
Print-Success "Created authorizer.zip ($([math]::Round($size, 2)) MB)"

Set-Location ..

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Packaging Token Refresh Lambda" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Set-Location token-refresh

# Install dependencies
Write-Host "Installing dependencies..."
npm install --production

# Run tests (optional)
if ($args[0] -ne "--skip-tests") {
    Write-Host "Running tests..."
    npm install --save-dev
    try {
        npm test
    } catch {
        Print-Warning "Tests failed, but continuing with deployment"
    }
}

# Create deployment package
Write-Host "Creating deployment package..."
if (Test-Path token-refresh.zip) {
    Remove-Item token-refresh.zip
}

Compress-Archive -Path index.js, node_modules -DestinationPath token-refresh.zip -Force

$size = (Get-Item token-refresh.zip).Length / 1MB
Print-Success "Created token-refresh.zip ($([math]::Round($size, 2)) MB)"

Set-Location ..

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Deployment Summary" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Print-Success "JWT Authorizer: authorizer/authorizer.zip"
Print-Success "Token Refresh: token-refresh/token-refresh.zip"

Write-Host ""
Write-Host "Next steps:"
Write-Host "1. Run 'terraform apply' to deploy the Lambda functions"
Write-Host "2. Configure API Gateway to use the JWT authorizer"
Write-Host "3. Test the token refresh endpoint"
Write-Host ""

Print-Success "Lambda functions packaged successfully!"
