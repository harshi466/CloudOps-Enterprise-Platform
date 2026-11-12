# ---------- Module 2: Object storage + lifecycle ----------
resource "aws_s3_bucket" "receipts" {
  bucket = "${local.name}-receipts-${data.aws_caller_identity.me.account_id}"
}

resource "aws_s3_bucket" "datalake" {
  bucket = "${local.name}-datalake-${data.aws_caller_identity.me.account_id}"
}

locals {
  buckets = { receipts = aws_s3_bucket.receipts.id, datalake = aws_s3_bucket.datalake.id }
}

resource "aws_s3_bucket_public_access_block" "all" {
  for_each                = local.buckets
  bucket                  = each.value
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "all" {
  for_each = local.buckets
  bucket   = each.value
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_versioning" "receipts" {
  bucket = aws_s3_bucket.receipts.id
  versioning_configuration { status = "Enabled" }
}

# Encryption in transit: deny any non-TLS request
resource "aws_s3_bucket_policy" "tls_only" {
  for_each = { receipts = aws_s3_bucket.receipts, datalake = aws_s3_bucket.datalake }
  bucket   = each.value.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [each.value.arn, "${each.value.arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })
}

# Lifecycle: Standard -> Standard-IA (30d) -> Glacier (90d) -> expire (365d)
resource "aws_s3_bucket_lifecycle_configuration" "receipts" {
  bucket = aws_s3_bucket.receipts.id
  rule {
    id     = "archive-receipts"
    status = "Enabled"
    filter {}
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    transition {
      days          = 90
      storage_class = "GLACIER"
    }
    expiration { days = 365 }
    noncurrent_version_expiration { noncurrent_days = 30 }
    abort_incomplete_multipart_upload { days_after_initiation = 7 }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "datalake" {
  bucket = aws_s3_bucket.datalake.id
  rule {
    id     = "archive-events"
    status = "Enabled"
    filter { prefix = "events/" }
    transition {
      days          = 60
      storage_class = "GLACIER"
    }
  }
}

resource "aws_s3_bucket_cors_configuration" "receipts" {
  bucket = aws_s3_bucket.receipts.id
  cors_rule {
    allowed_methods = ["PUT"]
    allowed_origins = ["*"]
    allowed_headers = ["*"]
    max_age_seconds = 300
  }
}

# Storage trigger -> Lambda
resource "aws_s3_bucket_notification" "receipts" {
  bucket = aws_s3_bucket.receipts.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.receipt_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "receipts/"
  }
  depends_on = [aws_lambda_permission.s3_invoke]
}
