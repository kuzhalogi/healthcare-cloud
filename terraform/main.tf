terraform {
  required_version = ">= 1.5.0"
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
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix for all resource names"
  type        = string
  default     = "healthcare-demo"
}

# Common tags applied to every resource so you can find and delete them easily
locals {
  tags = {
    Project   = var.project_name
    ManagedBy = "terraform"
    Purpose   = "portfolio-demo"
  }
}
