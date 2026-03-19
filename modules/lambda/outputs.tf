output "lambda_arn" {
  description = "ARN of the Lambda interceptor function"
  value       = aws_lambda_function.interceptor.arn
}

output "lambda_function_name" {
  description = "Name of the Lambda interceptor function"
  value       = aws_lambda_function.interceptor.function_name
}
