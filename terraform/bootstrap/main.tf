# ---------------------------------------------------------------------------
# Bootstrap: creates the S3 bucket and DynamoDB table that hold Terraform
# state for the main config. This stack keeps
# its own state locally and gets run once, by hand.
#
# Never destroy this while the main stack exists. You would lose the state
# file and orphan every resource in AWS.
# ---------------------------------------------------------------------------

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "healthcare"
}

data "aws_caller_identity" "current" {}

locals {
  bucket_name = "${var.project_name}-tfstate-${data.aws_caller_identity.current.account_id}"

  tags = {
    Project   = var.project_name
    Purpose   = "terraform-state"
    ManagedBy = "terraform"
  }
}

resource "aws_s3_bucket" "state" {
  bucket = local.bucket_name

  # No force_destroy. Deleting state by accident is unrecoverable.
  tags = local.tags
}

# Versioning is the safety net. A corrupted or truncated state file gets
# rolled back to the previous version.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# State contains resource IDs, ARNs, and sometimes secrets in plaintext.
# Encrypt it.
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "state_bucket" {
  value = aws_s3_bucket.state.id
}

# ---------------------------------------------------------------------------
# GitHub Actions OIDC. Lets the CI workflow assume an AWS role without any
# stored access keys. GitHub presents a signed token; AWS verifies it came
# from this specific repository before issuing temporary credentials.
# ---------------------------------------------------------------------------

variable "github_repo" {
  description = "GitHub repository allowed to assume the CI role, as owner/name."
  type        = string
}

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # GitHub's certificate thumbprint. AWS validates the TLS chain itself now,
  # so this value is vestigial, but the API still requires it.
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = local.tags
}

data "aws_iam_policy_document" "github_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Pins the trust to this repo. Without this condition, any GitHub
    # repository on the internet could assume the role.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${var.project_name}-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_assume.json

  tags = local.tags
}

# Plan-only permissions. CI reads infrastructure and reads/writes state.
# It cannot create, modify, or delete anything in AWS. An apply from CI
# would need a second, more privileged role and a manual approval gate.
data "aws_iam_policy_document" "github_plan" {
  statement {
    sid    = "ReadInfrastructure"
    effect = "Allow"
    actions = [
      "apigateway:GET",
      "cloudfront:Get*",
      "cloudfront:List*",
      "cloudwatch:Describe*",
      "cloudwatch:Get*",
      "cloudwatch:List*",
      "cognito-idp:Describe*",
      "cognito-idp:Get*",
      "cognito-idp:List*",
      "dynamodb:Describe*",
      "dynamodb:List*",
      "iam:Get*",
      "iam:List*",
      "kms:Describe*",
      "kms:Get*",
      "kms:List*",
      "lambda:Get*",
      "lambda:List*",
      "logs:Describe*",
      "logs:List*",
      "s3:Get*",
      "s3:List*",
      "sns:Get*",
      "sns:List*",
      "sts:GetCallerIdentity"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "TerraformState"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = ["${aws_s3_bucket.state.arn}/*"]
  }

  statement {
    sid       = "TerraformStateBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.state.arn]
  }
}

resource "aws_iam_role_policy" "github_plan" {
  name   = "${var.project_name}-github-plan"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_plan.json
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions.arn
}


