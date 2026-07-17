terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state bucket. The backend block is read at `terraform init`,
  # before variables or locals exist, so it cannot interpolate. The name is
  # hardcoded from the bootstrap output. The embedded account ID is not a
  # secret: AWS account IDs are semi-public (they appear in every ARN) and
  # grant no access on their own.
  backend "s3" {
    bucket       = "healthcare-tfstate-471112650617"
    key          = "healthcare/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region
}


# Common tags applied to every resource so you can find and delete them easily
locals {
  tags = {
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}
