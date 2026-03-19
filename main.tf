terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.37.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # Global Default Tags mapping
  # All bedrock-agentcore resources will inherit these automatically.
  default_tags {
    tags = {
      ManagedBy = "Terraform"
      Component = "BedrockAgentCore"
    }
  }
}

# Phase 1: IAM Roles
module "iam_roles" {
  source = "./modules/iam"

  workload_identity_name  = var.workload_identity_name
  interceptor_lambda_name = var.interceptor_lambda_name
  aws_region              = var.aws_region
  aws_account_id          = var.aws_account_id
}

# Phase 2: Bedrock Identity
module "bedrock_identity" {
  source = "./modules/bedrock-identity"

  workload_identity_name   = var.workload_identity_name
  credential_provider_name = var.credential_provider_name
  idc_instance_arn         = var.idc_instance_arn
  entra_oidc_issuer_url    = var.entra_oidc_issuer_url

  gitlab_client_id       = var.gitlab_client_id
  gitlab_connection_name = var.gitlab_connection_name
}

# Phase 3: Lambda Interceptor
module "lambda_interceptor" {
  source = "./modules/lambda"

  function_name            = var.interceptor_lambda_name
  execution_role_arn       = module.iam_roles.interceptor_role_arn
  credential_provider_name = var.credential_provider_name
  aws_region               = var.aws_region
  aws_account_id           = var.aws_account_id

  depends_on = [
    module.iam_roles,
    module.bedrock_identity
  ]
}

# Phase 4: Gateway
module "gateway" {
  source = "./modules/gateway"

  gateway_name           = var.gateway_name
  entra_oidc_issuer_url  = var.entra_oidc_issuer_url
  entra_audience         = var.entra_audience
  interceptor_lambda_arn = module.lambda_interceptor.lambda_arn
  mcp_targets            = var.mcp_targets

  depends_on = [
    module.lambda_interceptor
  ]
}
