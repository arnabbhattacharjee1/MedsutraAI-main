# PowerShell test script for DynamoDB tables configuration
# Validates Terraform syntax and configuration for sessions and agent_status tables

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "DynamoDB Tables Configuration Test" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Test counter
$TestsPassed = 0
$TestsFailed = 0

# Function to print test result
function Print-Result {
    param(
        [bool]$Success,
        [string]$Message
    )
    
    if ($Success) {
        Write-Host "✓ PASS: $Message" -ForegroundColor Green
        $script:TestsPassed++
    } else {
        Write-Host "✗ FAIL: $Message" -ForegroundColor Red
        $script:TestsFailed++
    }
}

# Test 1: Validate Terraform syntax
Write-Host "Test 1: Validating Terraform syntax..." -ForegroundColor Yellow
try {
    terraform fmt -check dynamodb.tf 2>&1 | Out-Null
    Print-Result -Success $true -Message "Terraform syntax validation"
} catch {
    Print-Result -Success $false -Message "Terraform syntax validation"
}
Write-Host ""

# Test 2: Validate Python syntax
Write-Host "Test 2: Validating Python syntax..." -ForegroundColor Yellow
try {
    python -m py_compile validate_dynamodb.py 2>&1 | Out-Null
    Print-Result -Success $true -Message "Python syntax validation"
} catch {
    Print-Result -Success $false -Message "Python syntax validation"
}
Write-Host ""

# Test 3: Run Python validation script
Write-Host "Test 3: Running DynamoDB configuration validation..." -ForegroundColor Yellow
try {
    python validate_dynamodb.py
    if ($LASTEXITCODE -eq 0) {
        Print-Result -Success $true -Message "DynamoDB configuration validation"
    } else {
        Print-Result -Success $false -Message "DynamoDB configuration validation"
    }
} catch {
    Print-Result -Success $false -Message "DynamoDB configuration validation"
}
Write-Host ""

# Test 4: Check for required resources
Write-Host "Test 4: Checking for required DynamoDB resources..." -ForegroundColor Yellow
$RequiredResources = @(
    "aws_dynamodb_table.sessions",
    "aws_dynamodb_table.agent_status"
)

$AllFound = $true
$Content = Get-Content -Path "dynamodb.tf" -Raw

foreach ($Resource in $RequiredResources) {
    $Parts = $Resource -split '\.'
    $ResourceType = $Parts[0]
    $ResourceName = $Parts[1]
    $Pattern = "resource `"$ResourceType`" `"$ResourceName`""
    
    if ($Content -match [regex]::Escape($Pattern)) {
        Write-Host "  ✓ Found: $Resource" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Missing: $Resource" -ForegroundColor Red
        $AllFound = $false
    }
}

Print-Result -Success $AllFound -Message "All required DynamoDB resources present"
Write-Host ""

# Test 5: Validate encryption configuration
Write-Host "Test 5: Validating encryption configuration..." -ForegroundColor Yellow
$HasEncryption = $Content -match "server_side_encryption"
$HasKMS = $Content -match "kms_key_arn = aws_kms_key\.dynamodb_encryption\.arn"

if ($HasEncryption -and $HasKMS) {
    Print-Result -Success $true -Message "Encryption with KMS configured correctly"
} else {
    Print-Result -Success $false -Message "Encryption configuration missing or incorrect"
}
Write-Host ""

# Test 6: Validate TTL configuration
Write-Host "Test 6: Validating TTL configuration..." -ForegroundColor Yellow
$TTLCount = ([regex]::Matches($Content, "ttl \{")).Count

if ($TTLCount -eq 2) {
    Print-Result -Success $true -Message "TTL configured for both tables"
} else {
    Print-Result -Success $false -Message "TTL configuration missing or incorrect (found $TTLCount, expected 2)"
}
Write-Host ""

# Test 7: Validate billing mode
Write-Host "Test 7: Validating billing mode (on-demand)..." -ForegroundColor Yellow
$BillingModeCount = ([regex]::Matches($Content, 'billing_mode\s*=\s*"PAY_PER_REQUEST"')).Count

if ($BillingModeCount -eq 2) {
    Print-Result -Success $true -Message "On-demand billing mode configured for both tables"
} else {
    Print-Result -Success $false -Message "Billing mode configuration incorrect (found $BillingModeCount, expected 2)"
}
Write-Host ""

# Test 8: Validate DynamoDB Streams
Write-Host "Test 8: Validating DynamoDB Streams configuration..." -ForegroundColor Yellow
$HasStreams = $Content -match "stream_enabled\s*=\s*true"
$HasStreamType = $Content -match 'stream_view_type\s*=\s*"NEW_AND_OLD_IMAGES"'

if ($HasStreams -and $HasStreamType) {
    Print-Result -Success $true -Message "DynamoDB Streams configured for agent_status table"
} else {
    Print-Result -Success $false -Message "DynamoDB Streams configuration missing or incorrect"
}
Write-Host ""

# Test 9: Validate Global Secondary Indexes
Write-Host "Test 9: Validating Global Secondary Indexes..." -ForegroundColor Yellow
$GSICount = ([regex]::Matches($Content, "global_secondary_index \{")).Count

if ($GSICount -ge 3) {
    Print-Result -Success $true -Message "Global Secondary Indexes configured (found $GSICount)"
} else {
    Print-Result -Success $false -Message "Insufficient Global Secondary Indexes (found $GSICount, expected at least 3)"
}
Write-Host ""

# Test 10: Validate point-in-time recovery
Write-Host "Test 10: Validating point-in-time recovery..." -ForegroundColor Yellow
$PITRCount = ([regex]::Matches($Content, "point_in_time_recovery \{")).Count

if ($PITRCount -eq 2) {
    Print-Result -Success $true -Message "Point-in-time recovery enabled for both tables"
} else {
    Print-Result -Success $false -Message "Point-in-time recovery configuration incorrect (found $PITRCount, expected 2)"
}
Write-Host ""

# Summary
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Tests Passed: $TestsPassed" -ForegroundColor Green
Write-Host "Tests Failed: $TestsFailed" -ForegroundColor Red
Write-Host ""

if ($TestsFailed -eq 0) {
    Write-Host "All tests passed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host "1. Review the DynamoDB configuration in dynamodb.tf"
    Write-Host "2. Run 'terraform plan' to preview the changes"
    Write-Host "3. Run 'terraform apply' to create the DynamoDB tables"
    Write-Host "4. Verify the tables in AWS Console"
    exit 0
} else {
    Write-Host "Some tests failed. Please review the configuration." -ForegroundColor Red
    exit 1
}
