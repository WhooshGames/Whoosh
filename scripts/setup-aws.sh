#!/bin/bash
set -e

echo "🚀 Whoosh AWS Setup Script"
echo "=========================="
echo ""

# Use AWS profile if set
if [ -n "$AWS_PROFILE" ]; then
    echo "Using AWS profile: $AWS_PROFILE"
    export AWS_PROFILE
fi

# Get AWS account info
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=${AWS_REGION:-us-east-1}

echo "AWS Account ID: ${AWS_ACCOUNT_ID}"
echo "Region: ${REGION}"

echo "AWS Account ID: ${AWS_ACCOUNT_ID}"
echo "Region: ${REGION}"
echo ""

# Step 1: Create S3 bucket for Terraform state
echo "📦 Step 1: Creating S3 bucket for Terraform state..."
BUCKET_NAME="whoosh-terraform-state-${AWS_ACCOUNT_ID}"

if aws s3 ls "s3://${BUCKET_NAME}" 2>&1 | grep -q 'NoSuchBucket'; then
    aws s3 mb s3://${BUCKET_NAME} --region ${REGION}
    aws s3api put-bucket-versioning \
        --bucket ${BUCKET_NAME} \
        --versioning-configuration Status=Enabled
    aws s3api put-bucket-encryption \
        --bucket ${BUCKET_NAME} \
        --server-side-encryption-configuration '{
            "Rules": [{
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }]
        }'
    aws s3api put-public-access-block \
        --bucket ${BUCKET_NAME} \
        --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
    echo "✅ S3 bucket created: ${BUCKET_NAME}"
else
    echo "✅ S3 bucket already exists: ${BUCKET_NAME}"
fi

# Step 2: Create DynamoDB table for state locking
echo ""
echo "🔒 Step 2: Creating DynamoDB table for state locking..."
if aws dynamodb describe-table --table-name whoosh-terraform-locks --region ${REGION} 2>&1 | grep -q 'ResourceNotFoundException'; then
    aws dynamodb create-table \
        --table-name whoosh-terraform-locks \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region ${REGION} > /dev/null
    echo "⏳ Waiting for table to be active..."
    aws dynamodb wait table-exists --table-name whoosh-terraform-locks --region ${REGION}
    echo "✅ DynamoDB table created"
else
    echo "✅ DynamoDB table already exists"
fi

# Step 3: Create ECR repositories
echo ""
echo "🐳 Step 3: Creating ECR repositories..."
for repo in whoosh-django-api whoosh-go-game-edge; do
    if aws ecr describe-repositories --repository-names ${repo} --region ${REGION} 2>&1 | grep -q 'RepositoryNotFoundException'; then
        aws ecr create-repository \
            --repository-name ${repo} \
            --region ${REGION} \
            --image-scanning-configuration scanOnPush=true \
            --encryption-configuration encryptionType=AES256 > /dev/null
        echo "✅ Created ECR repository: ${repo}"
    else
        echo "✅ ECR repository already exists: ${repo}"
    fi
done

# Step 4: Generate and store JWT keys
echo ""
echo "🔑 Step 4: Setting up JWT keys in Secrets Manager..."
if aws secretsmanager describe-secret --secret-id whoosh/jwt-keys --region ${REGION} 2>&1 | grep -q 'ResourceNotFoundException'; then
    # Generate keys
    TEMP_DIR=$(mktemp -d)
    openssl genrsa -out ${TEMP_DIR}/jwt_private_key.pem 2048
    openssl rsa -in ${TEMP_DIR}/jwt_private_key.pem -pubout -out ${TEMP_DIR}/jwt_public_key.pem
    
    # Create secret
    PRIVATE_KEY=$(cat ${TEMP_DIR}/jwt_private_key.pem | tr -d '\n' | sed 's/$/\\n/' | tr -d '\n')
    PUBLIC_KEY=$(cat ${TEMP_DIR}/jwt_public_key.pem | tr -d '\n' | sed 's/$/\\n/' | tr -d '\n')
    
    aws secretsmanager create-secret \
        --name whoosh/jwt-keys \
        --description "JWT RSA keys for Whoosh authentication" \
        --secret-string "{\"private_key\":\"${PRIVATE_KEY}\",\"public_key\":\"${PUBLIC_KEY}\"}" \
        --region ${REGION} > /dev/null
    
    # Clean up
    rm -rf ${TEMP_DIR}
    echo "✅ JWT keys stored in Secrets Manager"
else
    echo "✅ JWT keys already exist in Secrets Manager"
fi

echo ""
echo "✨ Setup complete!"
echo ""
echo "Next steps:"
echo "1. Update infrastructure/terraform/main.tf with S3 bucket: ${BUCKET_NAME}"
echo "2. Create infrastructure/terraform/terraform.tfvars"
echo "3. Run: cd infrastructure/terraform && terraform init && terraform plan"
