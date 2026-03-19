# Requirements Document: Bedrock AgentCore Terraform Infrastructure

## Introduction

This document specifies the functional and non-functional requirements for a production-ready Terraform infrastructure that deploys Amazon Bedrock AgentCore with Token Propagation and Just-in-Time (JIT) Credential Generation. The system enables secure, multi-account AWS resource access through a Gateway-Runtime architecture where EntraID JWT tokens are exchanged for AgentCore Workload Tokens, then transformed into temporary AWS SSO credentials via a Lambda Request Interceptor.

## Glossary

- **Runtime**: The Bedrock AgentCore Runtime component that exchanges EntraID JWT tokens for Workload Tokens
- **Gateway**: The Bedrock AgentCore Gateway component that validates JWT tokens and routes requests to MCP servers
- **Interceptor**: The AWS Lambda function that intercepts Gateway requests and injects temporary AWS credentials
- **IDC**: AWS IAM Identity Center service that provides SSO and credential generation capabilities
- **TTI**: Trusted Token Issuer configured in IAM Identity Center to trust EntraID OIDC tokens
- **Workload_Identity**: Bedrock AgentCore identity resource representing the agent workload
- **Credential_Provider**: Bedrock AgentCore resource that generates temporary credentials via IAM Identity Center
- **MCP_Server**: Model Context Protocol server that provides IAM or AWS API capabilities
- **EntraID**: Microsoft Entra ID (formerly Azure AD) identity provider
- **JIT_Credentials**: Just-in-Time temporary AWS credentials generated on-demand
- **Workload_Token**: AgentCore-issued token obtained by exchanging an EntraID JWT
- **Infrastructure_State**: The complete set of provisioned AWS resources and their configuration

## Requirements

### Requirement 1: IAM Identity Center Integration

**User Story:** As an infrastructure operator, I want to configure IAM Identity Center to trust EntraID tokens, so that users can authenticate with their corporate identities and receive AWS credentials.

#### Acceptance Criteria

1. WHEN the infrastructure is provisioned THEN the System SHALL create a Trusted Token Issuer in IAM Identity Center
2. WHEN creating the TTI THEN the System SHALL configure it with the EntraID OIDC discovery endpoint
3. WHEN the TTI is created THEN the System SHALL associate it with the specified IAM Identity Center instance
4. WHEN the TTI configuration is complete THEN the System SHALL verify the TTI status is ACTIVE
5. THE System SHALL validate that the EntraID OIDC issuer URL is a valid HTTPS endpoint
6. THE System SHALL validate that the IAM Identity Center instance ARN is in valid ARN format

### Requirement 2: Runtime Execution Role

**User Story:** As a security administrator, I want the Runtime to have minimal IAM permissions, so that the system follows the principle of least privilege.

#### Acceptance Criteria

1. WHEN the infrastructure is provisioned THEN the System SHALL create an IAM role for Runtime execution
2. THE Runtime_Execution_Role SHALL have a trust policy allowing the bedrock-agentcore.amazonaws.com service principal
3. THE Runtime_Execution_Role SHALL have an inline policy granting bedrock-agentcore:GetWorkloadAccessTokenForJwt permission
4. WHEN granting GetWorkloadAccessTokenForJwt permission THEN the System SHALL restrict the resource to the specific Workload Identity ARN
5. WHEN granting GetWorkloadAccessTokenForJwt permission THEN the System SHALL add a condition requiring the workload name to match
6. THE Runtime_Execution_Role SHALL NOT have wildcard resource permissions without strict conditions

### Requirement 3: Interceptor Execution Role

**User Story:** As a security administrator, I want the Lambda Interceptor to have only the permissions needed for credential generation, so that the attack surface is minimized.

#### Acceptance Criteria

