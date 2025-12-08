#!/bin/bash
set -e

echo "🔧 AWS Account Setup for Whoosh"
echo "================================="
echo ""

# Method 1: Interactive configuration
echo "Choose setup method:"
echo "1) Interactive (enter credentials manually)"
echo "2) Use existing AWS profile"
read -p "Enter choice [1-2]: " METHOD

if [ "$METHOD" = "1" ]; then
    # Interactive setup
    read -p "Enter profile name (default: whoosh): " PROFILE_NAME
    PROFILE_NAME=${PROFILE_NAME:-whoosh}
    
    echo ""
    echo "Enter your AWS credentials for the Whoosh account:"
    read -p "AWS Access Key ID: " AWS_ACCESS_KEY_ID
    read -sp "AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY
    echo ""
    read -p "Default region (default: us-east-1): " AWS_REGION
    AWS_REGION=${AWS_REGION:-us-east-1}
    
    # Configure AWS CLI
    aws configure set aws_access_key_id "${AWS_ACCESS_KEY_ID}" --profile ${PROFILE_NAME}
    aws configure set aws_secret_access_key "${AWS_SECRET_ACCESS_KEY}" --profile ${PROFILE_NAME}
    aws configure set region "${AWS_REGION}" --profile ${PROFILE_NAME}
    aws configure set output "json" --profile ${PROFILE_NAME}
    
    echo ""
    echo "✅ Profile '${PROFILE_NAME}' configured!"
    
elif [ "$METHOD" = "2" ]; then
    # Use existing profile
    echo ""
    echo "Available AWS profiles:"
    aws configure list-profiles
    echo ""
    read -p "Enter profile name to use: " PROFILE_NAME
    
    # Verify profile exists
    if ! aws configure list-profiles | grep -q "^${PROFILE_NAME}$"; then
        echo "❌ Profile '${PROFILE_NAME}' not found!"
        exit 1
    fi
else
    echo "❌ Invalid choice"
    exit 1
fi

# Verify credentials
echo ""
echo "Verifying credentials..."
ACCOUNT_INFO=$(aws sts get-caller-identity --profile ${PROFILE_NAME} 2>&1)

if echo "$ACCOUNT_INFO" | grep -q "Account"; then
    ACCOUNT_ID=$(echo "$ACCOUNT_INFO" | grep -o '"Account": "[^"]*"' | cut -d'"' -f4)
    USER_ARN=$(echo "$ACCOUNT_INFO" | grep -o '"Arn": "[^"]*"' | cut -d'"' -f4)
    
    echo "✅ Credentials verified!"
    echo ""
    echo "Account ID: ${ACCOUNT_ID}"
    echo "User ARN: ${USER_ARN}"
    echo ""
    
    # Export for use in setup script
    export AWS_PROFILE=${PROFILE_NAME}
    export AWS_ACCOUNT_ID=${ACCOUNT_ID}
    
    echo "📝 Profile '${PROFILE_NAME}' is now active for this session"
    echo ""
    echo "Next steps:"
    echo "1. Run: export AWS_PROFILE=${PROFILE_NAME}"
    echo "2. Run: ./scripts/setup-aws.sh"
    echo "3. Or run setup with profile: AWS_PROFILE=${PROFILE_NAME} ./scripts/setup-aws.sh"
    echo ""
    echo "Account ID for Terraform: ${ACCOUNT_ID}"
    
    # Save to file for reference
    echo "AWS_PROFILE=${PROFILE_NAME}" > .aws-profile
    echo "AWS_ACCOUNT_ID=${ACCOUNT_ID}" >> .aws-profile
    echo ""
    echo "✅ Saved profile info to .aws-profile"
    
else
    echo "❌ Error verifying credentials:"
    echo "$ACCOUNT_INFO"
    exit 1
fi

