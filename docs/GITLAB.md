# GitLab Outbound Identity Integration Guide

AWS Bedrock AgentCore supports outbound OAuth 2.0 Identity tracking, enabling AI agents and automated workflows to securely authenticate and execute actions on third-party SaaS ecosystems like GitLab.

## Architectural Overview

Instead of hard-coding a static personal access token (PAT), our Bedrock identity module utilizes an `OAUTH2` mapped `aws_bedrockagentcore_credential_provider`. 

When the Workload Identity initiates a connection to `gitlab.com` via an MCP Server or native Agent capability, it dynamically securely maps the initial user session's `email` claim to the target GitLab environment ensuring the agent takes action **only** on elements the user has explicit permissions for.

## Configuration Requirements

GitLab natively supports Microsoft Entra ID as an identity provider. For this identity bridge to securely pass claims, the following configuration is standard for deploying AgentCore against GitLab SaaS:

### 1. GitLab App Creation
1. Navigate to your GitLab Group or User Settings.
2. Select **Applications** -> **Add new application**.
3. Name your Application (e.g., `Bedrock AgentCore Gateway`).
4. Set the **Redirect URI** to the exact redirect callback provided by your AWS Bedrock implementation (if utilizing 3-legged OIDC) or leave it as client credentials if executing backend impersonation.
5. Grant explicit **Scopes** restricted to the Agent's operation (e.g., `api`, `read_api`, `read_repository`).
6. Securely copy the `Client ID` and `Client Secret`. 

### 2. Passing the Variables to Terraform
Ensure you inject your actual `Client ID` securely into the Terraform infrastructure context:
```hcl
gitlab_client_id       = "gl_appid_abc123"
gitlab_connection_name = "GitLab-OAUTH2-Connection"
```

### 3. Claim Mapping Context
Ensure your Entra ID token propagates the standardized `email` address. Your GitLab users must be provisioned and matching against this strict email string to allow the Bedrock Credential Vault to exchange and invoke actions directly as that user on `gitlab.com`.
