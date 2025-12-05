# Global Accelerator
resource "aws_globalaccelerator_accelerator" "whoosh" {
  name            = "${local.name}-accelerator"
  ip_address_type = "IPV4"
  enabled         = true

  tags = local.tags
}

resource "aws_globalaccelerator_listener" "whoosh" {
  accelerator_arn = aws_globalaccelerator_accelerator.whoosh.id
  protocol        = "TCP"

  port_range {
    from_port = 80
    to_port   = 80
  }

  port_range {
    from_port = 443
    to_port   = 443
  }
}

# Note: The ALB endpoint will be created by the AWS Load Balancer Controller
# This will be configured in the Kubernetes ingress resource
# The Global Accelerator endpoint group will need to be updated after ALB is created

# Output for ALB endpoint (to be used after ALB is created)
output "global_accelerator_ips" {
  description = "Global Accelerator static IP addresses"
  value       = aws_globalaccelerator_accelerator.whoosh.ip_sets[0].ip_addresses
}

