variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix applied to every resource name."
  type        = string
  default     = "healthcare"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "dev"
}

variable "alert_email" {
  description = "Email address that receives CloudWatch alarm notifications."
  type        = string
}

variable "log_retention_days" {
  description = "How long CloudWatch keeps logs. Short by default to control cost."
  type        = number
  default     = 14
}

variable "local_dev_origins" {
  description = "Extra origins allowed through CORS. Set to [] for a production deploy."
  type        = list(string)
  default     = ["http://localhost:5173"]
}

