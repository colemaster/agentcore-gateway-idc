# AWS IAM Identity Center Integration Guide

AWS IAM Identity Center (IDC) acts as the central hub for mapping incoming Microsoft Entra ID users to physical, temporary AWS credentials which are required to run Model Context Protocol (MCP) servers locally inside the user's isolated AWS account.

## The Trusted Token Issuer (TTI) Concept

The `aws_ssoadmin_trusted_token_issuer` resource is the underlying mathematical bridge validating external identities. 

### How the Identity Mapping Works
1. **The Request:** The frontend provides a Workload Identity Token (derived from Entra ID JWT).
2. **The Extraction:** Bedrock AgentCore extracts a specific claim from this token based on your Terraform configuration (e.g., `claim_attribute_path = "sub"` or `"email"`).
3. **The Matching:** AWS IDC searches its synchronized internal user pool for an exact match against the extracted claim (`identity_store_attribute_path = "userName"` or `"emails.value"`).
4. **The Assumption:** If matched, the Lambda Interceptor injects a request to `GetResourceCredentials`, allowing the session to assume the requested `x-target-role-name` within the `x-target-account-id`.

## IDC Configuration Requirements

### SCIM Synchronization
For this mapping to work flawlessly, you **MUST** ensure that your AWS IAM Identity Center is synchronized with Microsoft Entra ID via automated SCIM (System for Cross-domain Identity Management). 

If a user exists in Entra ID but not in AWS IDC, the Bedrock Credential Provider will reject the `GetResourceCredentials` call with a `403 Forbidden` error because the Identity map is broken.

### Permission Sets
The `x-target-role-name` passed via HTTP headers must physically map to an assigned Permission Set provisioned over the Target AWS Account.

1. Navigate to AWS IAM Identity Center.
2. Ensure you have a Permission Set configured for AgentCore Execution.
3. Ensure the synchronized Entra ID Users (or Groups) are assigned to that precise Permission Set inside the target account.
