variable "gateway_name" {
  description = "Name of the Bedrock AgentCore Gateway"
  type        = string

  validation {
    condition     = length(var.gateway_name) > 0
    error_message = "Gateway name must be non-empty"
  }
}

variable "entra_oidc_issuer_url" {
  description = "Microsoft Entra ID OIDC discovery endpoint URL"
  type        = string

  validation {
    condition     = can(regex("^https://", var.entra_oidc_issuer_url))
    error_message = "Entra ID OIDC issuer URL must be a valid HTTPS URL"
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

variable "interceptor_lambda_arn" {
  description = "ARN of the Lambda interceptor function"
  type        = string

  validation {
    condition     = can(regex("^arn:aws:lambda:", var.interceptor_lambda_arn))
    error_message = "Interceptor Lambda ARN must be a valid Lambda function ARN"
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
