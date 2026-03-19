# IAM Module Validation Tests - Implementation Summary

## Task Completion: Task 2.4 - Write validation tests for IAM roles

This document summarizes the validation tests implemented for the IAM module as specified in Task 2.4 of the Bedrock AgentCore Terraform Infrastructure implementation plan.

## Requirements Validated

The test suite validates the following requirements from the specification:

### Trust Policy Correctness
- **Requirement 2.2**: Runtime execution role has trust policy allowing bedrock-agentcore.amazonaws.com service principal
- **Requirement 3.2**: Interceptor execution role has trust policy allowing lambda.amazonaws.com service principal

### Inline Policy Permissions and Conditions
- **Requirement 2.3**: Runtime role has inline policy granting bedrock-agentcore:GetWorkloadAccessTokenForJwt permission
- **Requirement 2.4**: GetWorkloadAccessTokenForJwt permission is restricted to specific Workload Identity ARN
- **Requirement 2.5**: GetWorkloadAccessTokenForJwt permission has condition requiring workload name to match
- **Requirement 2.6**: Runtime role does not have wildcard resource permissions without strict conditions
- **Requirement 3.3**: Interceptor role has inline policy granting bedrock-agentcore:GetResourceCredentials permission

### Managed Policy Attachments
- **Requirement 3.4**: Interceptor role has AWSLambdaBasicExecutionRole managed policy attached

### Security Best Practices
- **Requirement 3.5**: Interceptor role does not have administrator access or overly permissive policies
- **Requirement 18.1**: No IAM roles with wildcard resource permissions unless strict conditions are applied
- **Requirement 18.2**: No IAM roles with administrator access

## Test Files Created

### 1. `iam_test.go`
Main test file containing all validation tests using the Terratest framework.

**Test Functions:**

1. **TestIAMRolesTrustPolicies**
   - Validates trust policies for both Runtime and Interceptor roles
   - Checks policy version, statements, effects, actions, and principals
   - Validates Requirements: 2.2, 3.2

2. **TestRuntimeRoleInlinePolicy**
   - Validates the Runtime role's TokenExchangePolicy
   - Checks permission grants, resource restrictions, and conditions
   - Validates Requirements: 2.3, 2.4, 2.5, 2.6

3. **TestInterceptorRoleInlinePolicy**
   - Validates the Interceptor role's CredentialGenerationPolicy
   - Checks permission grants and resource specifications
   - Validates Requirement: 3.3

4. **TestInterceptorRoleManagedPolicyAttachment**
   - Validates that AWSLambdaBasicExecutionRole is attached
   - Validates Requirement: 3.4

5. **TestIAMRoleNaming**
   - Validates role naming conventions
   - Ensures consistent naming patterns

6. **TestSecurityBestPractices**
   - Validates no administrator access policies
   - Validates least privilege permissions
   - Validates Requirements: 2.6, 3.5, 18.1, 18.2

### 2. `go.mod`
Go module definition with dependencies:
- Terratest v0.46.8 for Terraform testing
- Testify v1.8.4 for assertions

### 3. `TEST_README.md`
Comprehensive documentation covering:
- Test coverage and requirements mapping
- Prerequisites and setup instructions
- How to run tests (all, specific, parallel)
- Expected output examples
- Troubleshooting guide
- CI/CD integration examples

### 4. `Makefile`
Convenience commands for running tests:
- `make deps` - Download dependencies
- `make test` - Run all tests
- `make test-verbose` - Run with verbose output
- `make test-specific TEST=TestName` - Run specific test
- `make clean` - Clean test cache

### 5. `.gitignore`
Ignores test artifacts and temporary files

### 6. Updated `README.md`
Added testing section with quick start guide

## Test Approach

The tests use **Terratest**, the industry-standard Go-based testing framework for Terraform infrastructure. This approach provides:

1. **Plan-based validation**: Tests validate the Terraform plan without actually creating AWS resources, making tests fast and safe
2. **Comprehensive assertions**: Uses testify for clear, readable assertions
3. **Parallel execution**: Tests can run in parallel for faster execution
4. **CI/CD ready**: Easy integration into automated pipelines

## Test Coverage Summary

