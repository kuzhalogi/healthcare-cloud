# CloudWatch dashboard giving you one screen of system health for the demo
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-health"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Lambda invocations"
          region = var.aws_region
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.patient.function_name],
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.appointment.function_name],
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.records.function_name]
          ]
          period = 300
          stat   = "Sum"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Lambda errors"
          region = var.aws_region
          metrics = [
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.patient.function_name],
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.appointment.function_name],
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.records.function_name]
          ]
          period = 300
          stat   = "Sum"
        }
      }
    ]
  })
}

# These values feed your frontend config after deploy
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
