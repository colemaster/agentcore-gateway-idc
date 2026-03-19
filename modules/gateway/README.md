# Gateway Module

This module creates the Bedrock AgentCore Gateway with JWT authentication and request interception.

## Resources Created

- Bedrock AgentCore Gateway with CUSTOM_JWT authorizer
- Gateway interceptor configuration
- Gateway target routing rules for MCP servers

## Inputs

- `gateway_name` - Name of the Gateway
- `entra_oidc_issuer_url` - Entra ID OIDC discovery URL
- `entra_audience` - Expected JWT audience
- `interceptor_lambda_arn` - ARN of the interceptor Lambda function
- `mcp_targets` - List of MCP server targets

## Outputs

- `gateway_arn` - ARN of the Gateway
- `gateway_endpoint_url` - Gateway endpoint URL
