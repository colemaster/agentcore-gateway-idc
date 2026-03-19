output "runtime_role_arn" {
  description = "ARN of the Runtime execution role"
  value       = aws_iam_role.runtime_execution_role.arn
}

output "interceptor_role_arn" {
  description = "ARN of the Interceptor execution role"
  value       = aws_iam_role.interceptor_execution_role.arn
}
