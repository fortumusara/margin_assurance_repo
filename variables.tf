#variables.tf
variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-2"
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket for storing CodePipeline artifacts"
  type        = string
}

variable "github_owner" {
  description = "GitHub organization or username"
  type        = string
}

variable "github_repo_full_name" {
  description = "GitHub repo in the format owner/repo"
  type        = string
}

variable "github_branch" {
  description = "GitHub branch to build from"
  type        = string
  default     = "main"
}

variable "github_oauth_token_secret_name" {
  description = "The name of the secret in Secrets Manager for the GitHub OAuth token"
  type        = string
}

variable "lambda_function_name" {
  description = "The name of the Lambda function to deploy."
  type        = string
}
