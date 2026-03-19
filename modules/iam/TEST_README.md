# IAM Module Validation Tests

This directory contains validation tests for the IAM module that creates Runtime and Interceptor execution roles for Bedrock AgentCore infrastructure.

## Test Coverage

The test suite validates the following requirements:

### Trust Policy Correctness (Requirements 2.2, 3.2)
- **TestIAMRolesTrustPolicies**: Validates that both Runtime and Interceptor roles have correct trust policies
  - Runtime role trusts `bedrock-agentcore.amazonaws.com`
  - Interceptor role trusts `lambda.amazonaws.com`
  - Both use policy version `2012-10-17`
  - Both allow `sts:AssumeRole` action

### Runtime Role Inline Policy (Requirements 2.3, 2.4, 2.5, 2.6)
- **TestRuntimeRoleInlinePolicy**: Validates the Runtime role's inline policy
  - Policy name is `TokenExchangePolicy`
  - Grants `bedrock-agentcore:GetWorkloadAccessTokenForJwt` permission
  - Resource is restricted to specific Workload Identity ARN
  - Condition requires workload name to match
  - No wildcard resources without strict conditions

### Interceptor Role Inline Policy (Requirement 3.3)
- **TestInterceptorRoleInlinePolicy**: Validates the Interceptor role's inline policy
  - Policy name is `CredentialGenerationPolicy`
  - Grants `bedrock-agentcore:GetResourceCredentials` permission
  - Resource specification is appropriate for credential generation

### Managed Policy Attachments (Requirement 3.4)
- **TestInterceptorRoleManagedPolicyAttachment**: Validates managed policy attachments
  - Interceptor role has `AWSLambdaBasicExecutionRole` attached
  - Only one managed policy is attached

### Security Best Practices (Requirements 2.6, 3.5, 18.1, 18.2)
- **TestSecurityBestPractices**: Validates security best practices
  - No AdministratorAccess or PowerUserAccess policies
  - Least privilege permissions (no wildcard actions)
  - Specific actions only

### Role Naming
- **TestIAMRoleNaming**: Validates role naming conventions
  - Runtime role: `{workload_identity_name}-runtime-role`
  - Interceptor role: `{interceptor_lambda_name}-role`

## Prerequisites

1. **Go**: Install Go 1.21 or later
   ```bash
   # Check Go version
   go version
   ```

2. **AWS Credentials**: Configure AWS credentials with permissions to plan Terraform resources
   ```bash
   export AWS_ACCESS_KEY_ID="your-access-key"
   export AWS_SECRET_ACCESS_KEY="your-secret-key"
   export AWS_DEFAULT_REGION="us-east-1"
   ```

3. **Terraform**: Install Terraform 1.5.0 or later
   ```bash
   # Check Terraform version
   terraform version
   ```

## Running the Tests

### Install Dependencies

```bash
cd modules/iam
go mod download
```

### Run All Tests

```bash
go test -v -timeout 30m
```

### Run Specific Test

```bash
# Run trust policy tests only
go test -v -timeout 30m -run TestIAMRolesTrustPolicies

# Run inline policy tests only
go test -v -timeout 30m -run TestRuntimeRoleInlinePolicy

# Run security best practices tests only
go test -v -timeout 30m -run TestSecurityBestPractices
```

### Run Tests in Parallel

```bash
go test -v -timeout 30m -parallel 4
```

## Test Structure

Each test follows this pattern:

1. **Setup**: Configure Terraform options with test variables
2. **Plan**: Run `terraform init` and `terraform plan`
3. **Validate**: Parse the plan output and validate resource configurations
4. **Cleanup**: Destroy resources (deferred to ensure cleanup even on failure)

## Test Variables

The tests use the following default test variables:

```hcl
workload_identity_name  = "test-workload"
interceptor_lambda_name = "test-interceptor"
aws_region              = "us-east-1"
aws_account_id          = "123456789012"
```

## Expected Output

Successful test run:

