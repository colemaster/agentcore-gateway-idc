"""
Lambda Interceptor for Bedrock AgentCore Gateway

This function intercepts Gateway requests and performs Just-in-Time (JIT)
credential generation by exchanging a Workload Token for temporary AWS
credentials via the Bedrock AgentCore GetResourceCredentials API.

The interceptor:
  1. Extracts the Workload Token from the Authorization header
  2. Reads x-target-account-id and x-target-role-name headers
  3. Calls GetResourceCredentials to obtain temporary AWS credentials
  4. Injects credentials into transformed request headers
  5. Returns the modified request for the Gateway to forward to MCP servers

CRITICAL: Sensitive credential values are never logged.
"""

import logging
import os

import boto3
import botocore.exceptions

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Read configuration from environment variables
CREDENTIAL_PROVIDER_NAME = os.environ.get("CREDENTIAL_PROVIDER_NAME", "")


def extract_bearer_token(auth_header):
    """Extract the bearer token from an Authorization header value.

    Args:
        auth_header: The raw Authorization header string (e.g. "Bearer <token>").

    Returns:
        The token string with the "Bearer " prefix stripped, or None if the
        header is missing or malformed.
    """
    if not auth_header:
        return None

    # Handle both "Bearer " and "bearer " (case-insensitive prefix)
    if auth_header.lower().startswith("bearer "):
        return auth_header[7:].strip()

    return None


def lambda_handler(event, context):
    """Main Lambda entry point invoked by the Bedrock AgentCore Gateway.

    The Gateway calls this function at the REQUEST interception point with
    passRequestHeaders enabled, providing the original request headers and body.

    Args:
        event: Gateway interceptor event containing headers and body.
        context: Lambda execution context.

    Returns:
        Interceptor response with version "1.0" and transformed request
        containing injected AWS credential headers.
    """
    logger.info("Interceptor invoked — processing Gateway request")

    try:
        # ── Step 1: Extract headers ──────────────────────────────────────
        headers = event.get("headers")
        if headers is None:
            return _error_response("Request headers are missing from the event")

        # Extract the Workload Token from the Authorization header
        auth_header = headers.get("authorization") or headers.get("Authorization")
        workload_token = extract_bearer_token(auth_header)
        if not workload_token:
            return _error_response(
                "Missing or malformed Authorization header — "
                "expected 'Bearer <workload-token>'"
            )

        # Extract target account and role from custom headers
        target_account_id = (
            headers.get("x-target-account-id")
            or headers.get("X-Target-Account-Id")
        )
        target_role_name = (
            headers.get("x-target-role-name")
            or headers.get("X-Target-Role-Name")
        )

        if not target_account_id:
            return _error_response("Missing required header: x-target-account-id")
        if not target_role_name:
            return _error_response("Missing required header: x-target-role-name")

        logger.info(
            "Requesting credentials for account=%s role=%s",
            target_account_id,
            target_role_name,
        )

        # ── Step 2: Call GetResourceCredentials ──────────────────────────
        client = boto3.client("bedrock-agentcore")

        credential_response = client.get_resource_credentials(
            workloadIdentityToken=workload_token,
            credentialProviderName=CREDENTIAL_PROVIDER_NAME,
            targetAccountId=target_account_id,
            targetRoleName=target_role_name,
        )

        credentials = credential_response.get("credentials", {})

        # ── Step 3: Validate received credentials ────────────────────────
        access_key_id = credentials.get("accessKeyId")
        secret_access_key = credentials.get("secretAccessKey")
        session_token = credentials.get("sessionToken")

        if not all([access_key_id, secret_access_key, session_token]):
            return _error_response(
                "GetResourceCredentials returned incomplete credentials"
            )

        logger.info("Credentials obtained successfully — injecting into request")

        # ── Step 4: Build transformed request ────────────────────────────
        transformed_headers = {
            "x-aws-access-key-id": access_key_id,
            "x-aws-secret-access-key": secret_access_key,
            "x-aws-session-token": session_token,
        }

        response = {
            "interceptorOutputVersion": "1.0",
            "mcp": {
                "transformedGatewayRequest": {
                    "headers": transformed_headers,
                    "body": event.get("body", ""),
                }
            },
        }

        return response

    except botocore.exceptions.ClientError as exc:
        error_code = exc.response["Error"]["Code"]
        error_msg = exc.response["Error"]["Message"]
        logger.error(
            "GetResourceCredentials failed: %s — %s", error_code, error_msg
        )
        return _error_response(
            f"Credential generation failed: {error_code} — {error_msg}"
        )
    except Exception as exc:
        logger.error("Unexpected error in interceptor: %s", str(exc))
        return _error_response(f"Internal interceptor error: {str(exc)}")


def _error_response(message):
    """Build a standardized error response for the Gateway.

    Args:
        message: Human-readable error description.

    Returns:
        Interceptor response dict with error information.
    """
    logger.error("Interceptor error: %s", message)
    return {
        "interceptorOutputVersion": "1.0",
        "error": {
            "message": message,
        },
    }
