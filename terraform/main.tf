terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state. Values cannot be interpolated here, so the bucket name is
  # hardcoded. It comes from the bootstrap output.
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
