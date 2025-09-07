output "data_lake_bucket_id" {
  description = "ID of the data lake S3 bucket"
  value       = aws_s3_bucket.data_lake.id
}

output "data_lake_bucket_arn" {
  description = "ARN of the data lake S3 bucket"
  value       = aws_s3_bucket.data_lake.arn
}

output "processed_data_bucket_id" {
  description = "ID of the processed data S3 bucket"
  value       = aws_s3_bucket.processed.id
}

output "processed_data_bucket_arn" {
  description = "ARN of the processed data S3 bucket"
  value       = aws_s3_bucket.processed.arn
}

output "artifacts_bucket_id" {
  description = "ID of the artifacts S3 bucket"
  value       = aws_s3_bucket.artifacts.id
}

output "artifacts_bucket_arn" {
  description = "ARN of the artifacts S3 bucket"
  value       = aws_s3_bucket.artifacts.arn
}