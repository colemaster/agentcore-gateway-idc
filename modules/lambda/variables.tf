variable "function_name" {
  description = "Name of the Lambda interceptor function"
  type        = string

  validation {
    condition     = length(var.function_name) > 0
    error_message = "Function name must be non-empty"
  }
}

variable "execution_role_arn" {
  description = "ARN of the IAM execution role for the Lambda function"
  type        = string

  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:role/", var.execution_role_arn))
    error_message = "Execution role ARN must be a valid IAM role ARN"
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

variable "aws_region" {
  description = "AWS region where the Lambda function will be deployed"
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1}$", var.aws_region))
    error_message = "AWS region must be in valid format (e.g., us-east-1)"
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