1. WHEN the infrastructure is provisioned THEN the System SHALL create an IAM role for Interceptor execution
2. THE Interceptor_Execution_Role SHALL have a trust policy allowing the lambda.amazonaws.com service principal
3. THE Interceptor_Execution_Role SHALL have an inline policy granting bedrock-agentcore:GetResourceCredentials permission
4. THE Interceptor_Execution_Role SHALL have the AWSLambdaBasicExecutionRole managed policy attached
5. THE Interceptor_Execution_Role SHALL NOT have administrator access or overly permissive policies

### Requirement 4: Workload Identity Management

**User Story:** As an infrastructure operator, I want to create a Workload Identity for my agent, so that it can exchange EntraID tokens for Workload Tokens.

#### Acceptance Criteria

1. WHEN the infrastructure is provisioned THEN the System SHALL create a Bedrock AgentCore Workload Identity
2. THE Workload_Identity SHALL have a unique name within the AWS account and region
3. WHEN the Workload Identity is created THEN the System SHALL verify it is in ACTIVE state
4. THE System SHALL return a valid ARN for the created Workload Identity
5. THE Workload_Identity name SHALL match the pattern [a-zA-Z0-9-_]+

### Requirement 5: Credential Provider Configuration

**User Story:** As an infrastructure operator, I want to configure a Credential Provider linked to IAM Identity Center, so that the Interceptor can generate temporary AWS credentials.

#### Acceptance Criteria

1. WHEN the infrastructure is provisioned THEN the System SHALL create a Bedrock AgentCore Credential Provider
2. THE Credential_Provider SHALL be configured with type IAM_IDENTITY_CENTER
3. WHEN creating the Credential Provider THEN the System SHALL associate it with the IAM Identity Center instance ARN
4. THE System SHALL validate that the IAM Identity Center instance exists before creating the Credential Provider
5. THE Credential_Provider SHALL be available for use by the Interceptor Lambda function

### Requirement 6: Lambda Interceptor Deployment

**User Story:** As a developer, I want to deploy a Lambda function that intercepts Gateway requests and injects AWS credentials, so that MCP servers receive authenticated requests.

#### Acceptance Criteria

1. WHEN the infrastructure is provisioned THEN the System SHALL deploy a Lambda function for request interception
2. THE Interceptor_Lambda SHALL use Python 3.12 runtime
3. THE Interceptor_Lambda SHALL have a timeout of at least 30 seconds
4. THE Interceptor_Lambda SHALL have at least 256 MB of memory allocated
5. WHEN deploying the Lambda THEN the System SHALL attach the Interceptor Execution Role
6. THE Interceptor_Lambda SHALL have environment variables configured for AWS region and Credential Provider name
7. WHEN the Lambda is deployed THEN the System SHALL verify it is in Active state

### Requirement 7: Lambda Invocation Permissions

**User Story:** As an infrastructure operator, I want the Gateway to be able to invoke the Interceptor Lambda, so that requests can be processed with credential injection.

#### Acceptance Criteria

1. WHEN the Lambda is deployed THEN the System SHALL add a resource-based policy allowing Gateway invocation
2. THE Lambda_Permission SHALL allow the bedrock-agentcore.amazonaws.com service principal
3. THE Lambda_Permission SHALL grant lambda:InvokeFunction action
4. THE Lambda_Permission SHALL restrict invocation to the specific AWS account

### Requirement 8: Gateway Configuration

**User Story:** As an infrastructure operator, I want to configure a Gateway with JWT authentication and request interception, so that incoming requests are validated and transformed.

#### Acceptance Criteria

1. WHEN the infrastructure is provisioned THEN the System SHALL create a Bedrock AgentCore Gateway
2. THE Gateway SHALL be configured with a CUSTOM_JWT inbound authorizer
3. WHEN configuring the JWT authorizer THEN the System SHALL set the issuer to the EntraID OIDC discovery URL
4. WHEN configuring the JWT authorizer THEN the System SHALL set the allowed audiences to include the specified EntraID audience
5. THE Gateway SHALL have an interceptor configuration pointing to the Lambda function ARN
6. THE Gateway interceptor configuration SHALL have passRequestHeaders set to true
7. THE Gateway interceptor configuration SHALL have interceptionPoints set to ["REQUEST"]
8. WHEN the Gateway is created THEN the System SHALL verify it reaches ACTIVE state

