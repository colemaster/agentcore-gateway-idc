# Lambda Interceptor Module
# This module deploys the Lambda function that intercepts Bedrock AgentCore
# Gateway requests and injects temporary AWS credentials obtained via
# JIT credential generation through IAM Identity Center.

# ── Package Lambda source code ───────────────────────────────────────────────
data "archive_file" "interceptor_zip" {
  type        = "zip"
  source_file = "${path.module}/src/interceptor.py"
  output_path = "${path.module}/dist/interceptor.zip"
}

# ── Lambda Function ──────────────────────────────────────────────────────────
# Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7
resource "aws_lambda_function" "interceptor" {
  filename         = data.archive_file.interceptor_zip.output_path
  function_name    = var.function_name
  role             = var.execution_role_arn
  handler          = "interceptor.lambda_handler"
  source_code_hash = data.archive_file.interceptor_zip.output_base64sha256
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      CREDENTIAL_PROVIDER_NAME = var.credential_provider_name
    }
  }

  lifecycle {
    postcondition {
      condition     = self.qualified_arn != ""
      error_message = "Lambda function must be successfully created"
    }
  }
}

# ── Lambda Permission — Allow Gateway invocation ─────────────────────────────
# Requirements: 7.1, 7.2, 7.3, 7.4
resource "aws_lambda_permission" "allow_gateway_invoke" {
  statement_id   = "AllowBedrockGatewayInvoke"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.interceptor.function_name
  principal      = "bedrock-agentcore.amazonaws.com"
  source_account = var.aws_account_id
}
