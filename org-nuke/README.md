# org-nuke

`org-nuke` is a modular wrapper script around `aws-nuke` designed to safely manage and execute resource cleanup across AWS accounts in an organization.

## Overview

This tool provides a structured approach to using `aws-nuke` across multiple AWS accounts with:

- Pre-configured safety measures
- Account-specific configuration management
- AWS SSO integration
- Modular command structure

## Prerequisites

- AWS CLI v2 with SSO configured
- Go 1.16 or later (if building `aws-nuke` locally)
- AWS SSO access to target accounts
- Proper IAM permissions in target accounts

## Structure

```text
org-nuke/
├── configs/            # Account-specific aws-nuke configurations
│   ├── sample.yaml    # Template configuration
│   └── *.yaml         # Account-specific configurations
├── modules/           # Command modules
│   └── account.sh     # Account-specific nuke operations
├── org-nuke          # Main entry script
└── README.md         # This file
```

## Safety Features

- Blocklist protection for production/root accounts
- Account alias verification
- AWS SSO session validation
- Configuration templating and validation
- Role assumption security

## Configuration

Account configurations are stored in the `configs/` directory with the following naming convention:

```text
configs/<account-id>.yaml
```

Each configuration includes:

- Region specifications
- Account-specific resource filters
- Security controls
- Resource exclusions

AWS SSO CLI Configuration

```text
[sso-session LINQ_sso]
sso_start_url = https://linq.awsapps.com/start/#
sso_region = us-east-1
sso_registration_scopes = sso:account:access
[profile Org_prod]
sso_session = LINQ_sso
sso_account_id = 538023924079
sso_role_name = AWSAdministratorAccess
region = us-east-1
```

## Usage

```bash
./org-nuke <command> [args...]

Available commands:
  account     # Run aws-nuke against a specific AWS account
```

### Example: Nuking an Account

```bash
./org-nuke account 123456789012
```

This will:

1. Validate AWS SSO session
2. Create/validate account configuration
3. Assume proper IAM role
4. Execute aws-nuke with safety controls

## Environment Variables

- `AWS_PROFILE`: AWS CLI profile to use (defaults to "Org_prod")
- `AWS_NUKE_PARALLEL_QUERIES`: Number of parallel queries (defaults to 192)

## Safety Checks

1. AWS SSO session validation
2. Account configuration validation
3. Production account protection
4. Proper role assumption verification
5. Account alias verification

## Error Handling

The script includes comprehensive error handling for:

- Missing dependencies
- Invalid configurations
- Authentication failures
- Role assumption issues
- Command execution failures

## Contributing

1. Create or modify modules in the `modules/` directory
2. Update account configurations in `configs/`
3. Test changes in non-production accounts
4. Submit changes through pull requests

## Important Notes

- **DANGER**: This tool is destructive. Use with extreme caution.
- Always review account configurations before execution
- Test in non-production accounts first
- Maintain blocklists for critical accounts
- Monitor execution logs carefully

## Related Documentation

- [aws-nuke Documentation](https://github.com/ekristen/aws-nuke)
- [AWS Organizations Documentation](https://docs.aws.amazon.com/organizations/)
