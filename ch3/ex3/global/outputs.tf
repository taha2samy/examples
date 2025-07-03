output "bucket_name" {
  value       = aws_s3_bucket.backend_bucket.bucket
  description = "The name of the S3 bucket used for backend content"

}
output "region" {
  value       = var.region
  description = "The AWS region where the resources are deployed"

}

output "dynamodb_table" {
    value       = aws_dynamodb_table.terraform_locks.name
    description = "Indicates whether the S3 bucket is encrypted"
}
