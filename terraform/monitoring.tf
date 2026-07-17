# ---------------------------------------------------------------------------
# Observability: log retention, alarms, and a dashboard.
# Alarms cover the four failure modes:
# function errors, function latency, gateway 5xx, and table throttling.
# ---------------------------------------------------------------------------

locals {
  lambda_functions = {
    patient     = aws_lambda_function.patient.function_name
    appointment = aws_lambda_function.appointment.function_name
    records     = aws_lambda_function.records.function_name
  }

  dynamodb_tables = {
    patients     = aws_dynamodb_table.patients.name
    appointments = aws_dynamodb_table.appointments.name
    records      = aws_dynamodb_table.records.name
  }
}

# Explicit log groups. Without these, Lambda creates them with never-expire
# retention, which costs money forever on a project you tear down.
resource "aws_cloudwatch_log_group" "lambda" {
  for_each = local.lambda_functions

  name              = "/aws/lambda/${each.value}"
  retention_in_days = var.log_retention_days

  tags = local.tags
}

# SNS topic that every alarm publishes to.
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"
  tags = local.tags
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# --- Alarms -----------------------------------------------------------------

# Any function error at all. In a healthcare API a failed write is a lost
# record, so the threshold is 1, not a percentage.
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each = local.lambda_functions

  alarm_name          = "${var.project_name}-${each.key}-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = each.value
  }

  alarm_description = "Lambda ${each.value} returned an error."
  alarm_actions     = [aws_sns_topic.alerts.arn]
  ok_actions        = [aws_sns_topic.alerts.arn]

  tags = local.tags
}

# Duration approaching the 10s timeout. Fires at 8s so you see it coming.
resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  for_each = local.lambda_functions

  alarm_name          = "${var.project_name}-${each.key}-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  extended_statistic  = "p95"
  threshold           = 8000
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = each.value
  }

  alarm_description = "Lambda ${each.value} p95 latency is near the 10s timeout."
  alarm_actions     = [aws_sns_topic.alerts.arn]

  tags = local.tags
}

# Throttling means concurrency is exhausted. Requests are being dropped.
resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  for_each = local.lambda_functions

  alarm_name          = "${var.project_name}-${each.key}-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = each.value
  }

  alarm_description = "Lambda ${each.value} is being throttled."
  alarm_actions     = [aws_sns_topic.alerts.arn]

  tags = local.tags
}

# Gateway 5xx: the API is up but failing. Distinct from 4xx, which is
# usually a client sending bad requests.
resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name          = "${var.project_name}-api-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "5xx"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiId = aws_apigatewayv2_api.main.id
  }

  alarm_description = "API Gateway is returning server errors."
  alarm_actions     = [aws_sns_topic.alerts.arn]

  tags = local.tags
}

# DynamoDB throttling on on-demand tables means a hot partition.
resource "aws_cloudwatch_metric_alarm" "dynamodb_throttles" {
  for_each = local.dynamodb_tables

  alarm_name          = "${var.project_name}-${each.key}-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ThrottledRequests"
  namespace           = "AWS/DynamoDB"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    TableName = each.value
  }

  alarm_description = "DynamoDB table ${each.value} is throttling requests."
  alarm_actions     = [aws_sns_topic.alerts.arn]

  tags = local.tags
}

# --- Log metric filter ------------------------------------------------------

# Access logs for API Gateway. Separate from the Lambda log groups because
# it captures who called what, not what the code did.
resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/apigateway/${var.project_name}"
  retention_in_days = var.log_retention_days

  tags = local.tags
}

# Counts AccessDenied lines in the records function. In a PHI system a
# permissions failure is a security signal, not just a bug.
resource "aws_cloudwatch_log_metric_filter" "access_denied" {
  name           = "${var.project_name}-access-denied"
  log_group_name = aws_cloudwatch_log_group.lambda["records"].name
  pattern        = "AccessDenied"

  metric_transformation {
    name      = "AccessDeniedCount"
    namespace = "${var.project_name}/Security"
    value     = "1"
    unit      = "Count"
  }
}

resource "aws_cloudwatch_metric_alarm" "access_denied" {
  alarm_name          = "${var.project_name}-access-denied"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "AccessDeniedCount"
  namespace           = "${var.project_name}/Security"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  alarm_description = "A Lambda was denied access to a resource. Possible misconfiguration or intrusion attempt."
  alarm_actions     = [aws_sns_topic.alerts.arn]

  tags = local.tags
}

# --- Dashboard --------------------------------------------------------------

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
          title  = "Lambda invocations and errors"
          region = var.aws_region
          view   = "timeSeries"
          stat   = "Sum"
          period = 300
          metrics = flatten([
            for name in values(local.lambda_functions) : [
              ["AWS/Lambda", "Invocations", "FunctionName", name],
              [".", "Errors", ".", "."]
            ]
          ])
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Lambda p95 duration"
          region = var.aws_region
          view   = "timeSeries"
          stat   = "p95"
          period = 300
          metrics = [
            for name in values(local.lambda_functions) :
            ["AWS/Lambda", "Duration", "FunctionName", name]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "API Gateway requests and errors"
          region = var.aws_region
          view   = "timeSeries"
          stat   = "Sum"
          period = 300
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiId", aws_apigatewayv2_api.main.id],
            [".", "4xx", ".", "."],
            [".", "5xx", ".", "."]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "DynamoDB consumed capacity"
          region = var.aws_region
          view   = "timeSeries"
          stat   = "Sum"
          period = 300
          metrics = flatten([
            for name in values(local.dynamodb_tables) : [
              ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", name],
              [".", "ConsumedWriteCapacityUnits", ".", "."]
            ]
          ])
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 12
        width  = 24
        height = 6
        properties = {
          title  = "Recent errors across all functions"
          region = var.aws_region
          query  = <<-EOT
            SOURCE '${aws_cloudwatch_log_group.lambda["patient"].name}'
            | SOURCE '${aws_cloudwatch_log_group.lambda["appointment"].name}'
            | SOURCE '${aws_cloudwatch_log_group.lambda["records"].name}'
            | fields @timestamp, @log, @message
            | filter @message like /(?i)(error|exception|denied)/
            | sort @timestamp desc
            | limit 50
          EOT
          view   = "table"
        }
      }
    ]
  })
}