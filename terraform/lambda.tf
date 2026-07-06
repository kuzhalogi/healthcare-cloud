# Package each Lambda source folder into a zip at apply time
data "archive_file" "patient" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/patient"
  output_path = "${path.module}/build/patient.zip"
}

data "archive_file" "appointment" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/appointment"
  output_path = "${path.module}/build/appointment.zip"
}

data "archive_file" "records" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/records"
  output_path = "${path.module}/build/records.zip"
}

resource "aws_lambda_function" "patient" {
  function_name    = "${var.project_name}-patient"
  filename         = data.archive_file.patient.output_path
  source_code_hash = data.archive_file.patient.output_base64sha256
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  role             = aws_iam_role.lambda.arn
  timeout          = 10

  environment {
    variables = {
      PATIENTS_TABLE = aws_dynamodb_table.patients.name
    }
  }

  tags = local.tags
}

resource "aws_lambda_function" "appointment" {
  function_name    = "${var.project_name}-appointment"
  filename         = data.archive_file.appointment.output_path
  source_code_hash = data.archive_file.appointment.output_base64sha256
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  role             = aws_iam_role.lambda.arn
  timeout          = 10

  environment {
    variables = {
      APPOINTMENTS_TABLE = aws_dynamodb_table.appointments.name
    }
  }

  tags = local.tags
}

resource "aws_lambda_function" "records" {
  function_name    = "${var.project_name}-records"
  filename         = data.archive_file.records.output_path
  source_code_hash = data.archive_file.records.output_base64sha256
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  role             = aws_iam_role.lambda.arn
  timeout          = 10

  environment {
    variables = {
      RECORDS_TABLE    = aws_dynamodb_table.records.name
      DOCUMENTS_BUCKET = aws_s3_bucket.documents.id
    }
  }

  tags = local.tags
}
