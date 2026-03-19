# IAM Module

This module creates IAM roles for Bedrock AgentCore Runtime and Lambda Interceptor execution.

## Resources Created

- Runtime Execution Role with trust policy for bedrock-agentcore.amazonaws.com
- Interceptor Execution Role with trust policy for lambda.amazonaws.com
- Inline policies for token exchange and credential generation

## Inputs

- `workload_identity_name` - Name of the workload identity
- `interceptor_lambda_name` - Name of the interceptor Lambda function
- `aws_region` - AWS region
- `aws_account_id` - AWS account ID

## Outputs

- `runtime_role_arn` - ARN of the Runtime execution role
- `interceptor_role_arn` - ARN of the Interceptor execution role

## Testing

This module includes comprehensive validation tests using Terratest. See [TEST_README.md](./TEST_README.md) for detailed testing documentation.

To run the tests:

```bash
cd modules/iam
go mod download
go test -v -timeout 30m
```

The test suite validates:
- Trust policy correctness for both roles (Requirements 2.2, 3.2)
- Inline policy permissions and conditions (Requirements 2.3, 2.4, 2.5, 3.3)
- Managed policy attachments (Requirement 3.4)
- Security best practices (Requirements 2.6, 3.5, 18.1, 18.2)
