.PHONY: test test-verbose test-specific clean deps help

# Default target
help:
	@echo "IAM Module Test Commands:"
	@echo "  make deps          - Download Go dependencies"
	@echo "  make test          - Run all tests"
	@echo "  make test-verbose  - Run all tests with verbose output"
	@echo "  make test-specific - Run specific test (use TEST=TestName)"
	@echo "  make clean         - Clean test cache and temporary files"

# Download dependencies
deps:
	@echo "Downloading Go dependencies..."
	go mod download
	go mod tidy

# Run all tests
test: deps
	@echo "Running IAM module validation tests..."
	go test -timeout 30m

# Run tests with verbose output
test-verbose: deps
	@echo "Running IAM module validation tests (verbose)..."
	go test -v -timeout 30m

# Run specific test
# Usage: make test-specific TEST=TestIAMRolesTrustPolicies
test-specific: deps
	@echo "Running specific test: $(TEST)..."
	go test -v -timeout 30m -run $(TEST)

# Clean test cache
clean:
	@echo "Cleaning test cache..."
	go clean -testcache
	rm -rf .terraform/
	rm -f terraform.tfstate*
	rm -f .terraform.lock.hcl

# Run tests in parallel
test-parallel: deps
	@echo "Running tests in parallel..."
	go test -v -timeout 30m -parallel 4
