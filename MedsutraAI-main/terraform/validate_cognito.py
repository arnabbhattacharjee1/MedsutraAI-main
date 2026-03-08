#!/usr/bin/env python3
"""
Syntax validation script for Cognito Terraform configuration
Checks basic syntax without requiring Terraform installation
"""

import os
import re
import sys

def check_terraform_syntax(file_path):
    """Basic syntax validation for Terraform files"""
    errors = []
    warnings = []
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
        lines = content.split('\n')
    
    print(f"Validating {os.path.basename(file_path)}...")
    print(f"  Lines: {len(lines)}")
    
    # Check for balanced braces
    open_braces = content.count('{')
    close_braces = content.count('}')
    if open_braces != close_braces:
        errors.append(f"Unbalanced braces: {open_braces} open, {close_braces} close")
    else:
        print(f"  ✓ Braces balanced: {open_braces} pairs")
    
    # Check for balanced brackets
    open_brackets = content.count('[')
    close_brackets = content.count(']')
    if open_brackets != close_brackets:
        errors.append(f"Unbalanced brackets: {open_brackets} open, {close_brackets} close")
    else:
        print(f"  ✓ Brackets balanced: {open_brackets} pairs")
    
    # Check for balanced quotes
    double_quotes = content.count('"')
    if double_quotes % 2 != 0:
        warnings.append(f"Odd number of double quotes: {double_quotes}")
    else:
        print(f"  ✓ Quotes balanced: {double_quotes // 2} pairs")
    
    # Check for Cognito resources
    cognito_resources = {
        'aws_cognito_user_pool': 0,
        'aws_cognito_user_pool_client': 0,
        'aws_cognito_user_pool_domain': 0,
        'aws_cognito_user_group': 0,
        'aws_cognito_risk_configuration': 0,
        'aws_iam_role': 0,
        'aws_ses_email_identity': 0,
    }
    
    for resource_type in cognito_resources.keys():
        pattern = rf'resource\s+"{resource_type}"'
        matches = re.findall(pattern, content)
        cognito_resources[resource_type] = len(matches)
    
    print(f"\n  Resources found:")
    for resource_type, count in cognito_resources.items():
        print(f"    - {resource_type}: {count}")
    
    # Validate expected resources
    if cognito_resources['aws_cognito_user_pool'] < 1:
        errors.append("Missing aws_cognito_user_pool resource")
    
    if cognito_resources['aws_cognito_user_pool_client'] < 1:
        errors.append("Missing aws_cognito_user_pool_client resource")
    
    if cognito_resources['aws_cognito_user_group'] < 4:
        warnings.append(f"Expected 4 user groups, found {cognito_resources['aws_cognito_user_group']}")
    
    if cognito_resources['aws_iam_role'] < 5:
        warnings.append(f"Expected 5 IAM roles, found {cognito_resources['aws_iam_role']}")
    
    # Check for required configurations
    required_configs = {
        'mfa_configuration': 'MFA configuration',
        'password_policy': 'Password policy',
        'account_recovery_setting': 'Account recovery',
        'auto_verified_attributes': 'Auto-verified attributes',
        'advanced_security_mode': 'Advanced security',
        'user_pool_add_ons': 'User pool add-ons',
    }
    
    print(f"\n  Required configurations:")
    for config, description in required_configs.items():
        if config in content:
            print(f"    ✓ {description}")
        else:
            errors.append(f"Missing {description} ({config})")
            print(f"    ✗ {description}")
    
    # Check for outputs
    output_pattern = r'output\s+"[\w_]+"'
    outputs = re.findall(output_pattern, content)
    print(f"\n  Outputs defined: {len(outputs)}")
    
    if len(outputs) < 10:
        warnings.append(f"Expected at least 10 outputs, found {len(outputs)}")
    
    return errors, warnings

def main():
    """Main validation function"""
    terraform_dir = os.path.dirname(os.path.abspath(__file__))
    cognito_file = os.path.join(terraform_dir, 'cognito.tf')
    
    print("=" * 60)
    print("Cognito Terraform Configuration Validation")
    print("=" * 60)
    print()
    
    if not os.path.exists(cognito_file):
        print(f"❌ File not found: cognito.tf")
        return 1
    
    errors, warnings = check_terraform_syntax(cognito_file)
    
    print()
    print("=" * 60)
    print("Validation Results")
    print("=" * 60)
    
    if errors:
        print(f"\n❌ {len(errors)} error(s) found:")
        for error in errors:
            print(f"   - {error}")
    
    if warnings:
        print(f"\n⚠️  {len(warnings)} warning(s) found:")
        for warning in warnings:
            print(f"   - {warning}")
    
    if not errors and not warnings:
        print("\n✅ All validation checks passed!")
        print("\nNext steps:")
        print("  1. Run 'terraform init' to initialize")
        print("  2. Run 'terraform validate' to validate configuration")
        print("  3. Run 'terraform plan' to preview changes")
        print("  4. Run 'terraform apply' to deploy")
        return 0
    elif not errors:
        print("\n✅ Syntax validation passed with warnings")
        print("\nWarnings can be addressed but are not blocking.")
        return 0
    else:
        print("\n❌ Validation failed. Please fix errors before deploying.")
        return 1

if __name__ == "__main__":
    sys.exit(main())
