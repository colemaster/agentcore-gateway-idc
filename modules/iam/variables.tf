variable "workload_identity_name" {
  description = "Name of the Bedrock AgentCore Workload Identity"
  type        = string

  validation {
    condition     = length(var.workload_identity_name) > 0
    error_message = "Workload identity name must be non-empty"
  }

  validation {
    condition     = can(regex("^[a-zA-Z0-9-_]+$", var.workload_identity_name))
    error_message = "Workload identity name must match pattern [a-zA-Z0-9-_]+"
  }
}

variable "interceptor_lambda_name" {
  description = "Name of the Lambda interceptor function"
  type        = string

  validation {
    condition     = length(var.interceptor_lambda_name) > 0
    error_message = "Interceptor Lambda name must be non-empty"
  }
}

variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string

  validation {
    condition     = length(var.aws_region) > 0
    error_message = "AWS region must be non-empty"
  }
}

variable "aws_account_id" {
  description = "AWS account ID (12-digit number)"
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "AWS account ID must be a 12-digit number"
  }
}