### Requirement 9: Gateway Target Routing

**User Story:** As a developer, I want the Gateway to route requests to MCP servers, so that agents can access IAM and AWS API capabilities.

#### Acceptance Criteria

1. WHEN the Gateway is configured THEN the System SHALL add at least two target routing rules
2. THE Gateway SHALL have a target configured for IAM MCP server with a valid HTTPS endpoint
3. THE Gateway SHALL have a target configured for AWS API MCP server with a valid HTTPS endpoint
4. WHEN adding a target THEN the System SHALL validate the endpoint URL is HTTPS
5. WHEN adding a target THEN the System SHALL ensure the target name is unique within the Gateway
6. WHEN all targets are configured THEN the System SHALL verify each target status is ACTIVE

### Requirement 10: Token Exchange Flow

**User Story:** As a user, I want to authenticate with my EntraID credentials and have them automatically exchanged for AWS credentials, so that I can access AWS resources seamlessly.

#### Acceptance Criteria

1. WHEN a request arrives with an EntraID JWT THEN the Runtime SHALL exchange it for a Workload Token
2. WHEN the Runtime sends a request to the Gateway THEN the System SHALL include the Workload Token in the authorization header
3. WHEN the Gateway receives a request THEN the System SHALL validate the JWT against the EntraID OIDC discovery endpoint
4. WHEN the JWT is valid THEN the Gateway SHALL forward the request to the Interceptor Lambda
5. WHEN the Interceptor receives a request THEN the System SHALL extract the Workload Token from the authorization header

### Requirement 11: Credential Generation

**User Story:** As a developer, I want the Interceptor to generate temporary AWS credentials on-demand, so that each request has fresh, scoped credentials.

#### Acceptance Criteria

1. WHEN the Interceptor processes a request THEN the System SHALL extract the target account ID from request headers
2. WHEN the Interceptor processes a request THEN the System SHALL extract the target role name from request headers
3. WHEN the Interceptor has extracted target information THEN the System SHALL call bedrock-agentcore:GetResourceCredentials
4. WHEN calling GetResourceCredentials THEN the System SHALL pass the Workload Token, Credential Provider name, target account ID, and target role name
5. WHEN GetResourceCredentials succeeds THEN the System SHALL receive temporary AWS credentials including access key ID, secret access key, and session token
6. THE System SHALL validate that all credential components are non-null before proceeding

### Requirement 12: Credential Injection

**User Story:** As a developer, I want the Interceptor to inject AWS credentials into the request headers, so that MCP servers receive authenticated requests.

#### Acceptance Criteria

1. WHEN the Interceptor receives temporary credentials THEN the System SHALL create transformed request headers
2. THE transformed headers SHALL include x-aws-access-key-id with the access key ID value
3. THE transformed headers SHALL include x-aws-secret-access-key with the secret access key value
4. THE transformed headers SHALL include x-aws-session-token with the session token value
5. WHEN creating the interceptor response THEN the System SHALL preserve the original request body
6. THE Interceptor response SHALL have interceptorOutputVersion set to "1.0"
7. THE Interceptor SHALL NOT log sensitive credential values

### Requirement 13: Infrastructure Validation

**User Story:** As an infrastructure operator, I want the system to validate all components after provisioning, so that I can be confident the infrastructure is correctly configured.

#### Acceptance Criteria

1. WHEN all resources are provisioned THEN the System SHALL perform end-to-end validation
2. THE validation SHALL verify that all IAM roles exist and have correct trust policies
3. THE validation SHALL verify that the Workload Identity is in ACTIVE state
4. THE validation SHALL verify that the Credential Provider is correctly linked to IAM Identity Center
5. THE validation SHALL verify that the Lambda function is in Active state
6. THE validation SHALL verify that the Gateway is in ACTIVE state
7. THE validation SHALL verify that all Gateway targets are in ACTIVE state
8. WHEN any validation check fails THEN the System SHALL report the specific failure

