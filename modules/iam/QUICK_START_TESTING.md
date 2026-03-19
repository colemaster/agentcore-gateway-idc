# Quick Start: Running IAM Module Tests

## One-Command Test Execution

```bash
cd modules/iam && make test-verbose
```

## What Gets Tested

✅ **Trust Policies** - Both Runtime and Interceptor roles have correct service principals  
✅ **Inline Policies** - Correct permissions with proper resource restrictions  
✅ **Conditions** - Workload name matching condition is enforced  
✅ **Managed Policies** - AWSLambdaBasicExecutionRole is attached  
✅ **Security** - No administrator access, least privilege enforced  

## Prerequisites

```bash
# Install Go (if not already installed)
# macOS
brew install go

# Ubuntu/Debian
sudo apt-get install golang-go

# Verify installation
go version  # Should show 1.21 or later

# Install Terraform (if not already installed)
# macOS
brew install terraform

# Ubuntu/Debian
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install terraform

# Verify installation
terraform version  # Should show 1.5.0 or later

# Configure AWS credentials
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"

# Verify AWS access
aws sts get-caller-identity
```

## Running Tests

### All Tests (Verbose)
```bash
cd modules/iam
make test-verbose
```

### All Tests (Quiet)
```bash
cd modules/iam
make test
```

### Specific Test
```bash
cd modules/iam
make test-specific TEST=TestIAMRolesTrustPolicies
```

### Parallel Execution
```bash
cd modules/iam
make test-parallel
```

## Expected Output

```
=== RUN   TestIAMRolesTrustPolicies
=== RUN   TestIAMRolesTrustPolicies/RuntimeRoleTrustPolicy
=== RUN   TestIAMRolesTrustPolicies/InterceptorRoleTrustPolicy
--- PASS: TestIAMRolesTrustPolicies (5.23s)
=== RUN   TestRuntimeRoleInlinePolicy
--- PASS: TestRuntimeRoleInlinePolicy (5.18s)
=== RUN   TestInterceptorRoleInlinePolicy
--- PASS: TestInterceptorRoleInlinePolicy (5.21s)
=== RUN   TestInterceptorRoleManagedPolicyAttachment
--- PASS: TestInterceptorRoleManagedPolicyAttachment (5.19s)
=== RUN   TestIAMRoleNaming
--- PASS: TestIAMRoleNaming (5.22s)
=== RUN   TestSecurityBestPractices
--- PASS: TestSecurityBestPractices (5.20s)
PASS
ok      github.com/bedrock-agentcore-terraform/modules/iam     31.234s
```

## Troubleshooting

### "go: command not found"
Install Go using the prerequisites section above.

### "terraform: command not found"
Install Terraform using the prerequisites section above.

### "Error: No valid credential sources found"
Configure AWS credentials:
```bash
aws configure
# OR
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
```

### Tests timeout
Increase timeout:
```bash
go test -v -timeout 60m
```

### Need to debug a test
Add `-v` flag and check the Terraform plan output:
```bash
go test -v -run TestIAMRolesTrustPolicies
```

## What These Tests Do NOT Do

❌ Create actual AWS resources (tests only validate Terraform plans)  
❌ Incur AWS costs (no resources are deployed)  
❌ Require special AWS permissions (only needs ability to plan)  
❌ Modify your AWS account  

## CI/CD Integration

### GitHub Actions
```yaml
- name: Test IAM Module
  run: |
    cd modules/iam
    make test-verbose
  env:
    AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
    AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

### GitLab CI
```yaml
test-iam:
  script:
    - cd modules/iam
    - make test-verbose
  variables:
    AWS_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID
    AWS_SECRET_ACCESS_KEY: $AWS_SECRET_ACCESS_KEY
```

## Need More Details?

- Full documentation: [TEST_README.md](./TEST_README.md)
- Implementation summary: [VALIDATION_TESTS_SUMMARY.md](./VALIDATION_TESTS_SUMMARY.md)
- Test code: [iam_test.go](./iam_test.go)
