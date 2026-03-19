# Microsoft Entra ID Integration Guide

Microsoft Entra ID (formerly Azure Active Directory) plays a crucial role in the Bedrock AgentCore architecture as the primary Identity Provider (IdP). 

It handles inbound authentication by supplying the Initial JSON Web Token (JWT) and outbound mappings by securely authenticating the Agent for third-party resources.

## 1. Internal Inbound Authentication
When a user accesses the frontend Next.js application, they log in via Entra ID and receive an OpenID Connect (OIDC) JWT.

### Required Claims for AgentCore
For AWS Bedrock AgentCore to successfully validate the JWT, your Entra ID application registration **MUST NOT** include custom non-standard claims in the token envelope. AgentCore strictly verifies standard JWT properties against the Entra ID JWKS (JSON Web Key Set).

Ensure your token contains:
- `iss` (Issuer) - Matches your Entra ID tenant OIDC discovery endpoint.
- `aud` (Audience) - Matches the expected Bedrock AgentCore audience configured in the Gateway Authorizer.
- `sub` (Subject) or `email` - The consistent unique identifier utilized by the AWS Trusted Token Issuer to map the session.

### App Registration Configuration
1. Navigate to the Entra ID Portal -> **App Registrations**.
2. Create a new registration representing the **Next.js Frontend**.
3. Expose an API scope (e.g., `api://bedrock-agentcore/user_impersonation`).
4. In Token Configuration, ensure you select standard claims like `email` and `upn`. Do not add custom extension claims if passing directly to Bedrock.

## 2. Outbound Resource Access
Entra ID can also act as the authoritative source for the AgentCore Credential Provider. 

When your Agent needs to call an external API (like a Microsoft Graph endpoint or an internal secure App), the AWS Bedrock AgentCore Workload Identity leverages the Entra ID token to mathematically verify it is acting on behalf of the established user session.
