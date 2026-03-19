# Implementation Plan: Bedrock AgentCore Terraform Infrastructure

## Overview

This implementation plan creates a production-ready Terraform infrastructure for Amazon Bedrock AgentCore with Token Propagation and Just-in-Time (JIT) Credential Generation. The system enables secure, multi-account AWS resource access through a Gateway-Runtime architecture where EntraID JWT tokens are exchanged for AgentCore Workload Tokens, then transformed into temporary AWS SSO credentials via a Lambda Request Interceptor.

The implementation uses Python 3.12 for the Lambda interceptor and follows a modular Terraform structure with separate modules for IAM, Bedrock Identity, Lambda, and Gateway components.

## Tasks

- [x] 1. Set up Terraform project structure and configuration
  - Create root module directory structure with modules/ subdirectory
  - Create variables.tf with all required input variables (aws_region, aws_account_id, entra_tenant_id, entra_oidc_issuer_url, entra_audience, idc_instance_arn, workload_identity_name, credential_provider_name, gateway_name, interceptor_lambda_name, mcp_targets)
  - Create outputs.tf for infrastructure state outputs
  - Create main.tf for module orchestration
  - Create terraform.tfvars.example with sample values
  - Configure Terraform required_version >= 1.5.0 and required_providers (aws ~> 5.0, archive ~> 2.4)
  - _Requirements: 24.1, 25.1-25.7_

- [ ] 2. Implement IAM module for role creation
  - [x] 2.1 Create IAM module structure
    - Create modules/iam/main.tf, variables.tf, outputs.tf
    - Define input variables: workload_identity_name, interceptor_lambda_name, aws_region, aws_account_id
    - _Requirements: 24.2_
  
  - [x] 2.2 Implement Runtime execution role
    - Create aws_iam_role resource with name "${var.workload_identity_name}-runtime-role"
    - Configure trust policy allowing bedrock-agentcore.amazonaws.com service principal
    - Add inline policy "TokenExchangePolicy" granting bedrock-agentcore:GetWorkloadAccessTokenForJwt permission
    - Restrict resource to specific Workload Identity ARN pattern
    - Add condition requiring workload name match using StringEquals
    - Output runtime_role_arn
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_
  
  - [x] 2.3 Implement Interceptor execution role
    - Create aws_iam_role resource with name "${var.interceptor_lambda_name}-role"
    - Configure trust policy allowing lambda.amazonaws.com service principal
    - Add inline policy "CredentialGenerationPolicy" granting bedrock-agentcore:GetResourceCredentials permission
    - Attach AWS managed policy AWSLambdaBasicExecutionRole
    - Output interceptor_role_arn
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_
  
  - [x] 2.4 Write validation tests for IAM roles
    - Test trust policy correctness for both roles
    - Test inline policy permissions and conditions
    - Test managed policy attachments
    - _Requirements: 2.2, 2.3, 3.2, 3.3_

- [ ] 3. Implement Bedrock Identity module
  - [x] 3.1 Create Bedrock Identity module structure
    - Create modules/bedrock-identity/main.tf, variables.tf, outputs.tf
    - Define input variables: workload_identity_name, credential_provider_name, idc_instance_arn
    - _Requirements: 24.3_
  
  - [x] 3.2 Implement IAM Identity Center Trusted Token Issuer
    - Create aws_identitystore_trusted_token_issuer resource
    - Configure with EntraID OIDC discovery endpoint
    - Set claim_attribute_path to "sub" and identity_store_attribute_path to "userName"
    - Set jwks_retrieval_option to "OPEN_ID_DISCOVERY"
    - Add validation for HTTPS URL format
    - Output tti_arn
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6_
  
  - [x] 3.3 Implement Workload Identity resource
    - Create aws_bedrockagentcore_workload_identity resource
    - Set workload_identity_name from variable
    - Add validation for name pattern [a-zA-Z0-9-_]+
    - Verify resource reaches ACTIVE state
    - Output workload_identity_arn
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_
  
  - [x] 3.4 Implement Credential Provider resource
    - Create aws_bedrockagentcore_credential_provider resource
    - Set credential_provider_type to "IAM_IDENTITY_CENTER"
    - Configure iam_identity_center_configuration with instance_arn
    - Add validation that IDC instance exists
    - Output credential_provider_arn
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_
  
  - [ ] 3.5 Write validation tests for Bedrock Identity resources
    - Test Workload Identity creation and ACTIVE state
    - Test Credential Provider configuration and IDC linkage
    - Test TTI configuration with EntraID
    - _Requirements: 4.3, 5.4, 1.4_

