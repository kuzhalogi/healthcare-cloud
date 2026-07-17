# These values feed our frontend config after deploy
output "api_url" {
  description = "Base URL for the API"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "cognito_user_pool_id" {
  description = "Cognito user pool ID"
  value       = aws_cognito_user_pool.main.id
}

output "cognito_client_id" {
  description = "Cognito app client ID"
  value       = aws_cognito_user_pool_client.web.id
}

output "cognito_region" {
  description = "Region for Cognito"
  value       = var.aws_region
}

output "documents_bucket" {
  description = "S3 bucket for medical documents"
  value       = aws_s3_bucket.documents.id
}

output "dashboard_url" {
  description = "CloudWatch dashboard link"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "frontend_url" {
  description = "Public URL of the React app."
  value       = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}

output "frontend_bucket" {
  description = "S3 bucket holding the built frontend."
  value       = aws_s3_bucket.frontend.id
}

output "cloudfront_distribution_id" {
  description = "Distribution ID, used to invalidate the cache after a deploy."
  value       = aws_cloudfront_distribution.frontend.id
}