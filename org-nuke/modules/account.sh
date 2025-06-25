#!/usr/bin/env bash
# account.sh: Run aws-nuke against a specific AWS account
set -euo pipefail

# Parse arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <aws_account_id> [additional aws-nuke args...]"
    exit 1
fi

ACCOUNT_ID="$1"
shift

# Path to per-account aws-nuke config
CONFIGS_DIR="$SCRIPT_DIR/configs"
CONFIG_FILE="$CONFIGS_DIR/$ACCOUNT_ID.yaml"

# If config file does not exist, generate it from sample and update account ID
if [ ! -f "$CONFIG_FILE" ]; then
    SAMPLE_CONFIG="$CONFIGS_DIR/sample.yaml"
    if [ ! -f "$SAMPLE_CONFIG" ]; then
        echo "Sample config not found: $SAMPLE_CONFIG" >&2
        exit 2
    fi
    cp "$SAMPLE_CONFIG" "$CONFIG_FILE"
    # Replace placeholder with actual account ID
    sed -i '' "s/REPLACE_WITH_ACCOUNT_ID/$ACCOUNT_ID/g" "$CONFIG_FILE"
    echo "Generated new config file for account $ACCOUNT_ID at $CONFIG_FILE."
    echo "Please review and customize as needed."
fi

# Get the account name from AWS Organizations (using assumed role credentials)
ACCOUNT_NAME=$(aws organizations describe-account --account-id "$ACCOUNT_ID" --query 'Account.Name' --output text)
if [ -z "$ACCOUNT_NAME" ]; then
    echo "Error: Could not retrieve account name for $ACCOUNT_ID" >&2
    exit 5
fi

# Assume OrganizationAccountAccessRole in the target account
ROLE_ARN="arn:aws:iam::$ACCOUNT_ID:role/OrganizationAccountAccessRole"
ROLE_SESSION_NAME="org-nuke-session-$ACCOUNT_ID"
ASSUME_ROLE_OUTPUT=$(aws sts assume-role \
    --role-arn "$ROLE_ARN" \
    --role-session-name "$ROLE_SESSION_NAME")

if [ -z "$ASSUME_ROLE_OUTPUT" ]; then
    echo "Error: Failed to assume role $ROLE_ARN" >&2
    exit 3
fi

# Extract temporary credentials
AWS_ACCESS_KEY_ID=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r .Credentials.AccessKeyId)
AWS_SECRET_ACCESS_KEY=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r .Credentials.SecretAccessKey)
AWS_SESSION_TOKEN=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r .Credentials.SessionToken)
if [ -z "$AWS_ACCESS_KEY_ID" ] || \
   [ -z "$AWS_SECRET_ACCESS_KEY" ] || \
   [ -z "$AWS_SESSION_TOKEN" ]; then
    echo "Error: Could not extract temporary credentials from assume-role output." >&2
    exit 4
fi

# Export assumed role credentials for this session
export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_SESSION_TOKEN

# Unset AWS_PROFILE and AWS_DEFAULT_PROFILE to avoid conflicts
unset AWS_PROFILE
unset AWS_DEFAULT_PROFILE

# Sanitize the account name to create a valid alias: lowercase, replace spaces with dashes, remove invalid chars, append account number
ACCOUNT_ALIAS=$(echo "$ACCOUNT_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g' | sed 's/[^a-z0-9-]//g')
ACCOUNT_ALIAS="${ACCOUNT_ALIAS}-${ACCOUNT_ID}"

# Check if the account alias is already set to the sanitized account name
CURRENT_ALIAS=$(aws iam list-account-aliases --query 'AccountAliases[0]' --output text)
if [ "$CURRENT_ALIAS" = "None" ] || [ -z "$CURRENT_ALIAS" ]; then
    echo "No account alias set. Creating alias: $ACCOUNT_ALIAS"
    if aws iam create-account-alias --account-alias "$ACCOUNT_ALIAS"; then
        echo "Account alias set to $ACCOUNT_ALIAS."
    else
        echo "Failed to set account alias to $ACCOUNT_ALIAS." >&2
    fi
elif [ "$CURRENT_ALIAS" != "$ACCOUNT_ALIAS" ]; then
    aws iam delete-account-alias --account-alias "$CURRENT_ALIAS"
    if aws iam create-account-alias --account-alias "$ACCOUNT_ALIAS"; then
        echo "Account alias set to $ACCOUNT_ALIAS."
    else
        echo "Failed to set account alias to $ACCOUNT_ALIAS." >&2
    fi
else
    echo "Account alias is already set to $ACCOUNT_ALIAS."
fi

# Run aws-nuke with assumed role credentials (always no prompt)
export AWS_NUKE_PARALLEL_QUERIES=64
aws-nuke run --no-prompt --no-dry-run --config "$CONFIG_FILE" "$@"
