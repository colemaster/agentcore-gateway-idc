# Bedrock Identity Module

This module creates Bedrock AgentCore identity resources including IAM Identity Center Trusted Token Issuer, Workload Identity, and Credential Provider.

## Resources Created

- IAM Identity Center Trusted Token Issuer (for EntraID OIDC integration)
- Bedrock AgentCore Workload Identity
- Bedrock AgentCore Credential Provider (IAM Identity Center type)

## Inputs

- `workload_identity_name` - Name for the Workload Identity
- `credential_provider_name` - Name for the Credential Provider
- `idc_instance_arn` - ARN of the IAM Identity Center instance
- `entra_oidc_issuer_url` - Microsoft Entra ID OIDC discovery endpoint URL

## Outputs

- `tti_arn` - ARN of the IAM Identity Center Trusted Token Issuer
- `workload_identity_arn` - ARN of the Workload Identity
- `credential_provider_arn` - ARN of the Credential Provider