- [~] 4. Checkpoint - Verify IAM and Identity resources
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 5. Implement Lambda Interceptor module
  - [~] 5.1 Create Lambda module structure
    - Create modules/lambda/main.tf, variables.tf, outputs.tf
    - Create modules/lambda/src/ directory for Python code
    - Define input variables: function_name, execution_role_arn, credential_provider_name, aws_region, aws_account_id
    - _Requirements: 24.4_
  
  - [~] 5.2 Implement Lambda interceptor Python code
    - Create modules/lambda/src/interceptor.py with lambda_handler function
    - Implement extractBearerToken() to extract Workload Token from authorization header
    - Implement header extraction for x-target-account-id and x-target-role-name
    - Add validation for required headers (authorization, x-target-account-id, x-target-role-name)
    - Create boto3 client for bedrock-agentcore service
    - Implement GetResourceCredentials API call with workloadIdentityToken, credentialProviderName, targetAccountId, targetRoleName
    - Validate received credentials (accessKeyId, secretAccessKey, sessionToken all non-null)
    - Build transformed request headers with x-aws-access-key-id, x-aws-secret-access-key, x-aws-session-token
    - Return interceptor response with interceptorOutputVersion "1.0" and transformed headers
    - Preserve original request body in response
    - Add error handling with descriptive messages
    - Ensure no logging of sensitive credential values
    - _Requirements: 6.1, 6.2, 10.5, 11.1, 11.2, 11.3, 11.4, 11.5, 11.6, 12.1, 12.2, 12.3, 12.4, 12.5, 12.6, 12.7, 23.2, 23.3, 23.4_
  
  - [~] 5.3 Implement Lambda deployment resources
    - Create data.archive_file resource to package interceptor.py into zip
    - Create aws_lambda_function resource with Python 3.12 runtime
    - Set handler to "interceptor.lambda_handler"
    - Configure timeout to 30 seconds and memory_size to 256 MB
    - Attach execution_role_arn from IAM module
    - Set environment variables for AWS_REGION and CREDENTIAL_PROVIDER_NAME
    - Verify Lambda reaches Active state
    - Output lambda_arn and lambda_function_name
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7_
  
  - [~] 5.4 Add Lambda invocation permissions
    - Create aws_lambda_permission resource with statement_id "AllowBedrockGatewayInvoke"
    - Grant lambda:InvokeFunction action
    - Set principal to bedrock-agentcore.amazonaws.com
    - Restrict to specific AWS account using source_account
    - _Requirements: 7.1, 7.2, 7.3, 7.4_
  
  - [~] 5.5 Write unit tests for Lambda interceptor
    - Test extractBearerToken() with valid and invalid tokens
    - Test header extraction logic
    - Test credential validation logic
    - Test error handling for missing headers
    - Test error handling for GetResourceCredentials failures
    - _Requirements: 11.1, 11.2, 11.6, 20.5_

- [ ] 6. Implement Gateway module
  - [~] 6.1 Create Gateway module structure
    - Create modules/gateway/main.tf, variables.tf, outputs.tf
    - Define input variables: gateway_name, entra_oidc_issuer_url, entra_audience, interceptor_lambda_arn, mcp_targets
    - _Requirements: 24.5_
  
  - [~] 6.2 Implement Gateway resource with JWT authorizer
    - Create aws_bedrockagentcore_gateway resource
    - Configure inbound_authorizer with type "CUSTOM_JWT"
    - Set jwt_configuration issuer to entra_oidc_issuer_url
    - Set jwt_configuration audience to [entra_audience]
    - Add validation for HTTPS URL format
    - Verify Gateway reaches ACTIVE state
    - Output gateway_arn
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.8, 18.4, 18.5_
  
  - [~] 6.3 Configure Gateway interceptor
    - Add interceptor_configuration block to Gateway resource
    - Set interception_points to ["REQUEST"]
    - Set lambda_arn to interceptor_lambda_arn from Lambda module
    - Set pass_request_headers to true (CRITICAL)
    - Add depends_on for Lambda permission resource
    - _Requirements: 8.5, 8.6, 8.7, 23.1_
  
  - [~] 6.4 Implement Gateway target routing for MCP servers
    - Create aws_bedrockagentcore_gateway_target resource for IAM MCP server
    - Set target_name to "iam-mcp-server"
    - Configure endpoint_url from mcp_targets variable
    - Add mcp_configuration with server_type "IAM_MCP"
    - Validate endpoint URL is HTTPS
    - Create aws_bedrockagentcore_gateway_target resource for AWS API MCP server
    - Set target_name to "aws-api-mcp-server"
    - Configure endpoint_url from mcp_targets variable
    - Add mcp_configuration with server_type "AWS_API_MCP"
    - Verify all targets reach ACTIVE state
    - Output gateway_endpoint_url
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7, 22.1, 22.2, 22.3, 22.4_
  
  - [~] 6.5 Write validation tests for Gateway configuration
    - Test JWT authorizer configuration
    - Test interceptor configuration with passRequestHeaders
    - Test target routing configuration
    - Test HTTPS URL validation
    - _Requirements: 8.2, 8.3, 8.4, 8.6, 9.4_

