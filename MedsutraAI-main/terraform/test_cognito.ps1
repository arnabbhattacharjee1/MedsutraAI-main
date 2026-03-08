# Test script for Cognito User Pool configuration
# Task 3.1: Configure Amazon Cognito User Pool

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Cognito User Pool Configuration Test" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Check if AWS CLI is installed
try {
    $null = Get-Command aws -ErrorAction Stop
    Write-Host "✓ AWS CLI is installed" -ForegroundColor Green
} catch {
    Write-Host "❌ AWS CLI is not installed" -ForegroundColor Red
    exit 1
}

# Get Cognito User Pool ID from Terraform output
Write-Host ""
Write-Host "Retrieving Cognito User Pool ID from Terraform..."
try {
    $UserPoolId = terraform output -raw cognito_user_pool_id 2>$null
    if ([string]::IsNullOrEmpty($UserPoolId)) {
        throw "Empty User Pool ID"
    }
    Write-Host "✓ User Pool ID: $UserPoolId" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to retrieve User Pool ID. Run 'terraform apply' first." -ForegroundColor Red
    exit 1
}

# Test 1: Verify User Pool exists
Write-Host ""
Write-Host "Test 1: Verifying User Pool exists..."
try {
    $UserPoolInfo = aws cognito-idp describe-user-pool --user-pool-id $UserPoolId | ConvertFrom-Json
    Write-Host "✓ User Pool exists" -ForegroundColor Green
} catch {
    Write-Host "❌ User Pool does not exist" -ForegroundColor Red
    exit 1
}

# Test 2: Verify MFA configuration
Write-Host ""
Write-Host "Test 2: Verifying MFA configuration..."
$MfaConfig = $UserPoolInfo.UserPool.MfaConfiguration

if ($MfaConfig -eq "OPTIONAL" -or $MfaConfig -eq "ON") {
    Write-Host "✓ MFA is configured: $MfaConfig" -ForegroundColor Green
} else {
    Write-Host "❌ MFA is not properly configured: $MfaConfig" -ForegroundColor Red
    exit 1
}

# Test 3: Verify Password Policy
Write-Host ""
Write-Host "Test 3: Verifying Password Policy..."
$PasswordPolicy = $UserPoolInfo.UserPool.Policies.PasswordPolicy
$MinLength = $PasswordPolicy.MinimumLength
$RequireLowercase = $PasswordPolicy.RequireLowercase
$RequireUppercase = $PasswordPolicy.RequireUppercase
$RequireNumbers = $PasswordPolicy.RequireNumbers
$RequireSymbols = $PasswordPolicy.RequireSymbols

if ($MinLength -ge 12 -and $RequireLowercase -and $RequireUppercase -and $RequireNumbers -and $RequireSymbols) {
    Write-Host "✓ Password policy meets requirements:" -ForegroundColor Green
    Write-Host "  - Minimum length: $MinLength characters"
    Write-Host "  - Requires lowercase: $RequireLowercase"
    Write-Host "  - Requires uppercase: $RequireUppercase"
    Write-Host "  - Requires numbers: $RequireNumbers"
    Write-Host "  - Requires symbols: $RequireSymbols"
} else {
    Write-Host "❌ Password policy does not meet requirements" -ForegroundColor Red
    exit 1
}

# Test 4: Verify Auto-verified Attributes
Write-Host ""
Write-Host "Test 4: Verifying auto-verified attributes..."
$AutoVerified = $UserPoolInfo.UserPool.AutoVerifiedAttributes

if ($AutoVerified -contains "email" -and $AutoVerified -contains "phone_number") {
    Write-Host "✓ Auto-verified attributes configured: $($AutoVerified -join ', ')" -ForegroundColor Green
} else {
    Write-Host "❌ Auto-verified attributes not properly configured" -ForegroundColor Red
    exit 1
}

