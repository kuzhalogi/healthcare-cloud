# HTTP API is cheaper and simpler than REST API for a demo
resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization"]
  }

  tags = local.tags
}

# Cognito authorizer protects the routes with the user pool token
resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.main.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "${var.project_name}-cognito-authorizer"

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.web.id]
    issuer   = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.main.id}"
  }
}

locals {
  services = {
    patient = {
      lambda = aws_lambda_function.patient
      path   = "patients"
    }
    appointment = {
      lambda = aws_lambda_function.appointment
      path   = "appointments"
    }
    records = {
      lambda = aws_lambda_function.records
      path   = "records"
    }
  }
}

resource "aws_apigatewayv2_integration" "service" {
  for_each = local.services

  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = each.value.lambda.invoke_arn
  payload_format_version = "2.0"
}

# Two routes per service: GET and POST. Auth required on both.
resource "aws_apigatewayv2_route" "get" {
  for_each = local.services

  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "GET /${each.value.path}"
  target             = "integrations/${aws_apigatewayv2_integration.service[each.key].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "post" {
  for_each = local.services

  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "POST /${each.value.path}"
  target             = "integrations/${aws_apigatewayv2_integration.service[each.key].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  tags = local.tags
}

# Allow API Gateway to invoke each Lambda
resource "aws_lambda_permission" "api" {
  for_each = local.services

  statement_id  = "AllowAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = each.value.lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}
