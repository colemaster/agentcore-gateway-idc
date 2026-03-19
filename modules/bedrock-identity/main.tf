# Bedrock Identity Module
# This module creates Bedrock AgentCore identity resources including:
# - IAM Identity Center Trusted Token Issuer for EntraID integration
# - Workload Identity for agent token exchange
# - Credential Provider for JIT credential generation

# IAM Identity Center Trusted Token Issuer
# Configures IAM Identity Center to trust EntraID OIDC tokens
# Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6
resource "aws_identitystore_trusted_token_issuer" "entra_tti" {
  instance_arn = var.idc_instance_arn
  name         = "EntraID-TTI-${var.workload_identity_name}"

  trusted_token_issuer_configuration {
    oidc_jwt_configuration {
      issuer_url                    = var.entra_oidc_issuer_url
      claim_attribute_path          = "sub"
      identity_store_attribute_path = "userName"
      jwks_retrieval_option         = "OPEN_ID_DISCOVERY"
    }
  }
}

# Bedrock AgentCore Workload Identity
# Creates a Workload Identity for agent token exchange
# Requirements: 4.1, 4.2, 4.3, 4.4, 4.5
resource "aws_bedrockagentcore_workload_identity" "agent_identity" {
  workload_identity_name = var.workload_identity_name

  lifecycle {
    postcondition {
      condition     = self.status == "ACTIVE"
      error_message = "Workload Identity must reach ACTIVE state after creation"
    }
  }
}

# Bedrock AgentCore Credential Provider
# Creates a Credential Provider linked to IAM Identity Center for JIT credential generation
# Requirements: 5.1, 5.2, 5.3, 5.4, 5.5
resource "aws_bedrockagentcore_credential_provider" "idc_provider" {
  credential_provider_name = var.credential_provider_name
  credential_provider_type = "IAM_IDENTITY_CENTER"

  iam_identity_center_configuration {
    instance_arn = var.idc_instance_arn
  }

  # Ensure the Trusted Token Issuer is created first
  depends_on = [aws_identitystore_trusted_token_issuer.entra_tti]

  lifecycle {
    # Validate that the IDC instance ARN is properly formatted
    precondition {
      condition     = can(regex("^arn:aws:sso:::instance/ssoins-[a-zA-Z0-9]+$", var.idc_instance_arn))
      error_message = "IAM Identity Center instance ARN must be in valid format"
    }
  }
}
