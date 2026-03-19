# Gateway Module
# This module creates the Bedrock AgentCore Gateway with JWT authentication,
# request interception via Lambda, and MCP server target routing.

# ── Bedrock AgentCore Gateway ────────────────────────────────────────────────
# Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7, 8.8, 18.4, 18.5, 23.1
resource "aws_bedrockagentcore_gateway" "main" {
  gateway_name = var.gateway_name

  # ── JWT-based authentication using EntraID OIDC ──
  # The Gateway acts as the zero-trust boundary. Before it even touches the
  # Lambda Interceptor, it mathematically validates the incoming JWT token 
  # against the EntraID OIDC discovery endpoint.
  # It specifically checks two cryptographic claims:
  # 1. 'issuer' ensures the token was minted by your specific Entra Tenant.
  # 2. 'audience' ensures the token was minted *for* this specific Gateway 
  #    (matching the frontend App Registration Client ID).
  inbound_authorizer {
    type = "CUSTOM_JWT"

    jwt_configuration {
      issuer   = var.entra_oidc_issuer_url
      audience = [var.entra_audience]
    }
  }

  # ── Lambda Interceptor Configuration ──
  # CRITICAL: `pass_request_headers` MUST be true.
  # By default, API Gateways strip authorization headers and custom elements 
  # for safety. Because our Lambda Interceptor fundamentally requires the 
  # Authorization Bearer (Workload Token), `x-target-account-id`, and 
  # `x-target-role-name` to programmatically execute the AWS IDC Credential
  # Exchange, this flag instructs the Gateway to forward the raw, intact 
  # HTTP Headers downstream to the Lambda payload.
  interceptor_configuration {
    interception_points  = ["REQUEST"]
    lambda_arn           = var.interceptor_lambda_arn
    pass_request_headers = true
  }

  lifecycle {
    postcondition {
      condition     = self.status == "ACTIVE"
      error_message = "Gateway must reach ACTIVE state after creation"
    }
  }
}

# ── Gateway Target Routing ───────────────────────────────────────────────────
# Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7, 22.1, 22.2, 22.3, 22.4
#
# Dynamically creates a target for each MCP server defined in var.mcp_targets.
# Each target routes requests from the Gateway to the specified MCP endpoint
# with the appropriate server type configuration.
resource "aws_bedrockagentcore_gateway_target" "mcp_targets" {
  for_each = { for target in var.mcp_targets : target.name => target }

  gateway_arn  = aws_bedrockagentcore_gateway.main.arn
  target_name  = each.value.name
  endpoint_url = each.value.endpoint

  mcp_configuration {
    server_type = each.value.type
  }

  lifecycle {
    postcondition {
      condition     = self.status == "ACTIVE"
      error_message = "Gateway target '${each.value.name}' must reach ACTIVE state"
    }
  }
}