- [~] 7. Checkpoint - Verify Lambda and Gateway integration
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 8. Implement root module orchestration
  - [~] 8.1 Wire IAM module
    - Add module "iam_roles" block in root main.tf
    - Pass workload_identity_name, interceptor_lambda_name, aws_region, aws_account_id variables
    - _Requirements: 24.1, 24.6_
  
  - [~] 8.2 Wire Bedrock Identity module
    - Add module "bedrock_identity" block in root main.tf
    - Pass workload_identity_name, credential_provider_name, idc_instance_arn variables
    - _Requirements: 24.1, 24.6_
  
  - [~] 8.3 Wire Lambda module with dependencies
    - Add module "lambda_interceptor" block in root main.tf
    - Pass function_name, credential_provider_name, aws_region, aws_account_id variables
    - Pass execution_role_arn from iam_roles module output
    - Add depends_on for bedrock_identity module (Credential Provider must exist)
    - _Requirements: 17.4, 24.1, 24.6_
  
  - [~] 8.4 Wire Gateway module with dependencies
    - Add module "gateway" block in root main.tf
    - Pass gateway_name, entra_oidc_issuer_url, entra_audience, mcp_targets variables
    - Pass interceptor_lambda_arn from lambda_interceptor module output
    - Add depends_on for lambda_interceptor module
    - _Requirements: 17.2, 17.3, 24.1, 24.6_
  
  - [~] 8.5 Configure root module outputs
    - Output runtime_role_arn from iam_roles module
    - Output interceptor_role_arn from iam_roles module
    - Output workload_identity_arn from bedrock_identity module
    - Output credential_provider_arn from bedrock_identity module
    - Output lambda_arn from lambda_interceptor module
    - Output gateway_arn from gateway module
    - Output gateway_endpoint_url from gateway module
    - Create infrastructure_state output object with all ARNs
    - _Requirements: 15.2, 15.3, 15.4, 15.5, 15.6, 15.7, 15.8, 25.1, 25.2, 25.3, 25.4, 25.5, 25.6, 25.7_

- [ ] 9. Implement configuration validation
  - [~] 9.1 Add input variable validation rules
    - Add validation for aws_account_id matching pattern ^[0-9]{12}$
    - Add validation for aws_region in list of supported regions
    - Add validation for entra_oidc_issuer_url as valid HTTPS URL
    - Add validation for idc_instance_arn in valid ARN format
    - Add validation for workload_identity_name non-empty
    - Add validation for credential_provider_name non-empty
    - Add validation for gateway_name non-empty
    - _Requirements: 21.1, 21.2, 21.3, 21.4, 21.5, 21.6, 21.7_
  
  - [~] 9.2 Add ARN format validation functions
    - Create local variable for ARN regex pattern
    - Add validation that all resource ARNs match AWS ARN format
    - Add validation that account ID in ARNs matches aws_account_id variable
    - Add validation that region in ARNs matches aws_region variable
    - _Requirements: 14.1, 14.2, 14.3, 14.4_
  
  - [~] 9.3 Write validation tests for configuration
    - Test account ID validation with valid and invalid formats
    - Test region validation with supported and unsupported regions
    - Test URL validation with HTTP and HTTPS URLs
    - Test ARN format validation
    - _Requirements: 21.1, 21.2, 21.3, 21.4_

- [ ] 10. Implement end-to-end infrastructure validation
  - [~] 10.1 Create validation script
    - Create scripts/validate_infrastructure.py
    - Implement checks for IAM role existence and trust policies
    - Implement checks for Workload Identity ACTIVE state
    - Implement checks for Credential Provider IDC linkage
    - Implement checks for Lambda function Active state
    - Implement checks for Gateway ACTIVE state
    - Implement checks for Gateway targets ACTIVE state
    - Report specific failures with descriptive messages
    - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5, 13.6, 13.7, 13.8_
  
  - [~] 10.2 Write integration tests for validation script
    - Test validation with all resources in correct state
    - Test validation with missing resources
    - Test validation with resources in incorrect state
    - _Requirements: 13.1, 13.8_

- [ ] 11. Create documentation and examples
  - [~] 11.1 Create README.md
    - Document prerequisites (AWS credentials, IAM Identity Center setup, EntraID configuration)
    - Document module structure and purpose
    - Document input variables with descriptions and examples
    - Document output values with descriptions
    - Add deployment instructions (terraform init, plan, apply)
    - Add validation instructions
    - Add troubleshooting section for common errors
    - _Requirements: 20.1, 20.2, 20.3, 20.4_
  
  - [~] 11.2 Create example configuration
    - Create examples/basic/main.tf with complete working example
    - Create examples/basic/terraform.tfvars with sample values
    - Include comments explaining each configuration option
    - Document MCP server endpoint configuration
    - _Requirements: 22.4_
  
  - [~] 11.3 Create architecture diagram
    - Document token exchange flow (EntraID JWT → Workload Token → AWS Credentials)
    - Document Gateway request flow with interceptor
    - Document MCP server routing
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_

- [~] 12. Checkpoint - Final validation and documentation review
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- The Lambda interceptor uses Python 3.12 as selected by the user
- CRITICAL: Gateway interceptor_configuration MUST have passRequestHeaders: true
- CRITICAL: Lambda must extract x-target-account-id and x-target-role-name headers
- CRITICAL: Credential Provider must use IAM_IDENTITY_CENTER type
- All code examples in tasks use Python for Lambda implementation
- Terraform modules follow best practices with separate variables, outputs, and main files
- Resource dependencies are explicitly managed through depends_on and module outputs
