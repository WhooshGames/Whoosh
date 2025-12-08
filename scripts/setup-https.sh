#!/bin/bash
# Script to set up HTTPS with ACM certificate

set -e

DOMAIN_NAME="${1:-}"
AWS_PROFILE="${AWS_PROFILE:-Whoosh}"
REGION="${AWS_REGION:-us-east-1}"

if [ -z "$DOMAIN_NAME" ]; then
  echo "❌ Error: Domain name required"
  echo ""
  echo "Usage: $0 <domain-name>"
  echo "Example: $0 whoosh.example.com"
  echo ""
  echo "If you don't have a domain, you can:"
  echo "  1. Get one from Route 53 (AWS)"
  echo "  2. Get one from Namecheap, GoDaddy, etc."
  echo "  3. Use a subdomain of a domain you own"
  exit 1
fi

echo "🔒 Setting up HTTPS for domain: $DOMAIN_NAME"
echo ""

# Request certificate
echo "📋 Requesting ACM certificate..."
CERT_ARN=$(aws acm request-certificate \
  --domain-name "$DOMAIN_NAME" \
  --validation-method DNS \
  --region "$REGION" \
  --query 'CertificateArn' \
  --output text \
  --profile "$AWS_PROFILE" 2>&1)

if [ $? -ne 0 ]; then
  echo "⚠️  Certificate may already exist. Checking existing certificates..."
  CERT_ARN=$(aws acm list-certificates \
    --region "$REGION" \
    --profile "$AWS_PROFILE" \
    --query "CertificateSummaryList[?DomainName=='$DOMAIN_NAME'].CertificateArn" \
    --output text 2>&1)
fi

if [ -z "$CERT_ARN" ] || [ "$CERT_ARN" == "None" ]; then
  echo "❌ Failed to get certificate ARN"
  exit 1
fi

echo "✅ Certificate ARN: $CERT_ARN"
echo ""

# Get validation records
echo "📋 DNS Validation Records:"
echo "Add these CNAME records to your DNS provider:"
echo ""
aws acm describe-certificate \
  --certificate-arn "$CERT_ARN" \
  --region "$REGION" \
  --profile "$AWS_PROFILE" \
  --query 'Certificate.DomainValidationOptions[*].{Domain:DomainName,Name:ResourceRecord.Name,Value:ResourceRecord.Value,Type:ResourceRecord.Type}' \
  --output table 2>&1

echo ""
echo "⏳ Waiting for certificate validation..."
echo "This can take a few minutes after you add the DNS records."

# Update ingress
INGRESS_FILE="infrastructure/k8s/ingress/ingress.yaml"
if [ -f "$INGRESS_FILE" ]; then
  echo ""
  echo "📝 Updating ingress configuration..."
  
  # Update certificate ARN in ingress
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i.bak "s|alb.ingress.kubernetes.io/certificate-arn:.*|alb.ingress.kubernetes.io/certificate-arn: '$CERT_ARN'|g" "$INGRESS_FILE"
  else
    # Linux
    sed -i "s|alb.ingress.kubernetes.io/certificate-arn:.*|alb.ingress.kubernetes.io/certificate-arn: '$CERT_ARN'|g" "$INGRESS_FILE"
  fi
  
  echo "✅ Ingress updated with certificate ARN"
  echo ""
  echo "Next steps:"
  echo "1. Add the DNS validation records shown above to your DNS provider"
  echo "2. Wait for certificate validation (check with: aws acm describe-certificate --certificate-arn $CERT_ARN --region $REGION)"
  echo "3. Apply the ingress: kubectl apply -f $INGRESS_FILE"
  echo "4. Once validated, HTTPS will be enabled!"
else
  echo "⚠️  Ingress file not found at $INGRESS_FILE"
fi

echo ""
echo "✅ Setup complete! Certificate ARN saved."

