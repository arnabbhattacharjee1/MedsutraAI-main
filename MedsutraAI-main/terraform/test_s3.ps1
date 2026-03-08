# PowerShell test script for S3 bucket configuration validation
# Validates bucket creation, encryption, versioning, logging, and policies

$ErrorActionPreference = "Continue"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "S3 Bucket Configuration Validation" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Test counters
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

# Function to print section header
function Print-Section {
    param([string]$Title)
    
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host $Title -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
}

# Test 1: Terraform syntax validation
Print-Section "Test 1: Terraform Syntax Validation"
$formatCheck = terraform fmt -check s3.tf 2>&1
if ($LASTEXITCODE -eq 0) {
    Print-Result $true "Terraform formatting is correct"
} else {
    Write-Host "⚠ WARNING: Terraform formatting issues detected, auto-formatting..." -ForegroundColor Yellow
    terraform fmt s3.tf | Out-Null
    Print-Result $true "Terraform formatting auto-corrected"
}

# Test 2: Terraform validation
Print-Section "Test 2: Terraform Configuration Validation"
$validateOutput = terraform validate 2>&1
if ($LASTEXITCODE -eq 0) {
    Print-Result $true "Terraform configuration is valid"
} else {
    Print-Result $false "Terraform configuration validation failed"
    Write-Host $validateOutput
}

# Test 3: Check for required S3 bucket resources
Print-Section "Test 3: Required S3 Bucket Resources"

$requiredBuckets = @(
    "aws_s3_bucket.medical_documents",
    "aws_s3_bucket.frontend_assets",
    "aws_s3_bucket.audit_logs",
    "aws_s3_bucket.access_logs"
)

$s3Content = Get-Content s3.tf -Raw

foreach ($bucket in $requiredBuckets) {
    $parts = $bucket -split '\.'
    $resourceType = $parts[0]
    $resourceName = $parts[1]
    $pattern = "resource `"$resourceType`" `"$resourceName`""
    
    if ($s3Content -match [regex]::Escape($pattern)) {
        Print-Result $true "Resource $bucket exists"
    } else {
        Print-Result $false "Resource $bucket is missing"
    }
}

# Test 4: Check encryption configuration
Print-Section "Test 4: Encryption Configuration"

# Check medical documents bucket uses KMS
if ($s3Content -match "aws_s3_bucket_server_side_encryption_configuration.*medical_documents" -and $s3Content -match "aws:kms") {
    Print-Result $true "Medical documents bucket uses KMS encryption"
} else {
    Print-Result $false "Medical documents bucket KMS encryption not configured"
}

# Check KMS key reference
if ($s3Content -match "aws_kms_key\.s3_encryption\.arn") {
    Print-Result $true "Medical documents bucket references correct KMS key"
} else {
    Print-Result $false "Medical documents bucket KMS key reference incorrect"
}

# Check frontend assets bucket uses AES256
if ($s3Content -match "aws_s3_bucket_server_side_encryption_configuration.*frontend_assets" -and $s3Content -match "AES256") {
    Print-Result $true "Frontend assets bucket uses AES256 encryption"
} else {
    Print-Result $false "Frontend assets bucket encryption not configured"
}

# Check audit logs bucket uses AES256
if ($s3Content -match "aws_s3_bucket_server_side_encryption_configuration.*audit_logs" -and $s3Content -match "AES256") {
    Print-Result $true "Audit logs bucket uses AES256 encryption"
} else {
    Print-Result $false "Audit logs bucket encryption not configured"
}

# Test 5: Check versioning configuration
Print-Section "Test 5: Versioning Configuration"

$versionedBuckets = @("medical_documents", "frontend_assets", "audit_logs", "access_logs")

