#!/usr/bin/env python3
"""
Infrastructure Validation Script for Bedrock AgentCore Terraform Deployment

This script validates that all provisioned resources are correctly configured
and in the expected state after a Terraform apply. Run it after deployment to
verify end-to-end infrastructure health.

Usage:
    python validate_infrastructure.py --region us-east-1 --account-id 123456789012

Requirements: boto3, configured AWS credentials with read access.
"""

import argparse
import json
import sys

import boto3


class ValidationResult:
    """Collects pass/fail results for individual checks."""

    def __init__(self):
        self.checks = []

    def add(self, name, passed, detail=""):
        self.checks.append({"name": name, "passed": passed, "detail": detail})

    @property
    def all_passed(self):
        return all(c["passed"] for c in self.checks)

    def summary(self):
        total = len(self.checks)
        passed = sum(1 for c in self.checks if c["passed"])
        failed = total - passed
        return f"{passed}/{total} checks passed, {failed} failed"

    def print_report(self):
        for check in self.checks:
            status = "✅ PASS" if check["passed"] else "❌ FAIL"
            detail = f" — {check['detail']}" if check["detail"] else ""
            print(f"  {status}: {check['name']}{detail}")
        print(f"\n  {self.summary()}")


def validate_iam_roles(iam_client, result, workload_name, interceptor_name):
    """Validate IAM roles exist with correct trust policies."""
    # Runtime execution role
    runtime_role_name = f"{workload_name}-runtime-role"
    try:
        role = iam_client.get_role(RoleName=runtime_role_name)["Role"]
        trust = json.loads(role["AssumeRolePolicyDocument"])
        principal = trust["Statement"][0]["Principal"]["Service"]
        result.add(
            "Runtime role exists",
            True,
            f"ARN: {role['Arn']}",
        )
        result.add(
            "Runtime role trust policy",
            principal == "bedrock-agentcore.amazonaws.com",
            f"Principal: {principal}",
        )
    except iam_client.exceptions.NoSuchEntityException:
        result.add("Runtime role exists", False, f"Role '{runtime_role_name}' not found")

    # Interceptor execution role
    interceptor_role_name = f"{interceptor_name}-role"
    try:
        role = iam_client.get_role(RoleName=interceptor_role_name)["Role"]
        trust = json.loads(role["AssumeRolePolicyDocument"])
        principal = trust["Statement"][0]["Principal"]["Service"]
        result.add(
            "Interceptor role exists",
            True,
            f"ARN: {role['Arn']}",
        )
        result.add(
            "Interceptor role trust policy",
            principal == "lambda.amazonaws.com",
            f"Principal: {principal}",
        )
    except iam_client.exceptions.NoSuchEntityException:
        result.add(
            "Interceptor role exists",
            False,
            f"Role '{interceptor_role_name}' not found",
        )


def validate_lambda(lambda_client, result, function_name):
    """Validate Lambda function is deployed and Active."""
    try:
        fn = lambda_client.get_function(FunctionName=function_name)
        config = fn["Configuration"]
        state = config.get("State", "Unknown")
        runtime = config.get("Runtime", "Unknown")
        timeout = config.get("Timeout", 0)
        memory = config.get("MemorySize", 0)

        result.add("Lambda function exists", True, f"ARN: {config['FunctionArn']}")
        result.add("Lambda state is Active", state == "Active", f"State: {state}")
        result.add("Lambda runtime is python3.12", runtime == "python3.12", f"Runtime: {runtime}")
        result.add("Lambda timeout >= 30s", timeout >= 30, f"Timeout: {timeout}s")
        result.add("Lambda memory >= 256MB", memory >= 256, f"Memory: {memory}MB")
    except lambda_client.exceptions.ResourceNotFoundException:
        result.add("Lambda function exists", False, f"Function '{function_name}' not found")


def validate_gateway(agentcore_client, result, gateway_name):
    """Validate Bedrock AgentCore Gateway is ACTIVE."""
    try:
        # List gateways and find the one matching our name
        gateways = agentcore_client.list_gateways()
        gateway = None
        for gw in gateways.get("gateways", []):
            if gw.get("gatewayName") == gateway_name:
                gateway = gw
                break

        if gateway:
            status = gateway.get("status", "Unknown")
            result.add("Gateway exists", True, f"ARN: {gateway.get('gatewayArn', 'N/A')}")
            result.add("Gateway status is ACTIVE", status == "ACTIVE", f"Status: {status}")
        else:
            result.add("Gateway exists", False, f"Gateway '{gateway_name}' not found")
    except Exception as exc:
        result.add("Gateway validation", False, f"Error: {exc}")


def main():
    parser = argparse.ArgumentParser(
        description="Validate Bedrock AgentCore Terraform infrastructure"
    )
    parser.add_argument("--region", required=True, help="AWS region")
    parser.add_argument("--account-id", required=True, help="AWS account ID")
    parser.add_argument("--workload-name", default="my-strands-agent", help="Workload Identity name")
    parser.add_argument("--interceptor-name", default="agentcore-interceptor", help="Interceptor Lambda name")
    parser.add_argument("--gateway-name", default="agentcore-gateway", help="Gateway name")
    args = parser.parse_args()

    print(f"\n🔍 Validating infrastructure in {args.region} (account {args.account_id})\n")

    result = ValidationResult()
    session = boto3.Session(region_name=args.region)

    # IAM roles
    print("── IAM Roles ──")
    validate_iam_roles(
        session.client("iam"), result, args.workload_name, args.interceptor_name
    )

    # Lambda
    print("\n── Lambda Interceptor ──")
    validate_lambda(session.client("lambda"), result, args.interceptor_name)

    # Gateway
    print("\n── Bedrock AgentCore Gateway ──")
    validate_gateway(
        session.client("bedrock-agentcore"), result, args.gateway_name
    )

    # Final report
    print(f"\n{'=' * 50}")
    print(f"  {'✅ ALL CHECKS PASSED' if result.all_passed else '❌ SOME CHECKS FAILED'}")
    print(f"  {result.summary()}")
    print(f"{'=' * 50}\n")

    result.print_report()

    sys.exit(0 if result.all_passed else 1)


if __name__ == "__main__":
    main()
