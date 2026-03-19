# Example: Basic Bedrock AgentCore Terraform Deployment
#
# This example demonstrates a complete deployment of the AgentCore infrastructure
# with Token Propagation and JIT Credential Generation.
#
# Prerequisites:
#   - AWS CLI configured with appropriate credentials
#   - IAM Identity Center instance configured
#   - Microsoft Entra ID tenant with OIDC configured
#   - Terraform >= 1.5.0

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Use the root module as the source
module "agentcore" {
  source = "../../"

  # AWS Configuration
  aws_region     = var.aws_region
  aws_account_id = var.aws_account_id

  # Microsoft Entra ID Configuration
  # The OIDC issuer URL is constructed from your Entra tenant ID
  entra_tenant_id       = var.entra_tenant_id
  entra_oidc_issuer_url = "https://login.microsoftonline.com/${var.entra_tenant_id}/v2.0"
  entra_audience        = var.entra_audience

  # IAM Identity Center — must be pre-configured in your account
  idc_instance_arn = var.idc_instance_arn

  # Bedrock AgentCore identifiers
  workload_identity_name   = var.workload_identity_name
  credential_provider_name = var.credential_provider_name
  gateway_name             = var.gateway_name
  interceptor_lambda_name  = var.interceptor_lambda_name

  # MCP server targets — at least two are required
  mcp_targets = var.mcp_targets
}

# ── Variables ────────────────────────────────────────────────────────────────

variable "aws_region" {
  default = "us-east-1"
}

variable "aws_account_id" {
  description = "Your 12-digit AWS account ID"
  type        = string
}

variable "entra_tenant_id" {
  description = "Microsoft Entra ID tenant UUID"
  type        = string
}

variable "entra_audience" {
  default = "api://bedrock-agentcore-gateway"
}

variable "idc_instance_arn" {
  description = "ARN of your IAM Identity Center instance"
  type        = string
}

variable "workload_identity_name" {
  default = "my-strands-agent"
}

variable "credential_provider_name" {
  default = "aws-idc-provider"
}

variable "gateway_name" {
  default = "agentcore-gateway"
}

variable "interceptor_lambda_name" {
  default = "agentcore-interceptor"
}

variable "mcp_targets" {
  default = [
    {
      name     = "iam-mcp-server"
      endpoint = "https://internal-iam-mcp.example.com/mcp"
      type     = "IAM_MCP"
    },
    {
      name     = "aws-api-mcp-server"
      endpoint = "https://internal-aws-api-mcp.example.com/mcp"
      type     = "AWS_API_MCP"
    },
    {
      name     = "aws-knowledge-mcp-server"
      endpoint = "https://internal-aws-knowledge-mcp.example.com/mcp"
      type     = "AWS_KNOWLEDGE_MCP"
    }
  ]
}

# ── Outputs ──────────────────────────────────────────────────────────────────

output "gateway_endpoint_url" {
  description = "Use this URL to send requests to the AgentCore Gateway"
  value       = module.agentcore.gateway_endpoint_url
}

output "runtime_role_arn" {
  description = "ARN of the Runtime execution role — configure your agent with this"
  value       = module.agentcore.runtime_execution_role_arn
}

output "workload_identity_arn" {
  description = "ARN of the Workload Identity"
  value       = module.agentcore.workload_identity_arn
}

output "infrastructure_state" {
  description = "Complete set of provisioned resource ARNs"
  value       = module.agentcore.infrastructure_state
}
