#!/bin/bash
set -e

echo "🔧 Installing Dependencies for Whoosh"
echo "======================================"
echo ""

# Check for Homebrew
if ! command -v brew &> /dev/null; then
    echo "❌ Homebrew not found. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

echo "✅ Homebrew installed/available"
echo ""

# Install Terraform
if ! command -v terraform &> /dev/null; then
    echo "📦 Installing Terraform..."
    brew install terraform
    echo "✅ Terraform installed"
else
    echo "✅ Terraform already installed: $(terraform --version | head -1)"
fi

# Install kubectl
if ! command -v kubectl &> /dev/null; then
    echo "📦 Installing kubectl..."
    brew install kubectl
    echo "✅ kubectl installed"
else
    echo "✅ kubectl already installed: $(kubectl version --client --short 2>/dev/null || echo 'installed')"
fi

# Install jq (useful for JSON parsing)
if ! command -v jq &> /dev/null; then
    echo "📦 Installing jq..."
    brew install jq
    echo "✅ jq installed"
else
    echo "✅ jq already installed"
fi

echo ""
echo "✨ All dependencies installed!"
echo ""
echo "Next steps:"
echo "1. cd infrastructure/terraform"
echo "2. export AWS_PROFILE=Whoosh"
echo "3. terraform init"
echo "4. terraform plan"

