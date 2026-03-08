# Test Amazon Bedrock configuration (PowerShell)
# Task 7.3: Configure Amazon Bedrock access

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Amazon Bedrock Configuration Test" -ForegroundColor Cyan
Write-Host "Task 7.3: Configure Amazon Bedrock Access" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Python is available
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Python 3 is required but not installed" -ForegroundColor Red
    exit 1
}

# Check if AWS CLI is configured
try {
    aws sts get-caller-identity | Out-Null
    Write-Host "✅ AWS CLI configured" -ForegroundColor Green
    Write-Host ""
} catch {
    Write-Host "❌ AWS CLI is not configured or credentials are invalid" -ForegroundColor Red
    Write-Host "Run: aws configure" -ForegroundColor Yellow
    exit 1
}

# Install required Python packages if needed
try {
    python -c "import boto3" 2>$null
} catch {
    Write-Host "Installing boto3..." -ForegroundColor Yellow
    pip install boto3
}

# Run the Python test script
python test_bedrock.py

exit $LASTEXITCODE
