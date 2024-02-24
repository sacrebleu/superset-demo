// generate the data bucket
resource "aws_kms_key" "objects" {
  description             = "KMS key is used to encrypt bucket objects"
  deletion_window_in_days = 7
}

module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = "superset-demo-sacrebleu-data"
  acl    = "private"

  control_object_ownership = true
  object_ownership         = "ObjectWriter"

  versioning = {
    enabled = true
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        kms_master_key_id = aws_kms_key.objects.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
}

resource "aws_s3_object" "file_upload" {
  bucket = module.s3_bucket.s3_bucket_id
  key    = "data"
  source = "${path.module}/../dataset/source-data.csv"
  etag   = filemd5("${path.module}/../dataset/source-data.csv")
}