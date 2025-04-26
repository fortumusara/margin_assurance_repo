provider "aws" {
  region = "us-east-1" # or your preferred region
}

# S3 Bucket for CodePipeline Artifacts
resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket = "margin-assurance-artifacts-bucket"

  force_destroy = true
}

# Enable Versioning for S3 Bucket
resource "aws_s3_bucket_versioning" "codepipeline_bucket_versioning" {
  bucket = aws_s3_bucket.codepipeline_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# CodeStar Connections for GitHub
resource "aws_codestarconnections_connection" "github_connection" {
  name          = "github-margin-conn"
  provider_type = "GitHub"
}

# IAM Role for CodePipeline
resource "aws_iam_role" "codepipeline_role" {
  name = "MarginAssuranceCodePipelineRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "codepipeline.amazonaws.com"
      }
    }]
  })
}

# IAM Role Policy Attachment for CodePipeline
resource "aws_iam_role_policy_attachment" "codepipeline_policy_attach" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodePipeline_FullAccess"
}

# IAM Role for CodeBuild
resource "aws_iam_role" "codebuild_role" {
  name = "MarginAssuranceCodeBuildRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "codebuild.amazonaws.com"
      }
    }]
  })
}

# IAM Role Policy Attachment for CodeBuild
resource "aws_iam_role_policy_attachment" "codebuild_policy_attach" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeBuildDeveloperAccess"
}

# CodeBuild Project
resource "aws_codebuild_project" "build_project" {
  name          = "margin-assurance-build"
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0" # Latest image
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
  }

  source {
    type = "CODEPIPELINE"
    buildspec = "buildspec.yml" # Assumes you have a buildspec.yml at repo root
  }
}

# CodePipeline Definition
resource "aws_codepipeline" "margin_pipeline" {
  name     = "margin-assurance-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "SourceFromGitHub"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.github_connection.arn
        FullRepositoryId = "${var.github_owner}/${var.github_repo}"
        BranchName       = var.github_branch
        DetectChanges    = "true"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "CodeBuild"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.build_project.name
      }
    }
  }
}
