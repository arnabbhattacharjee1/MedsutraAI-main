#!/usr/bin/env python3
"""
DynamoDB Tables Configuration Validator
Validates the DynamoDB configuration for sessions and agent_status tables
"""

import re
import sys
from pathlib import Path


class Colors:
    """ANSI color codes for terminal output"""
    GREEN = '\033[0;32m'
    RED = '\033[0;31m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'  # No Color


def print_success(message):
    """Print success message in green"""
    print(f"{Colors.GREEN}✓{Colors.NC} {message}")


def print_error(message):
    """Print error message in red"""
    print(f"{Colors.RED}✗{Colors.NC} {message}")


def print_warning(message):
    """Print warning message in yellow"""
    print(f"{Colors.YELLOW}⚠{Colors.NC} {message}")


def print_info(message):
    """Print info message in blue"""
    print(f"{Colors.BLUE}ℹ{Colors.NC} {message}")


def read_file(filepath):
    """Read file content"""
    try:
        with open(filepath, 'r') as f:
            return f.read()
    except FileNotFoundError:
        print_error(f"File not found: {filepath}")
        return None


def validate_table_structure(content, table_name):
    """Validate DynamoDB table structure"""
    errors = []
    warnings = []
    
    # Check if table resource exists
    table_pattern = rf'resource\s+"aws_dynamodb_table"\s+"{table_name}"'
    if not re.search(table_pattern, content):
        errors.append(f"Table resource '{table_name}' not found")
        return errors, warnings
    
    # Extract table block
    table_match = re.search(
        rf'resource\s+"aws_dynamodb_table"\s+"{table_name}"\s*{{([^}}]*(?:{{[^}}]*}}[^}}]*)*?)}}',
        content,
        re.DOTALL
    )
    
    if not table_match:
        errors.append(f"Could not parse table block for '{table_name}'")
        return errors, warnings
    
    table_block = table_match.group(1)
    
    # Validate billing mode
    if 'billing_mode' not in table_block:
        errors.append(f"Table '{table_name}': billing_mode not specified")
    elif 'PAY_PER_REQUEST' not in table_block:
        warnings.append(f"Table '{table_name}': billing_mode is not PAY_PER_REQUEST (on-demand)")
    
    # Validate encryption
    if 'server_side_encryption' not in table_block:
        errors.append(f"Table '{table_name}': server_side_encryption not configured")
    elif 'kms_key_arn' not in table_block:
        errors.append(f"Table '{table_name}': KMS key not specified for encryption")
    elif 'aws_kms_key.dynamodb_encryption.arn' not in table_block:
        errors.append(f"Table '{table_name}': Not using correct KMS key (should be aws_kms_key.dynamodb_encryption.arn)")
    
    # Validate TTL
    if 'ttl {' not in table_block:
        errors.append(f"Table '{table_name}': TTL not configured")
    elif 'enabled' not in table_block or 'enabled = true' not in table_block:
        warnings.append(f"Table '{table_name}': TTL might not be enabled")
    
    # Validate point-in-time recovery
    if 'point_in_time_recovery' not in table_block:
        warnings.append(f"Table '{table_name}': point_in_time_recovery not configured")
    
    # Validate hash key
    if 'hash_key' not in table_block:
        errors.append(f"Table '{table_name}': hash_key not specified")
    
    return errors, warnings


def validate_sessions_table(content):
    """Validate sessions table specific requirements"""
    errors = []
    warnings = []
    
    print_info("Validating sessions table...")
    
    # Basic structure validation
    struct_errors, struct_warnings = validate_table_structure(content, 'sessions')
    errors.extend(struct_errors)
    warnings.extend(struct_warnings)
    
    # Check for required attributes
    required_attributes = ['session_id', 'user_id', 'expires_at']
    for attr in required_attributes:
        if f'name = "{attr}"' not in content:
            errors.append(f"Sessions table: Required attribute '{attr}' not found")
    
    # Check for GSI on user_id
    if 'UserIdIndex' not in content:
        warnings.append("Sessions table: UserIdIndex GSI not found (recommended for querying by user)")
    
    # Check for GSI on expires_at
    if 'ExpiresAtIndex' not in content:
        warnings.append("Sessions table: ExpiresAtIndex GSI not found (recommended for cleanup queries)")
    
    return errors, warnings


