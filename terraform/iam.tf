# ---------------------------------------------------------------------------
# Per-service execution roles. Each Lambda gets its own identity, scoped to
# only the resources it actually touches. Blast radius of a compromised
# function is limited to that function's data.
# ---------------------------------------------------------------------------

locals {
  lambda_services = {
    patient     = aws_dynamodb_table.patients.arn
    appointment = aws_dynamodb_table.appointments.arn
    records     = aws_dynamodb_table.records.arn
  }
}

resource "aws_iam_role" "lambda" {
  for_each = local.lambda_services

  name = "${var.project_name}-${each.key}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = local.tags
}

# CloudWatch logging so every function writes an audit trail.
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  for_each = aws_iam_role.lambda

  role       = each.value.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# DynamoDB: each service reaches only its own table, plus that table's indexes.
resource "aws_iam_role_policy" "dynamodb" {
  for_each = local.lambda_services

  name = "${var.project_name}-${each.key}-dynamodb"
  role = aws_iam_role.lambda[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query"
      ]
      Resource = [
        each.value,
        "${each.value}/index/*"
      ]
    }]
  })
}

# S3: only the records service handles documents. Prefixed so a future
# service cannot read another's objects.
resource "aws_iam_role_policy" "s3_documents" {
  name = "${var.project_name}-records-s3"
  role = aws_iam_role.lambda["records"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ]
      Resource = "${aws_s3_bucket.documents.arn}/records/*"
    }]
  })
}

# KMS: every service encrypts and decrypts its own data at rest.
# Condition pins usage to the services that actually hold PHI.
resource "aws_iam_role_policy" "kms" {
  for_each = local.lambda_services

  name = "${var.project_name}-${each.key}-kms"
  role = aws_iam_role.lambda[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ]
      Resource = aws_kms_key.main.arn
      Condition = {
        StringEquals = {
          "kms:ViaService" = [
            "dynamodb.${var.aws_region}.amazonaws.com",
            "s3.${var.aws_region}.amazonaws.com"
          ]
        }
      }
    }]
  })
}