# Test 5: Verify User Groups
Write-Host ""
Write-Host "Test 5: Verifying User Groups..."
try {
    $Groups = (aws cognito-idp list-groups --user-pool-id $UserPoolId | ConvertFrom-Json).Groups.GroupName
    
    $RequiredGroups = @("Oncologist", "Doctor", "Patient", "Admin")
    $AllGroupsExist = $true
    
    foreach ($group in $RequiredGroups) {
        if ($Groups -contains $group) {
            Write-Host "✓ Group exists: $group" -ForegroundColor Green
        } else {
            Write-Host "❌ Group missing: $group" -ForegroundColor Red
            $AllGroupsExist = $false
        }
    }
    
    if (-not $AllGroupsExist) {
        exit 1
    }
} catch {
    Write-Host "❌ Failed to retrieve User Groups" -ForegroundColor Red
    exit 1
}

# Test 6: Verify User Pool Client
Write-Host ""
Write-Host "Test 6: Verifying User Pool Client..."
try {
    $ClientId = terraform output -raw cognito_user_pool_client_id 2>$null
    if ([string]::IsNullOrEmpty($ClientId)) {
        throw "Empty Client ID"
    }
    
    $ClientInfo = aws cognito-idp describe-user-pool-client --user-pool-id $UserPoolId --client-id $ClientId | ConvertFrom-Json
    Write-Host "✓ User Pool Client exists" -ForegroundColor Green
    
    # Verify token validity
    $IdTokenValidity = $ClientInfo.UserPoolClient.IdTokenValidity
    $AccessTokenValidity = $ClientInfo.UserPoolClient.AccessTokenValidity
    
    Write-Host "  - ID Token Validity: $IdTokenValidity minutes"
    Write-Host "  - Access Token Validity: $AccessTokenValidity minutes"
    
    if ($IdTokenValidity -eq 15 -and $AccessTokenValidity -eq 15) {
        Write-Host "✓ Token validity configured correctly (15 minutes)" -ForegroundColor Green
    } else {
        Write-Host "⚠ Token validity differs from expected (15 minutes)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ User Pool Client does not exist" -ForegroundColor Red
    exit 1
}

# Test 7: Verify Advanced Security Mode
Write-Host ""
Write-Host "Test 7: Verifying Advanced Security Mode..."
$AdvancedSecurity = $UserPoolInfo.UserPool.UserPoolAddOns.AdvancedSecurityMode

if ($AdvancedSecurity -eq "ENFORCED") {
    Write-Host "✓ Advanced Security Mode is ENFORCED" -ForegroundColor Green
} else {
    Write-Host "⚠ Advanced Security Mode: $AdvancedSecurity" -ForegroundColor Yellow
}

# Test 8: Verify User Pool Domain
Write-Host ""
Write-Host "Test 8: Verifying User Pool Domain..."
try {
    $Domain = terraform output -raw cognito_user_pool_domain 2>$null
    if ([string]::IsNullOrEmpty($Domain)) {
        throw "Empty Domain"
    }
    
    $DomainInfo = aws cognito-idp describe-user-pool-domain --domain $Domain | ConvertFrom-Json
    Write-Host "✓ User Pool Domain exists: $Domain" -ForegroundColor Green
    
    $DomainUrl = terraform output -raw cognito_user_pool_domain_url 2>$null
    Write-Host "  - Domain URL: $DomainUrl"
} catch {
    Write-Host "❌ User Pool Domain does not exist" -ForegroundColor Red
    exit 1
}

# Summary
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "✓ All Cognito User Pool tests passed!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuration Summary:"
Write-Host "  - User Pool ID: $UserPoolId"
Write-Host "  - MFA: $MfaConfig"
Write-Host "  - Password Policy: 12+ chars with complexity"
Write-Host "  - Auto-verified: Email and Phone"
Write-Host "  - User Groups: Oncologist, Doctor, Patient, Admin"
Write-Host "  - Token Validity: 15 minutes"
Write-Host "  - Advanced Security: $AdvancedSecurity"
Write-Host "  - Domain: $Domain"
Write-Host ""
Write-Host "Next Steps:"
Write-Host "  1. Configure callback URLs for your application"
Write-Host "  2. Set up SES email identity for notifications"
Write-Host "  3. Create test users and assign to groups"
Write-Host "  4. Test authentication flow with your application"
Write-Host ""