def validate_agent_status_table(content):
    """Validate agent_status table specific requirements"""
    errors = []
    warnings = []
    
    print_info("Validating agent_status table...")
    
    # Basic structure validation
    struct_errors, struct_warnings = validate_table_structure(content, 'agent_status')
    errors.extend(struct_errors)
    warnings.extend(struct_warnings)
    
    # Check for required attributes
    required_attributes = ['session_id', 'agent_id', 'updated_at']
    for attr in required_attributes:
        if f'name = "{attr}"' not in content:
            errors.append(f"Agent_status table: Required attribute '{attr}' not found")
    
    # Check for composite key (hash + range)
    if 'range_key' not in content:
        errors.append("Agent_status table: range_key not specified (should be agent_id)")
    
    # Check for DynamoDB Streams
    if 'stream_enabled' not in content:
        errors.append("Agent_status table: DynamoDB Streams not enabled (required for WebSocket updates)")
    elif 'stream_enabled = true' not in content:
        errors.append("Agent_status table: DynamoDB Streams not enabled")
    
    if 'stream_view_type' not in content:
        errors.append("Agent_status table: stream_view_type not specified")
    elif 'NEW_AND_OLD_IMAGES' not in content:
        warnings.append("Agent_status table: stream_view_type should be NEW_AND_OLD_IMAGES for full change tracking")
    
    # Check for UpdatedAtIndex GSI
    if 'UpdatedAtIndex' not in content:
        warnings.append("Agent_status table: UpdatedAtIndex GSI not found (recommended for time-based queries)")
    
    return errors, warnings


def validate_outputs(content):
    """Validate DynamoDB outputs in outputs.tf"""
    errors = []
    warnings = []
    
    print_info("Validating outputs configuration...")
    
    required_outputs = [
        'dynamodb_sessions_table_name',
        'dynamodb_sessions_table_arn',
        'dynamodb_agent_status_table_name',
        'dynamodb_agent_status_table_arn',
        'dynamodb_agent_status_stream_arn'
    ]
    
    for output in required_outputs:
        if f'output "{output}"' not in content:
            warnings.append(f"Output '{output}' not found in outputs.tf")
    
    return errors, warnings


def main():
    """Main validation function"""
    print("=" * 50)
    print("DynamoDB Configuration Validation")
    print("=" * 50)
    print()
    
    # Read configuration files
    dynamodb_content = read_file('dynamodb.tf')
    outputs_content = read_file('outputs.tf')
    
    if not dynamodb_content:
        print_error("Failed to read dynamodb.tf")
        sys.exit(1)
    
    all_errors = []
    all_warnings = []
    
    # Validate sessions table
    errors, warnings = validate_sessions_table(dynamodb_content)
    all_errors.extend(errors)
    all_warnings.extend(warnings)
    
    if not errors:
        print_success("Sessions table configuration valid")
    print()
    
    # Validate agent_status table
    errors, warnings = validate_agent_status_table(dynamodb_content)
    all_errors.extend(errors)
    all_warnings.extend(warnings)
    
    if not errors:
        print_success("Agent_status table configuration valid")
    print()
    
    # Validate outputs
    if outputs_content:
        errors, warnings = validate_outputs(outputs_content)
        all_errors.extend(errors)
        all_warnings.extend(warnings)
        
        if not errors:
            print_success("Outputs configuration valid")
    else:
        print_warning("Could not validate outputs.tf")
    print()
    
    # Print summary
    print("=" * 50)
    print("Validation Summary")
    print("=" * 50)
    
    if all_errors:
        print(f"\n{Colors.RED}Errors found:{Colors.NC}")
        for error in all_errors:
            print_error(error)
    
    if all_warnings:
        print(f"\n{Colors.YELLOW}Warnings:{Colors.NC}")
        for warning in all_warnings:
            print_warning(warning)
    
    if not all_errors and not all_warnings:
        print_success("All validations passed!")
        print()
        print("Configuration Summary:")
        print("  • Sessions table: Configured with TTL and encryption")
        print("  • Agent_status table: Configured with streams, TTL, and encryption")
        print("  • Both tables: On-demand billing mode")
        print("  • Encryption: Using aws_kms_key.dynamodb_encryption")
        print("  • Point-in-time recovery: Enabled")
        return 0
    elif all_errors:
        print()
        print_error(f"Validation failed with {len(all_errors)} error(s)")
        return 1
    else:
        print()
        print_warning(f"Validation passed with {len(all_warnings)} warning(s)")
        return 0


if __name__ == '__main__':
    sys.exit(main())
