#!/bin/bash
# Quick script to activate the Whoosh AWS profile

export AWS_PROFILE=Whoosh
export AWS_ACCOUNT_ID=590544116310

echo "✅ AWS Profile 'Whoosh' activated"
echo "Account ID: ${AWS_ACCOUNT_ID}"
echo ""
echo "To use in this session, run:"
echo "  source ./scripts/use-whoosh-profile.sh"
echo ""
echo "Or manually:"
echo "  export AWS_PROFILE=Whoosh"

