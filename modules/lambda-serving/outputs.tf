output "api_gateway_url" {
  description = "URL of the API Gateway"
  value       = aws_api_gateway_stage.ml_api.invoke_url
}

output "api_gateway_id" {
  description = "ID of the API Gateway"
  value       = aws_api_gateway_rest_api.ml_api.id
}

output "api_gateway_arn" {
  description = "ARN of the API Gateway"
  value       = aws_api_gateway_rest_api.ml_api.arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.model_predictor.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.model_predictor.arn
}

output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_execution.arn
}

output "api_key_id" {
  description = "ID of the API key (if enabled)"
  value       = var.enable_api_key ? aws_api_gateway_api_key.ml_api[0].id : null
}

output "api_endpoint_example" {
  description = "Example API endpoint URL"
  value       = "${aws_api_gateway_stage.ml_api.invoke_url}/models/{model_name}/predict"
}