```
=== RUN   TestIAMRolesTrustPolicies
=== RUN   TestIAMRolesTrustPolicies/RuntimeRoleTrustPolicy
=== RUN   TestIAMRolesTrustPolicies/InterceptorRoleTrustPolicy
--- PASS: TestIAMRolesTrustPolicies (5.23s)
    --- PASS: TestIAMRolesTrustPolicies/RuntimeRoleTrustPolicy (0.00s)
    --- PASS: TestIAMRolesTrustPolicies/InterceptorRoleTrustPolicy (0.00s)
=== RUN   TestRuntimeRoleInlinePolicy
=== RUN   TestRuntimeRoleInlinePolicy/PermissionGrant
=== RUN   TestRuntimeRoleInlinePolicy/ResourceRestriction
=== RUN   TestRuntimeRoleInlinePolicy/ConditionEnforcement
=== RUN   TestRuntimeRoleInlinePolicy/NoWildcardWithoutConditions
--- PASS: TestRuntimeRoleInlinePolicy (5.18s)
    --- PASS: TestRuntimeRoleInlinePolicy/PermissionGrant (0.00s)
    --- PASS: TestRuntimeRoleInlinePolicy/ResourceRestriction (0.00s)
    --- PASS: TestRuntimeRoleInlinePolicy/ConditionEnforcement (0.00s)
    --- PASS: TestRuntimeRoleInlinePolicy/NoWildcardWithoutConditions (0.00s)
=== RUN   TestInterceptorRoleInlinePolicy
=== RUN   TestInterceptorRoleInlinePolicy/PermissionGrant
=== RUN   TestInterceptorRoleInlinePolicy/ResourceSpecification
--- PASS: TestInterceptorRoleInlinePolicy (5.21s)
    --- PASS: TestInterceptorRoleInlinePolicy/PermissionGrant (0.00s)
    --- PASS: TestInterceptorRoleInlinePolicy/ResourceSpecification (0.00s)
=== RUN   TestInterceptorRoleManagedPolicyAttachment
--- PASS: TestInterceptorRoleManagedPolicyAttachment (5.19s)
=== RUN   TestIAMRoleNaming
=== RUN   TestIAMRoleNaming/RuntimeRoleName
=== RUN   TestIAMRoleNaming/InterceptorRoleName
--- PASS: TestIAMRoleNaming (5.22s)
    --- PASS: TestIAMRoleNaming/RuntimeRoleName (0.00s)
    --- PASS: TestIAMRoleNaming/InterceptorRoleName (0.00s)
=== RUN   TestSecurityBestPractices
=== RUN   TestSecurityBestPractices/NoAdministratorAccess
=== RUN   TestSecurityBestPractices/LeastPrivilegePermissions
--- PASS: TestSecurityBestPractices (5.20s)
    --- PASS: TestSecurityBestPractices/NoAdministratorAccess (0.00s)
    --- PASS: TestSecurityBestPractices/LeastPrivilegePermissions (0.00s)
PASS
ok      github.com/bedrock-agentcore-terraform/modules/iam     31.234s
```

## Troubleshooting

### Test Timeout
If tests timeout, increase the timeout value:
```bash
go test -v -timeout 60m
```

### AWS Credentials
If you see authentication errors, verify your AWS credentials:
```bash
aws sts get-caller-identity
```

### Terraform State
Tests use temporary directories and clean up automatically. If you need to debug, you can disable cleanup by commenting out the `defer terraform.Destroy(t, terraformOptions)` line.

## CI/CD Integration

To integrate these tests into CI/CD pipelines:

```yaml
# Example GitHub Actions workflow
- name: Run IAM Module Tests
  run: |
    cd modules/iam
    go mod download
    go test -v -timeout 30m
  env:
    AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
    AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    AWS_DEFAULT_REGION: us-east-1
```

## Additional Resources

- [Terratest Documentation](https://terratest.gruntwork.io/)
- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [Terraform Testing Best Practices](https://www.terraform.io/docs/language/modules/testing-experiment.html)
