output "workload_identity_arn" {
  description = "ARN of the Bedrock AgentCore Workload Identity"
  value       = aws_bedrockagentcore_workload_identity.agent_identity.arn
}

output "credential_provider_arn" {
  description = "ARN of the Bedrock AgentCore Credential Provider"
  value       = aws_bedrockagentcore_credential_provider.idc_provider.arn
}

output "tti_arn" {
  description = "ARN of the IAM Identity Center Trusted Token Issuer"
  value       = aws_identitystore_trusted_token_issuer.entra_tti.arn
}
