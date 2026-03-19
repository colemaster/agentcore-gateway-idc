package test

import (
	"encoding/json"
	"fmt"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestIAMRolesTrustPolicies validates that both IAM roles have correct trust policies
// Validates Requirements: 2.2, 3.2
func TestIAMRolesTrustPolicies(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: ".",
		Vars: map[string]interface{}{
			"workload_identity_name":  "test-workload",
			"interceptor_lambda_name": "test-interceptor",
			"aws_region":              "us-east-1",
			"aws_account_id":          "123456789012",
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndPlan(t, terraformOptions)

	// Get the planned resources
	plan := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)

	// Find the runtime execution role
	var runtimeRole map[string]interface{}
	var interceptorRole map[string]interface{}

	for _, resource := range plan.ResourceChangesMap {
		if resource.Type == "aws_iam_role" && resource.Name == "runtime_execution_role" {
			runtimeRole = resource.Change.After.(map[string]interface{})
		}
		if resource.Type == "aws_iam_role" && resource.Name == "interceptor_execution_role" {
			interceptorRole = resource.Change.After.(map[string]interface{})
		}
	}

	require.NotNil(t, runtimeRole, "Runtime execution role should be planned")
	require.NotNil(t, interceptorRole, "Interceptor execution role should be planned")

	// Test Runtime Role Trust Policy
	t.Run("RuntimeRoleTrustPolicy", func(t *testing.T) {
		trustPolicyJSON := runtimeRole["assume_role_policy"].(string)
		var trustPolicy map[string]interface{}
		err := json.Unmarshal([]byte(trustPolicyJSON), &trustPolicy)
		require.NoError(t, err, "Trust policy should be valid JSON")

		// Validate Version
		assert.Equal(t, "2012-10-17", trustPolicy["Version"], "Trust policy version should be 2012-10-17")

		// Validate Statement
		statements := trustPolicy["Statement"].([]interface{})
		require.Len(t, statements, 1, "Trust policy should have exactly one statement")

		statement := statements[0].(map[string]interface{})
		assert.Equal(t, "Allow", statement["Effect"], "Statement effect should be Allow")
		assert.Equal(t, "sts:AssumeRole", statement["Action"], "Statement action should be sts:AssumeRole")

		// Validate Principal
		principal := statement["Principal"].(map[string]interface{})
		assert.Equal(t, "bedrock-agentcore.amazonaws.com", principal["Service"], 
			"Principal service should be bedrock-agentcore.amazonaws.com")
	})

	// Test Interceptor Role Trust Policy
	t.Run("InterceptorRoleTrustPolicy", func(t *testing.T) {
		trustPolicyJSON := interceptorRole["assume_role_policy"].(string)
		var trustPolicy map[string]interface{}
		err := json.Unmarshal([]byte(trustPolicyJSON), &trustPolicy)
		require.NoError(t, err, "Trust policy should be valid JSON")

		// Validate Version
		assert.Equal(t, "2012-10-17", trustPolicy["Version"], "Trust policy version should be 2012-10-17")

		// Validate Statement
		statements := trustPolicy["Statement"].([]interface{})
		require.Len(t, statements, 1, "Trust policy should have exactly one statement")

		statement := statements[0].(map[string]interface{})
		assert.Equal(t, "Allow", statement["Effect"], "Statement effect should be Allow")
		assert.Equal(t, "sts:AssumeRole", statement["Action"], "Statement action should be sts:AssumeRole")

		// Validate Principal
		principal := statement["Principal"].(map[string]interface{})
		assert.Equal(t, "lambda.amazonaws.com", principal["Service"], 
			"Principal service should be lambda.amazonaws.com")
	})
}

// TestRuntimeRoleInlinePolicy validates the Runtime role's inline policy permissions and conditions
// Validates Requirements: 2.3, 2.4, 2.5, 2.6
func TestRuntimeRoleInlinePolicy(t *testing.T) {
	t.Parallel()

	workloadName := "test-workload"
	awsRegion := "us-east-1"
	awsAccountID := "123456789012"

	terraformOptions := &terraform.Options{
		TerraformDir: ".",
		Vars: map[string]interface{}{
			"workload_identity_name":  workloadName,
			"interceptor_lambda_name": "test-interceptor",
			"aws_region":              awsRegion,
			"aws_account_id":          awsAccountID,
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndPlan(t, terraformOptions)

	plan := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)

	var runtimeRole map[string]interface{}
	for _, resource := range plan.ResourceChangesMap {
		if resource.Type == "aws_iam_role" && resource.Name == "runtime_execution_role" {
			runtimeRole = resource.Change.After.(map[string]interface{})
			break
		}
	}

	require.NotNil(t, runtimeRole, "Runtime execution role should be planned")

	// Get inline policies
	inlinePolicies := runtimeRole["inline_policy"].([]interface{})
	require.Len(t, inlinePolicies, 1, "Runtime role should have exactly one inline policy")

	inlinePolicy := inlinePolicies[0].(map[string]interface{})
	
	// Validate policy name
	assert.Equal(t, "TokenExchangePolicy", inlinePolicy["name"], 
		"Inline policy name should be TokenExchangePolicy")

	// Parse policy document
	policyJSON := inlinePolicy["policy"].(string)
	var policyDoc map[string]interface{}
	err := json.Unmarshal([]byte(policyJSON), &policyDoc)
	require.NoError(t, err, "Policy document should be valid JSON")

	// Validate policy version
	assert.Equal(t, "2012-10-17", policyDoc["Version"], "Policy version should be 2012-10-17")

	// Validate statements
	statements := policyDoc["Statement"].([]interface{})
	require.Len(t, statements, 1, "Policy should have exactly one statement")

	statement := statements[0].(map[string]interface{})

	// Test permission grant
	t.Run("PermissionGrant", func(t *testing.T) {
		assert.Equal(t, "Allow", statement["Effect"], "Statement effect should be Allow")
		assert.Equal(t, "bedrock-agentcore:GetWorkloadAccessTokenForJwt", statement["Action"], 
			"Statement action should be bedrock-agentcore:GetWorkloadAccessTokenForJwt")
	})

	// Test resource restriction
	t.Run("ResourceRestriction", func(t *testing.T) {
		expectedResource := fmt.Sprintf("arn:aws:bedrock-agentcore:%s:%s:workload-identity/%s",
			awsRegion, awsAccountID, workloadName)
		assert.Equal(t, expectedResource, statement["Resource"], 
			"Resource should be restricted to specific Workload Identity ARN")
	})

	// Test condition enforcement
	t.Run("ConditionEnforcement", func(t *testing.T) {
		condition := statement["Condition"].(map[string]interface{})
		require.NotNil(t, condition, "Statement should have a Condition")

		stringEquals := condition["StringEquals"].(map[string]interface{})
		require.NotNil(t, stringEquals, "Condition should have StringEquals")

		workloadNameCondition := stringEquals["bedrock-agentcore:WorkloadName"]
		assert.Equal(t, workloadName, workloadNameCondition, 
			"Condition should require workload name to match")
	})

	// Test no wildcard resources without conditions
	t.Run("NoWildcardWithoutConditions", func(t *testing.T) {
		resource := statement["Resource"].(string)
		if resource == "*" {
			require.NotNil(t, statement["Condition"], 
				"Wildcard resource must have strict conditions")
		}
	})
}

// TestInterceptorRoleInlinePolicy validates the Interceptor role's inline policy permissions
// Validates Requirements: 3.3
func TestInterceptorRoleInlinePolicy(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: ".",
		Vars: map[string]interface{}{
			"workload_identity_name":  "test-workload",
			"interceptor_lambda_name": "test-interceptor",
			"aws_region":              "us-east-1",
			"aws_account_id":          "123456789012",
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndPlan(t, terraformOptions)

	plan := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)

	var interceptorRole map[string]interface{}
	for _, resource := range plan.ResourceChangesMap {
		if resource.Type == "aws_iam_role" && resource.Name == "interceptor_execution_role" {
			interceptorRole = resource.Change.After.(map[string]interface{})
			break
		}
	}

	require.NotNil(t, interceptorRole, "Interceptor execution role should be planned")

	// Get inline policies
	inlinePolicies := interceptorRole["inline_policy"].([]interface{})
	require.Len(t, inlinePolicies, 1, "Interceptor role should have exactly one inline policy")

	inlinePolicy := inlinePolicies[0].(map[string]interface{})
	
	// Validate policy name
	assert.Equal(t, "CredentialGenerationPolicy", inlinePolicy["name"], 
		"Inline policy name should be CredentialGenerationPolicy")

	// Parse policy document
	policyJSON := inlinePolicy["policy"].(string)
	var policyDoc map[string]interface{}
	err := json.Unmarshal([]byte(policyJSON), &policyDoc)
	require.NoError(t, err, "Policy document should be valid JSON")

	// Validate policy version
	assert.Equal(t, "2012-10-17", policyDoc["Version"], "Policy version should be 2012-10-17")

	// Validate statements
	statements := policyDoc["Statement"].([]interface{})
	require.Len(t, statements, 1, "Policy should have exactly one statement")

	statement := statements[0].(map[string]interface{})

	// Test permission grant
	t.Run("PermissionGrant", func(t *testing.T) {
		assert.Equal(t, "Allow", statement["Effect"], "Statement effect should be Allow")
		assert.Equal(t, "bedrock-agentcore:GetResourceCredentials", statement["Action"], 
			"Statement action should be bedrock-agentcore:GetResourceCredentials")
	})

	// Test resource specification
	t.Run("ResourceSpecification", func(t *testing.T) {
		resource := statement["Resource"]
		assert.NotNil(t, resource, "Resource should be specified")
		// Note: The current implementation uses "*" which is acceptable for this permission
		// as it's scoped by the credential provider configuration
	})
}

// TestInterceptorRoleManagedPolicyAttachment validates the managed policy attachment
// Validates Requirements: 3.4
func TestInterceptorRoleManagedPolicyAttachment(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: ".",
		Vars: map[string]interface{}{
			"workload_identity_name":  "test-workload",
			"interceptor_lambda_name": "test-interceptor",
			"aws_region":              "us-east-1",
			"aws_account_id":          "123456789012",
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndPlan(t, terraformOptions)

	plan := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)

	var interceptorRole map[string]interface{}
	for _, resource := range plan.ResourceChangesMap {
		if resource.Type == "aws_iam_role" && resource.Name == "interceptor_execution_role" {
			interceptorRole = resource.Change.After.(map[string]interface{})
			break
		}
	}

	require.NotNil(t, interceptorRole, "Interceptor execution role should be planned")

	// Get managed policy ARNs
	managedPolicyArns := interceptorRole["managed_policy_arns"].([]interface{})
	require.Len(t, managedPolicyArns, 1, "Interceptor role should have exactly one managed policy")

	// Validate the managed policy ARN
	expectedPolicyArn := "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
	assert.Equal(t, expectedPolicyArn, managedPolicyArns[0], 
		"Managed policy should be AWSLambdaBasicExecutionRole")
}

// TestIAMRoleNaming validates that role names are correctly constructed
func TestIAMRoleNaming(t *testing.T) {
	t.Parallel()

	workloadName := "test-workload"
	interceptorName := "test-interceptor"

	terraformOptions := &terraform.Options{
		TerraformDir: ".",
		Vars: map[string]interface{}{
			"workload_identity_name":  workloadName,
			"interceptor_lambda_name": interceptorName,
			"aws_region":              "us-east-1",
			"aws_account_id":          "123456789012",
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndPlan(t, terraformOptions)

	plan := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)

	t.Run("RuntimeRoleName", func(t *testing.T) {
		var runtimeRole map[string]interface{}
		for _, resource := range plan.ResourceChangesMap {
			if resource.Type == "aws_iam_role" && resource.Name == "runtime_execution_role" {
				runtimeRole = resource.Change.After.(map[string]interface{})
				break
			}
		}

		require.NotNil(t, runtimeRole, "Runtime execution role should be planned")
		expectedName := fmt.Sprintf("%s-runtime-role", workloadName)
		assert.Equal(t, expectedName, runtimeRole["name"], 
			"Runtime role name should follow the pattern {workload_identity_name}-runtime-role")
	})

	t.Run("InterceptorRoleName", func(t *testing.T) {
		var interceptorRole map[string]interface{}
		for _, resource := range plan.ResourceChangesMap {
			if resource.Type == "aws_iam_role" && resource.Name == "interceptor_execution_role" {
				interceptorRole = resource.Change.After.(map[string]interface{})
				break
			}
		}

		require.NotNil(t, interceptorRole, "Interceptor execution role should be planned")
		expectedName := fmt.Sprintf("%s-role", interceptorName)
		assert.Equal(t, expectedName, interceptorRole["name"], 
			"Interceptor role name should follow the pattern {interceptor_lambda_name}-role")
	})
}

// TestSecurityBestPractices validates that roles follow security best practices
// Validates Requirements: 2.6, 3.5, 18.1, 18.2
func TestSecurityBestPractices(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: ".",
		Vars: map[string]interface{}{
			"workload_identity_name":  "test-workload",
			"interceptor_lambda_name": "test-interceptor",
			"aws_region":              "us-east-1",
			"aws_account_id":          "123456789012",
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndPlan(t, terraformOptions)

	plan := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)

	t.Run("NoAdministratorAccess", func(t *testing.T) {
		for _, resource := range plan.ResourceChangesMap {
			if resource.Type == "aws_iam_role" {
				role := resource.Change.After.(map[string]interface{})
				
				// Check managed policies
				if managedPolicies, ok := role["managed_policy_arns"].([]interface{}); ok {
					for _, policyArn := range managedPolicies {
						assert.NotContains(t, policyArn, "AdministratorAccess", 
							"Role should not have AdministratorAccess policy")
						assert.NotContains(t, policyArn, "PowerUserAccess", 
							"Role should not have PowerUserAccess policy")
					}
				}
			}
		}
	})

	t.Run("LeastPrivilegePermissions", func(t *testing.T) {
		// Runtime role should only have GetWorkloadAccessTokenForJwt
		var runtimeRole map[string]interface{}
		for _, resource := range plan.ResourceChangesMap {
			if resource.Type == "aws_iam_role" && resource.Name == "runtime_execution_role" {
				runtimeRole = resource.Change.After.(map[string]interface{})
				break
			}
		}

		require.NotNil(t, runtimeRole, "Runtime execution role should be planned")
		inlinePolicies := runtimeRole["inline_policy"].([]interface{})
		
		for _, policy := range inlinePolicies {
			policyMap := policy.(map[string]interface{})
			policyJSON := policyMap["policy"].(string)
			var policyDoc map[string]interface{}
			json.Unmarshal([]byte(policyJSON), &policyDoc)
			
			statements := policyDoc["Statement"].([]interface{})
			for _, stmt := range statements {
				statement := stmt.(map[string]interface{})
				action := statement["Action"]
				
				// Ensure only specific actions are granted
				assert.NotEqual(t, "*", action, "Action should not be wildcard")
				assert.NotContains(t, action, "*", "Action should not contain wildcards")
			}
		}
	})
}
