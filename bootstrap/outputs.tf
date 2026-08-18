output "state_bucket_name" {
  description = "Name of the private S3 bucket storing Terraform states."
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_arn" {
  description = "ARN of the private S3 bucket storing Terraform states."
  value       = aws_s3_bucket.terraform_state.arn
}