| Requirement | Test Function | Status |
|-------------|---------------|--------|
| 2.2 | TestIAMRolesTrustPolicies | ✅ Implemented |
| 2.3 | TestRuntimeRoleInlinePolicy | ✅ Implemented |
| 2.4 | TestRuntimeRoleInlinePolicy | ✅ Implemented |
| 2.5 | TestRuntimeRoleInlinePolicy | ✅ Implemented |
| 2.6 | TestRuntimeRoleInlinePolicy, TestSecurityBestPractices | ✅ Implemented |
| 3.2 | TestIAMRolesTrustPolicies | ✅ Implemented |
| 3.3 | TestInterceptorRoleInlinePolicy | ✅ Implemented |
| 3.4 | TestInterceptorRoleManagedPolicyAttachment | ✅ Implemented |
| 3.5 | TestSecurityBestPractices | ✅ Implemented |
| 18.1 | TestSecurityBestPractices | ✅ Implemented |
| 18.2 | TestSecurityBestPractices | ✅ Implemented |

## How to Run the Tests

### Prerequisites
1. Install Go 1.21 or later
2. Install Terraform 1.5.0 or later
3. Configure AWS credentials

### Quick Start
```bash
cd modules/iam
make deps
make test-verbose
```

### Run Specific Test
```bash
make test-specific TEST=TestIAMRolesTrustPolicies
```

## Design Properties Validated

The tests validate the following correctness properties from the design document:

### Property 1: IAM Role Trust Policy Correctness
```pascal
FORALL role IN [runtime_execution_role, interceptor_execution_role]:
  role.assume_role_policy IS NOT NULL AND
  role.assume_role_policy.Version = "2012-10-17" AND
  EXISTS statement IN role.assume_role_policy.Statement:
    statement.Effect = "Allow" AND
    statement.Action = "sts:AssumeRole"
```
**Validated by**: TestIAMRolesTrustPolicies

### Property 2: Permission Boundary Enforcement
```pascal
FORALL role IN [runtime_execution_role]:
  EXISTS policy IN role.inline_policies:
    FORALL statement IN policy.Statement:
      EXISTS condition IN statement.Condition:
        condition.StringEquals["bedrock-agentcore:WorkloadName"] = workload_identity_name
```
**Validated by**: TestRuntimeRoleInlinePolicy

### Property 13: Security Best Practices
```pascal
FORALL role IN iam_roles:
  NOT hasWildcardResource(role) OR hasStrictConditions(role) AND
  NOT hasAdministratorAccess(role)
```
**Validated by**: TestSecurityBestPractices

## Test Execution Flow

1. **Setup**: Configure Terraform options with test variables
2. **Initialize**: Run `terraform init` to initialize the module
3. **Plan**: Run `terraform plan` to generate execution plan
4. **Parse**: Parse the plan output into structured data
5. **Validate**: Run assertions against the parsed plan
6. **Cleanup**: Destroy any created resources (deferred)

## Benefits of This Testing Approach

1. **Fast**: Tests validate plans without creating actual AWS resources
2. **Safe**: No risk of creating billable resources or affecting production
3. **Comprehensive**: Validates all aspects of IAM role configuration
4. **Maintainable**: Clear test structure with descriptive names
5. **Automated**: Easy to integrate into CI/CD pipelines
6. **Documented**: Extensive documentation for running and understanding tests

## Next Steps

To run these tests in your environment:

1. Ensure Go and Terraform are installed
2. Configure AWS credentials
3. Navigate to `modules/iam`
4. Run `make test-verbose`

The tests will validate all IAM role configurations against the requirements and report any issues.

## Compliance

These tests ensure compliance with:
- AWS IAM best practices
- Principle of least privilege
- Bedrock AgentCore security requirements
- Infrastructure as Code testing standards

## Maintenance

When updating the IAM module:
1. Run tests to ensure no regressions
2. Update tests if new requirements are added
3. Keep test documentation in sync with implementation
4. Review test coverage for new features

---

**Task Status**: ✅ Complete

All validation tests for IAM roles have been implemented as specified in Task 2.4, covering trust policy correctness, inline policy permissions and conditions, and managed policy attachments for Requirements 2.2, 2.3, 3.2, and 3.3.
