output "runtime_execution_role_arn" {
  description = "ARN of the IAM role for Runtime execution"
  value       = module.iam_roles.runtime_role_arn
}

output "interceptor_execution_role_arn" {
  description = "ARN of the IAM role for Interceptor Lambda execution"
  value       = module.iam_roles.interceptor_role_arn
}

output "tti_arn" {
  description = "ARN of the IAM Identity Center Trusted Token Issuer"
  value       = module.bedrock_identity.tti_arn
}

output "workload_identity_arn" {
  description = "ARN of the Bedrock AgentCore Workload Identity"
  value       = module.bedrock_identity.workload_identity_arn
}

output "credential_provider_arn" {
  description = "ARN of the Bedrock AgentCore Credential Provider"
  value       = module.bedrock_identity.credential_provider_arn
}

output "gitlab_credential_provider_id" {
  description = "The logical ID/Name of the GitLab Outbound Connection"
  value       = module.bedrock_identity.gitlab_credential_provider_id
}

output "lambda_function_arn" {
  description = "ARN of the Lambda interceptor function"
  value       = module.lambda_interceptor.lambda_arn
}

output "gateway_arn" {
  description = "ARN of the Bedrock AgentCore Gateway"
  value       = module.gateway.gateway_arn
}

output "gateway_endpoint_url" {
  description = "Endpoint URL of the Bedrock AgentCore Gateway"
  value       = module.gateway.gateway_endpoint_url
}

output "infrastructure_state" {
  description = "Complete infrastructure state with all resource ARNs"
  value = {
    runtime_role_arn           = module.iam_roles.runtime_role_arn
    interceptor_role_arn       = module.iam_roles.interceptor_role_arn
    tti_arn                    = module.bedrock_identity.tti_arn
    workload_identity_arn      = module.bedrock_identity.workload_identity_arn
    credential_provider_arn    = module.bedrock_identity.credential_provider_arn
    lambda_arn                 = module.lambda_interceptor.lambda_arn
    gateway_arn                = module.gateway.gateway_arn
    gateway_endpoint_url       = module.gateway.gateway_endpoint_url
    gitlab_credential_provider = module.bedrock_identity.gitlab_credential_provider_id
  }
}
