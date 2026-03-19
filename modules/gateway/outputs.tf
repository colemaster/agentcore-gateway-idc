output "gateway_arn" {
  description = "ARN of the Bedrock AgentCore Gateway"
  value       = aws_bedrockagentcore_gateway.main.arn
}

output "gateway_endpoint_url" {
  description = "Endpoint URL of the Bedrock AgentCore Gateway"
  value       = aws_bedrockagentcore_gateway.main.endpoint_url
}