foreach ($bucket in $versionedBuckets) {
    if ($s3Content -match "aws_s3_bucket_versioning.*$bucket" -and $s3Content -match "status\s*=\s*`"Enabled`"") {
        Print-Result $true "Versioning enabled for $bucket bucket"
    } else {
        Print-Result $false "Versioning not enabled for $bucket bucket"
    }
}

# Test 6: Check public access block
Print-Section "Test 6: Public Access Block Configuration"

foreach ($bucket in $versionedBuckets) {
    if ($s3Content -match "aws_s3_bucket_public_access_block.*$bucket" -and $s3Content -match "block_public_acls\s*=\s*true") {
        Print-Result $true "Public access blocked for $bucket bucket"
    } else {
        Print-Result $false "Public access not blocked for $bucket bucket"
    }
}

# Test 7: Check access logging configuration
Print-Section "Test 7: Access Logging Configuration"

$loggedBuckets = @("medical_documents", "frontend_assets", "audit_logs")

foreach ($bucket in $loggedBuckets) {
    if ($s3Content -match "aws_s3_bucket_logging.*$bucket" -and $s3Content -match "target_bucket\s*=\s*aws_s3_bucket\.access_logs\.id") {
        Print-Result $true "Access logging configured for $bucket bucket"
    } else {
        Print-Result $false "Access logging not configured for $bucket bucket"
    }
}

# Test 8: Check bucket policies
Print-Section "Test 8: Bucket Policy Configuration"

$policyBuckets = @("medical_documents", "frontend_assets", "audit_logs")

foreach ($bucket in $policyBuckets) {
    if ($s3Content -match "aws_s3_bucket_policy.*$bucket") {
        Print-Result $true "Bucket policy exists for $bucket bucket"
    } else {
        Print-Result $false "Bucket policy missing for $bucket bucket"
    }
}

# Test 9: Check security policies
Print-Section "Test 9: Security Policy Validation"

foreach ($bucket in $policyBuckets) {
    if ($s3Content -match "aws_s3_bucket_policy.*$bucket[\s\S]*?DenyInsecureTransport") {
        Print-Result $true "DenyInsecureTransport policy exists for $bucket bucket"
    } else {
        Print-Result $false "DenyInsecureTransport policy missing for $bucket bucket"
    }
}

# Check for encryption enforcement in medical documents bucket
if ($s3Content -match "aws_s3_bucket_policy.*medical_documents[\s\S]*?DenyUnencryptedObjectUploads") {
    Print-Result $true "Encryption enforcement policy exists for medical documents bucket"
} else {
    Print-Result $false "Encryption enforcement policy missing for medical documents bucket"
}

# Check for log deletion prevention in audit logs bucket
if ($s3Content -match "aws_s3_bucket_policy.*audit_logs[\s\S]*?PreventLogDeletion") {
    Print-Result $true "Log deletion prevention policy exists for audit logs bucket"
} else {
    Print-Result $false "Log deletion prevention policy missing for audit logs bucket"
}

# Test 10: Check lifecycle policies
Print-Section "Test 10: Lifecycle Policy Configuration"

if ($s3Content -match "aws_s3_bucket_lifecycle_configuration.*medical_documents[\s\S]*?noncurrent_version_expiration") {
    Print-Result $true "Lifecycle policy configured for medical documents bucket"
} else {
    Print-Result $false "Lifecycle policy missing for medical documents bucket"
}

if ($s3Content -match "aws_s3_bucket_lifecycle_configuration.*audit_logs[\s\S]*?2555") {
    Print-Result $true "7-year retention policy configured for audit logs bucket"
} else {
    Print-Result $false "7-year retention policy missing for audit logs bucket"
}

# Test 11: Check compliance tags
Print-Section "Test 11: Compliance Tagging"

if ($s3Content -match 'resource "aws_s3_bucket" "medical_documents"[\s\S]*?DataClassification\s*=\s*"PHI"') {
    Print-Result $true "PHI data classification tag exists for medical documents bucket"
} else {
    Print-Result $false "PHI data classification tag missing for medical documents bucket"
}

if ($s3Content -match 'resource "aws_s3_bucket" "medical_documents"[\s\S]*?Compliance') {
    Print-Result $true "Compliance tag exists for medical documents bucket"
} else {
    Print-Result $false "Compliance tag missing for medical documents bucket"
}

# Test 12: Check bucket key enablement
Print-Section "Test 12: Bucket Key Configuration"

foreach ($bucket in $versionedBuckets) {
    if ($s3Content -match "aws_s3_bucket_server_side_encryption_configuration.*$bucket[\s\S]*?bucket_key_enabled\s*=\s*true") {
        Print-Result $true "Bucket key enabled for $bucket bucket (cost optimization)"
    } else {
        Print-Result $false "Bucket key not enabled for $bucket bucket"
    }
}

# Test 13: Check outputs are defined
Print-Section "Test 13: Terraform Outputs"

$requiredOutputs = @(
    "s3_medical_documents_bucket_id",
    "s3_medical_documents_bucket_arn",
    "s3_frontend_assets_bucket_id",
    "s3_frontend_assets_bucket_arn",
    "s3_audit_logs_bucket_id",
    "s3_audit_logs_bucket_arn",
    "s3_access_logs_bucket_id",
    "s3_access_logs_bucket_arn"
)

$outputsContent = Get-Content outputs.tf -Raw

foreach ($output in $requiredOutputs) {
    if ($outputsContent -match "output `"$output`"") {
        Print-Result $true "Output $output is defined"
    } else {
        Print-Result $false "Output $output is missing"
    }
}

# Final summary
Print-Section "Test Summary"
$TotalTests = $TestsPassed + $TestsFailed
Write-Host "Total tests: $TotalTests"
Write-Host "Passed: $TestsPassed" -ForegroundColor Green
Write-Host "Failed: $TestsFailed" -ForegroundColor Red
Write-Host ""

if ($TestsFailed -eq 0) {
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "All tests passed! ✓" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
    exit 0
} else {
    Write-Host "==========================================" -ForegroundColor Red
    Write-Host "Some tests failed. Please review the output above." -ForegroundColor Red
    Write-Host "==========================================" -ForegroundColor Red
    exit 1
}
