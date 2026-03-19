# Lambda Module

This module deploys the Lambda interceptor function that injects AWS credentials into Gateway requests.

## Resources Created

- Lambda function with Python 3.12 runtime
- Lambda permission for Bedrock Gateway invocation
- Lambda deployment package

## Inputs

- `function_name` - Name of the Lambda function
- `execution_role_arn` - ARN of the Lambda execution role
- `credential_provider_name` - Name of the Credential Provider
- `aws_region` - AWS region
- `aws_account_id` - AWS account ID

## Outputs

- `lambda_arn` - ARN of the Lambda function
- `lambda_function_name` - Name of the Lambda function