### Requirement 14: Resource ARN Format

**User Story:** As a developer, I want all resource ARNs to follow AWS standards, so that they can be reliably parsed and validated.

#### Acceptance Criteria

1. THE System SHALL generate ARNs matching the pattern arn:aws:[service]:[region]:[account-id]:[resource]
2. WHEN creating any resource THEN the System SHALL validate the ARN format before returning it
3. THE System SHALL ensure the account ID in the ARN matches the configured AWS account ID
4. THE System SHALL ensure the region in the ARN matches the configured AWS region

### Requirement 15: Terraform State Management

**User Story:** As an infrastructure operator, I want Terraform to track all provisioned resources, so that I can manage infrastructure as code and perform updates safely.

#### Acceptance Criteria

1. WHEN resources are provisioned THEN the System SHALL record all resource ARNs in Terraform state
2. THE Terraform state SHALL include Runtime execution role ARN
3. THE Terraform state SHALL include Interceptor execution role ARN
4. THE Terraform state SHALL include Workload Identity ARN
5. THE Terraform state SHALL include Credential Provider ARN
6. THE Terraform state SHALL include Lambda function ARN
7. THE Terraform state SHALL include Gateway ARN
8. THE Terraform state SHALL include Gateway endpoint URL

### Requirement 16: Idempotent Deployment

**User Story:** As an infrastructure operator, I want to run Terraform apply multiple times with the same configuration without creating duplicate resources, so that deployments are safe and predictable.

#### Acceptance Criteria

1. WHEN Terraform apply is executed with identical input variables THEN the System SHALL produce the same resource ARNs
2. WHEN Terraform apply is executed on existing infrastructure THEN the System SHALL detect existing resources and not create duplicates
3. WHEN no configuration changes are made THEN Terraform plan SHALL report zero changes

### Requirement 17: Resource Dependency Ordering

**User Story:** As an infrastructure operator, I want resources to be created in the correct order, so that dependencies are satisfied and provisioning succeeds.

#### Acceptance Criteria

1. THE System SHALL create IAM roles before creating Lambda functions
2. THE System SHALL create Lambda functions before creating the Gateway
3. THE System SHALL create the Workload Identity before creating the Gateway
4. THE System SHALL create the Credential Provider before the Lambda function is invoked
5. THE System SHALL create Lambda permissions before creating the Gateway

### Requirement 18: Security Best Practices

**User Story:** As a security administrator, I want the infrastructure to follow AWS security best practices, so that the system is secure by default.

#### Acceptance Criteria

1. THE System SHALL NOT create IAM roles with wildcard resource permissions unless strict conditions are applied
2. THE System SHALL NOT create IAM roles with administrator access
3. THE System SHALL NOT store sensitive credentials in Lambda environment variables
4. THE Gateway SHALL NOT allow unauthenticated requests
5. THE Gateway inbound authorizer SHALL NOT be set to NONE

### Requirement 19: Credential Temporal Validity

**User Story:** As a security administrator, I want temporary credentials to have limited validity periods, so that the risk of credential compromise is minimized.

#### Acceptance Criteria

1. WHEN credentials are generated THEN the System SHALL ensure the expiration timestamp is in the future
2. WHEN credentials are generated THEN the System SHALL ensure the expiration timestamp is no more than 3600 seconds in the future
3. THE System SHALL validate that the access key ID is in valid AWS format
4. THE System SHALL validate that the secret access key is in valid AWS format
5. THE System SHALL validate that the session token is in valid AWS format

### Requirement 20: Error Handling

**User Story:** As a developer, I want clear error messages when provisioning fails, so that I can quickly diagnose and fix issues.

