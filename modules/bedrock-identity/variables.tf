variable "workload_identity_name" {
  description = "Name of the Bedrock AgentCore Workload Identity"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9-_]+$", var.workload_identity_name))
    error_message = "Workload identity name must match pattern [a-zA-Z0-9-_]+"
  }

  validation {
    condition     = length(var.workload_identity_name) > 0
    error_message = "Workload identity name must be non-empty"
  }
}

variable "credential_provider_name" {
  description = "Name of the Bedrock AgentCore Credential Provider"
  type        = string

  validation {
    condition     = length(var.credential_provider_name) > 0
    error_message = "Credential provider name must be non-empty"
  }
}

variable "idc_instance_arn" {
  description = "ARN of the IAM Identity Center instance"
  type        = string

  validation {
    condition     = can(regex("^arn:aws:sso:::instance/ssoins-[a-zA-Z0-9]+$", var.idc_instance_arn))
    error_message = "IAM Identity Center instance ARN must be in valid ARN format"
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
