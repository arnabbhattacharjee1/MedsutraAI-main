# Deployment script for Task 4 Lambda functions
# PatientService (Node.js) and ReportService (Python)

$ErrorActionPreference = "Stop"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Task 4 Lambda Functions Deployment" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
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

# Check if required tools are installed
Write-Host "Checking prerequisites..." -ForegroundColor Cyan

try {
    $nodeVersion = node --version
    Print-Success "Node.js found: $nodeVersion"
} catch {
    Print-Error "Node.js is not installed"
    exit 1
}

try {
    $npmVersion = npm --version
    Print-Success "npm found: $npmVersion"
} catch {
    Print-Error "npm is not installed"
    exit 1
}

try {
    $pythonVersion = python --version
    Print-Success "Python found: $pythonVersion"
} catch {
    Print-Error "Python is not installed"
    exit 1
}

try {
    pip --version | Out-Null
    Print-Success "pip found"
} catch {
    Print-Error "pip is not installed"
    exit 1
}

Write-Host ""

# ============================================
# PatientService (Node.js 20)
# ============================================

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Building PatientService Lambda (Node.js)" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

Set-Location patient-service

Write-Host "Installing dependencies..." -ForegroundColor Cyan
npm install --production
if ($LASTEXITCODE -ne 0) {
    Print-Error "Failed to install dependencies"
    exit 1
}
Print-Success "Dependencies installed"

Write-Host "Running tests..." -ForegroundColor Cyan
npm test
if ($LASTEXITCODE -ne 0) {
    Print-Error "Tests failed"
    exit 1
}
Print-Success "Tests passed"

Write-Host "Creating deployment package..." -ForegroundColor Cyan
if (Test-Path "patient-service.zip") {
    Remove-Item "patient-service.zip"
}

# Use PowerShell's Compress-Archive
$filesToZip = @("index.js", "package.json")
$filesToZip += Get-ChildItem -Path "node_modules" -Recurse -File | ForEach-Object { $_.FullName }

Compress-Archive -Path "index.js", "package.json", "node_modules" -DestinationPath "patient-service.zip" -Force
Print-Success "Deployment package created: patient-service.zip"

$packageSize = (Get-Item "patient-service.zip").Length / 1MB
Write-Host "Package size: $([math]::Round($packageSize, 2)) MB"
Write-Host ""

Set-Location ..

# ============================================
# ReportService (Python 3.11)
# ============================================

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Building ReportService Lambda (Python)" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

Set-Location report-service

Write-Host "Installing dependencies..." -ForegroundColor Cyan
if (Test-Path "package") {
    Remove-Item -Recurse -Force "package"
}
New-Item -ItemType Directory -Path "package" | Out-Null

pip install -r requirements.txt -t package/ --upgrade | Out-Null
if ($LASTEXITCODE -ne 0) {
    Print-Error "Failed to install dependencies"
    exit 1
}
Print-Success "Dependencies installed"

Write-Host "Running tests..." -ForegroundColor Cyan
python -m pytest test_lambda_function.py -v
if ($LASTEXITCODE -ne 0) {
    Print-Error "Tests failed"
    exit 1
}
Print-Success "Tests passed"

Write-Host "Creating deployment package..." -ForegroundColor Cyan
if (Test-Path "report-service.zip") {
    Remove-Item "report-service.zip"
}

# Copy Lambda function to package directory
Copy-Item "lambda_function.py" -Destination "package/"

# Create zip from package directory
Set-Location package
Compress-Archive -Path "*" -DestinationPath "../report-service.zip" -Force
Set-Location ..

# Clean up package directory
Remove-Item -Recurse -Force "package"

Print-Success "Deployment package created: report-service.zip"

$packageSize = (Get-Item "report-service.zip").Length / 1MB
Write-Host "Package size: $([math]::Round($packageSize, 2)) MB"
Write-Host ""

Set-Location ..

# ============================================
# Summary
# ============================================

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Deployment Summary" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

Print-Success "PatientService: patient-service/patient-service.zip"
Print-Success "ReportService: report-service/report-service.zip"

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Deploy infrastructure with Terraform:"
Write-Host "   cd ../terraform"
Write-Host "   terraform apply"
Write-Host ""
Write-Host "2. Test API endpoints:"
Write-Host "   ./test_api_gateway.ps1"
Write-Host ""

Print-Success "Build completed successfully!"
