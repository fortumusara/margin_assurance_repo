output "pipeline_url" {
  description = "AWS Console URL to the newly created CodePipeline"
  value       = "https://${var.aws_region}.console.aws.amazon.com/codesuite/codepipeline/pipelines/${aws_codepipeline.margin_pipeline.name}/view"
}
