##############################################
# OUTPUT: BUCKET NAMES
##############################################

output "bucket_names" {
  description = "Names of all data lake buckets"
  value       = [for b in aws_s3_bucket.data_lake : b.bucket]
}

##############################################
# OUTPUT: BUCKET ARNs
##############################################

output "bucket_arns" {
  description = "ARNs of all data lake buckets"
  value       = [for b in aws_s3_bucket.data_lake : b.arn]
}



output "raw_bucket_name" {
  description = "Raw bucket name"
  value       = aws_s3_bucket.data_lake["raw"].bucket
}

output "processed_bucket_name" {
  description = "Processed bucket name"
  value       = aws_s3_bucket.data_lake["processed"].bucket
}

output "curated_bucket_name" {
  description = "Curated bucket name"
  value       = aws_s3_bucket.data_lake["curated"].bucket
}


output "athena_results_bucket" {
  value = aws_s3_bucket.athena_results.bucket
}