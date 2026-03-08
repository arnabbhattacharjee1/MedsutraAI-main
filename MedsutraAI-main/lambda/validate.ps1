# Validation Script for JWT Token Management (PowerShell)
# Verifies that all components are correctly implemented

$ErrorActionPreference = "Continue"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "JWT Token Management Validation" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$PASSED = 0
$FAILED = 0

function Print-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
    $script:PASSED++
}

function Print-Warning {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
}

function Print-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
    $script:FAILED++
}

Write-Host "1. Checking file structure..."
Write-Host ""

# Check authorizer files
if (Test-Path "authorizer/index.js") {
    Print-Success "authorizer/index.js exists"
} else {
    Print-Error "authorizer/index.js missing"
}

if (Test-Path "authorizer/index.test.js") {
    Print-Success "authorizer/index.test.js exists"
} else {
    Print-Error "authorizer/index.test.js missing"
}

if (Test-Path "authorizer/package.json") {
    Print-Success "authorizer/package.json exists"
} else {
    Print-Error "authorizer/package.json missing"
}

# Check token-refresh files
if (Test-Path "token-refresh/index.js") {
    Print-Success "token-refresh/index.js exists"
} else {
    Print-Error "token-refresh/index.js missing"
}

if (Test-Path "token-refresh/index.test.js") {
    Print-Success "token-refresh/index.test.js exists"
} else {
    Print-Error "token-refresh/index.test.js missing"
}

if (Test-Path "token-refresh/package.json") {
    Print-Success "token-refresh/package.json exists"
} else {
    Print-Error "token-refresh/package.json missing"
}

# Check documentation
if (Test-Path "JWT_TOKEN_MANAGEMENT.md") {
    Print-Success "JWT_TOKEN_MANAGEMENT.md exists"
} else {
    Print-Error "JWT_TOKEN_MANAGEMENT.md missing"
}

if (Test-Path "JWT_QUICKSTART.md") {
    Print-Success "JWT_QUICKSTART.md exists"
} else {
    Print-Error "JWT_QUICKSTART.md missing"
}

if (Test-Path "TASK_3.2_COMPLETION.md") {
    Print-Success "TASK_3.2_COMPLETION.md exists"
} else {
    Print-Error "TASK_3.2_COMPLETION.md missing"
}

Write-Host ""
Write-Host "2. Checking code quality..."
Write-Host ""

# Check for required functions in authorizer
$authorizerContent = Get-Content "authorizer/index.js" -Raw
if ($authorizerContent -match "exports\.handler") {
    Print-Success "Authorizer handler function exists"
} else {
    Print-Error "Authorizer handler function missing"
}

if ($authorizerContent -match "verifyToken") {
    Print-Success "Token verification function exists"
} else {
    Print-Error "Token verification function missing"
}

if ($authorizerContent -match "generatePolicy") {
    Print-Success "Policy generation function exists"
} else {
    Print-Error "Policy generation function missing"
}

# Check for required functions in token-refresh
$tokenRefreshContent = Get-Content "token-refresh/index.js" -Raw
if ($tokenRefreshContent -match "exports\.handler") {
    Print-Success "Token refresh handler function exists"
} else {
    Print-Error "Token refresh handler function missing"
}

if ($tokenRefreshContent -match "refreshTokens") {
    Print-Success "Token refresh function exists"
} else {
    Print-Error "Token refresh function missing"
}

Write-Host ""
Write-Host "3. Checking requirements implementation..."
Write-Host ""

# Check Requirement 13.2 (15-minute expiration)
if ($authorizerContent -match "15 minutes" -or $authorizerContent -match "900") {
    Print-Success "Requirement 13.2: 15-minute expiration documented"
} else {
    Print-Warning "Requirement 13.2: 15-minute expiration not explicitly documented"
}

# Check Requirement 20.1 (unique session identifier)
if ($authorizerContent -match "decoded\.sub") {
    Print-Success "Requirement 20.1: Unique session identifier (sub claim) extracted"
} else {
    Print-Error "Requirement 20.1: Unique session identifier not extracted"
}

Write-Host ""
Write-Host "4. Checking test coverage..."
Write-Host ""

# Check authorizer tests
$authorizerTestContent = Get-Content "authorizer/index.test.js" -Raw
if ($authorizerTestContent -match "describe.*JWT Lambda Authorizer") {
    Print-Success "Authorizer test suite exists"
} else {
    Print-Error "Authorizer test suite missing"
}

if ($authorizerTestContent -match "Requirement 13\.2") {
    Print-Success "Requirement 13.2 test exists"
} else {
    Print-Error "Requirement 13.2 test missing"
}

if ($authorizerTestContent -match "Requirement 20\.1") {
    Print-Success "Requirement 20.1 test exists"
} else {
    Print-Error "Requirement 20.1 test missing"
}

# Check token-refresh tests
$tokenRefreshTestContent = Get-Content "token-refresh/index.test.js" -Raw
if ($tokenRefreshTestContent -match "describe.*Token Refresh Lambda") {
    Print-Success "Token refresh test suite exists"
} else {
    Print-Error "Token refresh test suite missing"
}

Write-Host ""
Write-Host "5. Checking Terraform configuration..."
Write-Host ""

if (Test-Path "../terraform/lambda_authorizer.tf") {
    Print-Success "Terraform configuration exists"
    
    $terraformContent = Get-Content "../terraform/lambda_authorizer.tf" -Raw
    if ($terraformContent -match "aws_lambda_function\.jwt_authorizer") {
        Print-Success "JWT authorizer Lambda resource defined"
    } else {
        Print-Error "JWT authorizer Lambda resource missing"
    }
    
    if ($terraformContent -match "aws_lambda_function\.token_refresh") {
        Print-Success "Token refresh Lambda resource defined"
    } else {
        Print-Error "Token refresh Lambda resource missing"
    }
} else {
    Print-Error "Terraform configuration missing"
}

Write-Host ""
Write-Host "6. Checking deployment scripts..."
Write-Host ""

if (Test-Path "deploy.sh") {
    Print-Success "Bash deployment script exists"
} else {
    Print-Error "Bash deployment script missing"
}

if (Test-Path "deploy.ps1") {
    Print-Success "PowerShell deployment script exists"
} else {
    Print-Error "PowerShell deployment script missing"
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Validation Summary" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Passed: $PASSED" -ForegroundColor Green
Write-Host "Failed: $FAILED" -ForegroundColor Red

Write-Host ""

if ($FAILED -eq 0) {
    Write-Host "✓ All validations passed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host "1. Run '.\deploy.ps1' to package Lambda functions"
    Write-Host "2. Run 'cd ..\terraform; terraform apply' to deploy"
    Write-Host "3. Test the implementation using JWT_QUICKSTART.md"
    exit 0
} else {
    Write-Host "✗ Some validations failed. Please fix the issues above." -ForegroundColor Red
    exit 1
}
