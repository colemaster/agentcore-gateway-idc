"""
Unit tests for the Lambda Interceptor function.

These tests validate the interceptor's token extraction, header handling,
credential injection, and error handling logic using unittest.mock to
simulate the Bedrock AgentCore API.
"""

import os
import sys
import unittest
from unittest.mock import MagicMock, patch

# Ensure the src directory is on the path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))

# Set required env vars before importing the module
os.environ["CREDENTIAL_PROVIDER_NAME"] = "test-credential-provider"

import interceptor


class TestExtractBearerToken(unittest.TestCase):
    """Tests for the extract_bearer_token() helper."""

    def test_valid_bearer_token(self):
        token = interceptor.extract_bearer_token("Bearer abc123xyz")
        self.assertEqual(token, "abc123xyz")

    def test_bearer_case_insensitive(self):
        token = interceptor.extract_bearer_token("bearer lowercase-token")
        self.assertEqual(token, "lowercase-token")

    def test_bearer_mixed_case(self):
        token = interceptor.extract_bearer_token("BEARER UPPER-TOKEN")
        self.assertEqual(token, "UPPER-TOKEN")

    def test_none_header(self):
        token = interceptor.extract_bearer_token(None)
        self.assertIsNone(token)

    def test_empty_header(self):
        token = interceptor.extract_bearer_token("")
        self.assertIsNone(token)

    def test_no_bearer_prefix(self):
        token = interceptor.extract_bearer_token("Basic dXNlcjpwYXNz")
        self.assertIsNone(token)

    def test_bearer_with_extra_whitespace(self):
        token = interceptor.extract_bearer_token("Bearer   spaced-token  ")
        self.assertEqual(token, "spaced-token")


class TestLambdaHandlerMissingHeaders(unittest.TestCase):
    """Tests for error handling when required headers are absent."""

    def test_missing_headers_entirely(self):
        event = {}
        result = interceptor.lambda_handler(event, None)
        self.assertEqual(result["interceptorOutputVersion"], "1.0")
        self.assertIn("error", result)

    def test_empty_headers(self):
        event = {"headers": {}}
        result = interceptor.lambda_handler(event, None)
        self.assertIn("error", result)
        self.assertIn("Authorization", result["error"]["message"])

    def test_none_headers(self):
        event = {"headers": None}
        result = interceptor.lambda_handler(event, None)
        self.assertIn("error", result)
        self.assertIn("missing", result["error"]["message"].lower())

    def test_missing_target_account_id(self):
        event = {
            "headers": {
                "authorization": "Bearer valid-token",
                "x-target-role-name": "SomeRole",
            }
        }
        result = interceptor.lambda_handler(event, None)
        self.assertIn("error", result)
        self.assertIn("x-target-account-id", result["error"]["message"])

    def test_missing_target_role_name(self):
        event = {
            "headers": {
                "authorization": "Bearer valid-token",
                "x-target-account-id": "123456789012",
            }
        }
        result = interceptor.lambda_handler(event, None)
        self.assertIn("error", result)
        self.assertIn("x-target-role-name", result["error"]["message"])


class TestLambdaHandlerSuccess(unittest.TestCase):
    """Tests for the full happy-path credential injection flow."""

    def _build_event(self, body="test-body"):
        return {
            "headers": {
                "authorization": "Bearer workload-token-abc",
                "x-target-account-id": "123456789012",
                "x-target-role-name": "TargetRoleName",
            },
            "body": body,
        }

    @patch("interceptor.boto3")
    def test_successful_credential_injection(self, mock_boto3):
        mock_client = MagicMock()
        mock_boto3.client.return_value = mock_client
        mock_client.get_resource_credentials.return_value = {
            "credentials": {
                "accessKeyId": "AKIAIOSFODNN7EXAMPLE",
                "secretAccessKey": "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLE",
                "sessionToken": "FwoGZXIvYXdzEBYaD...",
            }
        }

        result = interceptor.lambda_handler(self._build_event(), None)

        # Verify response structure
        self.assertEqual(result["interceptorOutputVersion"], "1.0")
        self.assertIn("mcp", result)
        self.assertNotIn("error", result)

        transformed = result["mcp"]["transformedGatewayRequest"]

        # Verify credential headers
        self.assertEqual(
            transformed["headers"]["x-aws-access-key-id"], "AKIAIOSFODNN7EXAMPLE"
        )
        self.assertEqual(
            transformed["headers"]["x-aws-secret-access-key"],
            "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLE",
        )
        self.assertEqual(
            transformed["headers"]["x-aws-session-token"], "FwoGZXIvYXdzEBYaD..."
        )

        # Verify body is preserved
        self.assertEqual(transformed["body"], "test-body")

    @patch("interceptor.boto3")
    def test_body_preserved_when_empty(self, mock_boto3):
        mock_client = MagicMock()
        mock_boto3.client.return_value = mock_client
        mock_client.get_resource_credentials.return_value = {
            "credentials": {
                "accessKeyId": "AKIA...",
                "secretAccessKey": "secret...",
                "sessionToken": "token...",
            }
        }

        event = self._build_event(body="")
        result = interceptor.lambda_handler(event, None)
        self.assertEqual(result["mcp"]["transformedGatewayRequest"]["body"], "")

    @patch("interceptor.boto3")
    def test_get_resource_credentials_called_correctly(self, mock_boto3):
        mock_client = MagicMock()
        mock_boto3.client.return_value = mock_client
        mock_client.get_resource_credentials.return_value = {
            "credentials": {
                "accessKeyId": "AKIA...",
                "secretAccessKey": "secret...",
                "sessionToken": "token...",
            }
        }

        interceptor.lambda_handler(self._build_event(), None)

        mock_boto3.client.assert_called_once_with("bedrock-agentcore")
        mock_client.get_resource_credentials.assert_called_once_with(
            workloadIdentityToken="workload-token-abc",
            credentialProviderName="test-credential-provider",
            targetAccountId="123456789012",
            targetRoleName="TargetRoleName",
        )


class TestLambdaHandlerErrors(unittest.TestCase):
    """Tests for error handling when GetResourceCredentials fails."""

    def _build_event(self):
        return {
            "headers": {
                "authorization": "Bearer valid-token",
                "x-target-account-id": "123456789012",
                "x-target-role-name": "SomeRole",
            },
            "body": "",
        }

    @patch("interceptor.boto3")
    def test_incomplete_credentials_response(self, mock_boto3):
        mock_client = MagicMock()
        mock_boto3.client.return_value = mock_client
        mock_client.get_resource_credentials.return_value = {
            "credentials": {
                "accessKeyId": "AKIA...",
                # Missing secretAccessKey and sessionToken
            }
        }

        result = interceptor.lambda_handler(self._build_event(), None)
        self.assertIn("error", result)
        self.assertIn("incomplete", result["error"]["message"].lower())

    @patch("interceptor.boto3")
    def test_general_exception_handling(self, mock_boto3):
        mock_client = MagicMock()
        mock_boto3.client.return_value = mock_client
        mock_client.get_resource_credentials.side_effect = RuntimeError("boom")

        result = interceptor.lambda_handler(self._build_event(), None)
        self.assertEqual(result["interceptorOutputVersion"], "1.0")
        self.assertIn("error", result)


if __name__ == "__main__":
    unittest.main()
