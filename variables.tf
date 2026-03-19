variable "aws_region" {
  description = "AWS region where resources will be deployed"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1}$", var.aws_region))
    error_message = "AWS region must be in valid format (e.g., us-east-1, eu-west-1)"
  }
}

variable "aws_account_id" {
  description = "AWS account ID where resources will be deployed"
  type        = string
  
  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "AWS account ID must be a 12-digit number"
  }
}

variable "entra_tenant_id" {
  description = "Microsoft Entra ID tenant ID for OIDC authentication"
  type        = string
  
  validation {
    condition     = can(regex("^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$", var.entra_tenant_id))
    error_message = "Entra tenant ID must be a valid UUID"
  }
}

variable "entra_oidc_issuer_url" {
  description = "Microsoft Entra ID OIDC discovery endpoint URL"
  type        = string
  
  validation {
    condition     = can(regex("^https://", var.entra_oidc_issuer_url))
    error_message = "Entra OIDC issuer URL must be a valid HTTPS URL"
  }
}

variable "entra_audience" {
  description = "Expected audience value in Entra ID JWT tokens"
  type        = string
  
  validation {
    condition     = length(var.entra_audience) > 0
    error_message = "Entra audience must be non-empty"
  }
}

variable "idc_instance_arn" {
  description = "ARN of the AWS IAM Identity Center instance"
  type        = string
  
  validation {
    condition     = can(regex("^arn:aws:sso:::instance/ssoins-[a-f0-9]+$", var.idc_instance_arn))
    error_message = "IDC instance ARN must be in valid format"
  }
}

variable "workload_identity_name" {
  description = "Name for the Bedrock AgentCore Workload Identity"
  type        = string
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9-_]+$", var.workload_identity_name)) && length(var.workload_identity_name) > 0
    error_message = "Workload identity name must be non-empty and contain only alphanumeric characters, hyphens, and underscores"
  }
}

variable "credential_provider_name" {
  description = "Name for the Bedrock AgentCore Credential Provider"
  type        = string
  
  validation {
    condition     = length(var.credential_provider_name) > 0
    error_message = "Credential provider name must be non-empty"
  }
}

variable "gateway_name" {
  description = "Name for the Bedrock AgentCore Gateway"
  type        = string
  
  validation {
    condition     = length(var.gateway_name) > 0
    error_message = "Gateway name must be non-empty"
  }
}

variable "interceptor_lambda_name" {
  description = "Name for the Lambda interceptor function"
  type        = string
  
  validation {
    condition     = length(var.interceptor_lambda_name) > 0
    error_message = "Interceptor Lambda name must be non-empty"
  }
}

variable "mcp_targets" {
  description = "List of MCP server targets for Gateway routing"
  type = list(object({
    name     = string
    endpoint = string
    type     = string
  }))
  
  validation {
    condition     = length(var.mcp_targets) >= 2
    error_message = "At least two MCP targets must be configured"
  }
  
  validation {
    condition     = alltrue([for target in var.mcp_targets : can(regex("^https://", target.endpoint))])
    error_message = "All MCP target endpoints must be HTTPS URLs"
  }
}
