variable "aws_region" {
  description = "AWS Region"
  default     = "us-east-1"
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket for storing CodePipeline artifacts"
}

variable "github_owner" {
  description = "GitHub organization or username"
}

variable "github_repo" {
  description = "GitHub repository name"
}

variable "github_branch" {
  description = "GitHub branch to build from"
  default     = "main"
}
