# S3 bucket for artifacts
resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket        = var.s3_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "codepipeline_bucket_versioning" {
  bucket = aws_s3_bucket.codepipeline_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# CodeStar Connection for GitHub
resource "aws_codestarconnections_connection" "github_connection" {
  name          = "github-connection"
  provider_type = "GitHub"
}

# SNS Topic for Deployment Notifications
resource "aws_sns_topic" "deployment_notifications" {
  name = "deployment-notifications"
}

# IAM Role for CodePipeline
resource "aws_iam_role" "codepipeline_role" {
  name = "MarginAssuranceCodePipelineRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "codepipeline.amazonaws.com"
      }
    }]
  })
}

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
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "codebuild.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codebuild_policy_attach" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeBuildDeveloperAccess"
}

# IAM Role for CodeDeploy
resource "aws_iam_role" "codedeploy_role" {
  name = "MarginAssuranceCodeDeployRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "codedeploy.amazonaws.com"
      }
    }]
  })
}

# IAM Policy for CodeDeploy
resource "aws_iam_policy" "codedeploy_policy" {
  name        = "MarginAssuranceCodeDeployPolicy"
  description = "Policy for CodeDeploy role"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Resource = "*"
      },
      {
        Action = [
          "codedeploy:CreateDeployment",
          "codedeploy:GetDeployment",
          "codedeploy:RegisterApplicationRevision",
          "codedeploy:GetApplication"
        ],
        Effect = "Allow",
        Resource = "*"
      },
      {
        Action = "sns:Publish",
        Effect = "Allow",
        Resource = aws_sns_topic.deployment_notifications.arn
      }
    ]
  })
}

# Attach the policy to CodeDeploy Role
resource "aws_iam_role_policy_attachment" "codedeploy_policy_attach" {
  role       = aws_iam_role.codedeploy_role.name
  policy_arn = aws_iam_policy.codedeploy_policy.arn
}

# CodeDeploy Application for Lambda
resource "aws_codedeploy_app" "lambda_app" {
  name             = "margin-assurance-lambda-application"
  compute_platform = "Lambda"
}

# CodeDeploy Deployment Group for Lambda
resource "aws_codedeploy_deployment_group" "lambda_deployment_group" {
  app_name              = aws_codedeploy_app.lambda_app.name
  deployment_group_name = "margin-assurance-lambda-deployment-group"
  service_role_arn      = aws_iam_role.codedeploy_role.arn

  deployment_style {
    deployment_type   = "BLUE_GREEN"
    deployment_option = "WITH_TRAFFIC_CONTROL"
  }

  deployment_config_name = "CodeDeployDefault.LambdaCanary10Percent5Minutes"

  trigger_configuration {
    trigger_name       = "DeploymentNotification"
    trigger_target_arn = aws_sns_topic.deployment_notifications.arn
    trigger_events     = [
      "DeploymentSuccess",
      "DeploymentFailure"
    ]
  }
}

# CodeBuild Project
resource "aws_codebuild_project" "build_project" {
  name         = "margin-assurance-build"
  service_role = aws_iam_role.codebuild_role.arn

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:4.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = false

    environment_variable {
      name  = "LAMBDA_FUNCTION_NAME"
      value = var.lambda_function_name  # Better to pass as a var
    }
  }

  source {
    type            = "GITHUB"
    location        = "https://github.com/${var.github_repo_full_name}.git"
    buildspec       = "buildspec.yml"
    git_clone_depth = 1
  }

  artifacts {
    type      = "S3"
    location  = aws_s3_bucket.codepipeline_bucket.bucket
    name      = "build_output"
    packaging = "ZIP"
    path      = "build_output/"
  }
}

# CodePipeline
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
        FullRepositoryId = var.github_repo_full_name
        BranchName       = var.github_branch
        DetectChanges    = "true"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "BuildAction"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]

      configuration = {
        ProjectName = aws_codebuild_project.build_project.name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name             = "DeployLambda"
      category         = "Deploy"
      owner            = "AWS"
      provider         = "CodeDeploy"
      version          = "1"
      input_artifacts  = ["build_output"]

      configuration = {
        ApplicationName     = aws_codedeploy_app.lambda_app.name
        DeploymentGroupName = aws_codedeploy_deployment_group.lambda_deployment_group.deployment_group_name
      }
    }
  }
}
