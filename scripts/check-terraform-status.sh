#!/bin/bash
# Script to check Terraform apply status

cd "$(dirname "$0")/../infrastructure/terraform" || exit 1

if [ -f terraform-apply.log ]; then
    echo "📊 Terraform Apply Status"
    echo "========================"
    echo ""
    
    # Count resources being created
    CREATING=$(grep -c "Creating..." terraform-apply.log 2>/dev/null || echo "0")
    CREATED=$(grep -c "Creation complete" terraform-apply.log 2>/dev/null || echo "0")
    ERRORS=$(grep -c "Error:" terraform-apply.log 2>/dev/null || echo "0")
    
    echo "Resources creating: $CREATING"
    echo "Resources created: $CREATED"
    echo "Errors: $ERRORS"
    echo ""
    
    if [ "$ERRORS" -gt 0 ]; then
        echo "❌ Errors found! Last few errors:"
        grep "Error:" terraform-apply.log | tail -5
    else
        echo "✅ No errors so far"
    fi
    
    echo ""
    echo "Recent activity:"
    tail -10 terraform-apply.log | grep -E "(Creating|Creation complete|module|Apply)" | tail -5
    
    # Check if still running
    if pgrep -f "terraform apply" > /dev/null; then
        echo ""
        echo "🔄 Terraform is still running..."
    else
        echo ""
        echo "✅ Terraform apply completed!"
        echo ""
        echo "Check the full log:"
        echo "  tail -f infrastructure/terraform/terraform-apply.log"
    fi
else
    echo "No terraform-apply.log found. Terraform may not be running."
fi