#### Acceptance Criteria

1. WHEN IAM Identity Center instance does not exist THEN the System SHALL return a descriptive error message
2. WHEN EntraID OIDC discovery endpoint is unreachable THEN the System SHALL return a descriptive error message
3. WHEN Lambda deployment fails THEN the System SHALL return a descriptive error message including the failure reason
4. WHEN Gateway creation fails THEN the System SHALL return a descriptive error message including the failure reason
5. WHEN credential generation fails THEN the Interceptor SHALL return an error response with appropriate HTTP status code

### Requirement 21: Configuration Validation

**User Story:** As an infrastructure operator, I want the system to validate configuration inputs before provisioning, so that I catch errors early.

#### Acceptance Criteria

1. WHEN configuration is provided THEN the System SHALL validate the AWS account ID matches the pattern ^[0-9]{12}$
2. WHEN configuration is provided THEN the System SHALL validate the AWS region is in the list of supported regions
3. WHEN configuration is provided THEN the System SHALL validate the EntraID OIDC issuer URL is a valid HTTPS URL
4. WHEN configuration is provided THEN the System SHALL validate the IAM Identity Center instance ARN is in valid ARN format
5. WHEN configuration is provided THEN the System SHALL validate the workload identity name is non-empty
6. WHEN configuration is provided THEN the System SHALL validate the credential provider name is non-empty
7. WHEN any validation fails THEN the System SHALL report all validation errors before attempting provisioning

### Requirement 22: MCP Server Integration

**User Story:** As a developer, I want the Gateway to properly route requests to MCP servers, so that agents can use IAM and AWS API capabilities.

#### Acceptance Criteria

1. WHEN a request is routed to an MCP server THEN the System SHALL include the injected AWS credentials in the request headers
2. WHEN an MCP server responds THEN the Gateway SHALL forward the response to the Runtime
3. THE Gateway SHALL support routing to multiple MCP server targets
4. WHEN adding an MCP target THEN the System SHALL validate the endpoint URL is accessible

### Requirement 23: Header Propagation

**User Story:** As a developer, I want request headers to be passed to the Interceptor, so that target account and role information is available for credential generation.

#### Acceptance Criteria

1. WHEN the Gateway invokes the Interceptor THEN the System SHALL pass all request headers
2. THE Interceptor SHALL have access to the x-target-account-id header
3. THE Interceptor SHALL have access to the x-target-role-name header
4. THE Interceptor SHALL have access to the authorization header containing the Workload Token

### Requirement 24: Module Structure

**User Story:** As an infrastructure operator, I want the Terraform code organized into reusable modules, so that I can maintain and extend the infrastructure easily.

#### Acceptance Criteria

1. THE System SHALL provide a root module that orchestrates all submodules
2. THE System SHALL provide an IAM module for role creation
3. THE System SHALL provide a Bedrock Identity module for Workload Identity and Credential Provider creation
4. THE System SHALL provide a Lambda module for Interceptor deployment
5. THE System SHALL provide a Gateway module for Gateway and target configuration
6. WHEN using modules THEN the System SHALL pass outputs from one module as inputs to dependent modules

### Requirement 25: Output Values

**User Story:** As an infrastructure operator, I want Terraform to output important resource identifiers, so that I can reference them in other configurations or documentation.

#### Acceptance Criteria

1. WHEN provisioning completes THEN the System SHALL output the Runtime execution role ARN
2. WHEN provisioning completes THEN the System SHALL output the Interceptor execution role ARN
3. WHEN provisioning completes THEN the System SHALL output the Workload Identity ARN
4. WHEN provisioning completes THEN the System SHALL output the Credential Provider ARN
5. WHEN provisioning completes THEN the System SHALL output the Lambda function ARN
6. WHEN provisioning completes THEN the System SHALL output the Gateway ARN
7. WHEN provisioning completes THEN the System SHALL output the Gateway endpoint URL
