# Runtime Execution Role
# This role is assumed by the Bedrock AgentCore Runtime to exchange EntraID JWT tokens
# for Workload Tokens
resource "aws_iam_role" "runtime_execution_role" {
  name = "${var.workload_identity_name}-runtime-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "bedrock-agentcore.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  inline_policy {
    name = "TokenExchangePolicy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect   = "Allow"
        Action   = "bedrock-agentcore:GetWorkloadAccessTokenForJwt"
        Resource = "arn:aws:bedrock-agentcore:${var.aws_region}:${var.aws_account_id}:workload-identity/${var.workload_identity_name}"
        Condition = {
          StringEquals = {
            "bedrock-agentcore:WorkloadName" = var.workload_identity_name
          }
        }
      }]
    })
  }

  tags = {
    Name      = "${var.workload_identity_name}-runtime-role"
    ManagedBy = "Terraform"
    Component = "BedrockAgentCore"
    Purpose   = "RuntimeExecution"
  }
}

# Interceptor Execution Role
# This role is assumed by the Lambda function that intercepts Gateway requests
# and injects temporary AWS credentials
resource "aws_iam_role" "interceptor_execution_role" {
  name = "${var.interceptor_lambda_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  inline_policy {
    name = "CredentialGenerationPolicy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect   = "Allow"
        Action   = "bedrock-agentcore:GetResourceCredentials"
        Resource = "*"
      }]
    })
  }

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  ]

  tags = {
    Name      = "${var.interceptor_lambda_name}-role"
    ManagedBy = "Terraform"
    Component = "BedrockAgentCore"
    Purpose   = "InterceptorExecution"
  }
}
