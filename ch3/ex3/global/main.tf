
variable "region" {
    description = "The AWS region to deploy resources in"
    default     = "eu-west-1"
    type        = string
}

provider "aws" {
    region = var.region
  
}

resource "random_string" "random" {
    length = 8
    special = false
    upper = false
  
}

resource "aws_s3_bucket" "backend_bucket" {
    bucket = "my-terraform-backend-bucket-${random_string.random.result}"
    force_destroy = true
  
}
resource "aws_s3_bucket_public_access_block" "public_access" {
    bucket = aws_s3_bucket.backend_bucket.id
  
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
  
}
resource "aws_s3_bucket_server_side_encryption_configuration" "s3_encryption" {
    bucket = aws_s3_bucket.backend_bucket.id
  
    rule {
        apply_server_side_encryption_by_default {
            sse_algorithm = "AES256"
        }
    }
  
}
resource "aws_s3_bucket_versioning" "enable" {
    bucket = aws_s3_bucket.backend_bucket.id
    versioning_configuration {
        status = "Enabled"
    }
}
resource "aws_dynamodb_table" "terraform_locks" {
    name         = "backend_locks-${random_string.random.result}"
    billing_mode = "PAY_PER_REQUEST"
    hash_key     = "LockID"

    attribute {
        name = "LockID"
        type = "S"
    }
  
}
resource "local_file" "backend_config" {
content = <<EOF
bucket = "${aws_s3_bucket.backend_bucket.bucket}"
region = "${var.region}"
encrypt = true
dynamodb_table = "${aws_dynamodb_table.terraform_locks.name}"
EOF

filename = "./backend_config.hcl"
}