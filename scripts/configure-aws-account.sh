#!/bin/bash

echo "🔧 Configure AWS Account for Whoosh"
echo "===================================="
echo ""
echo "This script will help you set up a new AWS profile for Whoosh."
echo ""

# Prompt for profile name
read -p "Enter profile name (default: whoosh): " PROFILE_NAME
PROFILE_NAME=${PROFILE_NAME:-whoosh}

echo ""
echo "Please provide your AWS credentials:"
read -p "AWS Access Key ID: " AWS_ACCESS_KEY_ID
read -sp "AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY
echo ""
read -p "Default region (default: us-east-1): " AWS_REGION
AWS_REGION=${AWS_REGION:-us-east-1}
read -p "Default output format (default: json): " AWS_OUTPUT
AWS_OUTPUT=${AWS_OUTPUT:-json}

echo ""
echo "Configuring AWS profile: ${PROFILE_NAME}..."

# Configure AWS CLI
aws configure set aws_access_key_id "${AWS_ACCESS_KEY_ID}" --profile ${PROFILE_NAME}
aws configure set aws_secret_access_key "${AWS_SECRET_ACCESS_KEY}" --profile ${PROFILE_NAME}
aws configure set region "${AWS_REGION}" --profile ${PROFILE_NAME}
aws configure set output "${AWS_OUTPUT}" --profile ${PROFILE_NAME}

echo ""
echo "✅ AWS profile '${PROFILE_NAME}' configured!"
echo ""
echo "Verifying credentials..."

# Verify the account
ACCOUNT_INFO=$(aws sts get-caller-identity --profile ${PROFILE_NAME} 2>&1)

if echo "$ACCOUNT_INFO" | grep -q "Account"; then
    echo "✅ Credentials verified!"
    echo ""
    echo "$ACCOUNT_INFO" | jq '.' 2>/dev/null || echo "$ACCOUNT_INFO"
    echo ""
    
    # Get account ID
    ACCOUNT_ID=$(echo "$ACCOUNT_INFO" | grep -o '"Account": "[^"]*"' | cut -d'"' -f4)
    
    echo "📝 Next steps:"
    echo "1. Update infrastructure/terraform/main.tf with your S3 bucket name"
    echo "2. Run setup script: AWS_PROFILE=${PROFILE_NAME} ./scripts/setup-aws.sh"
    echo "3. Or use this account ID for S3 bucket: ${ACCOUNT_ID}"
    echo ""
    echo "To use this profile, set: export AWS_PROFILE=${PROFILE_NAME}"
else
    echo "❌ Error verifying credentials:"
    echo "$ACCOUNT_INFO"
    exit 1
fi

