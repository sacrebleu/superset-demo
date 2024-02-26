// generate the data.tf bucket
resource aws_kms_key objects {
  description             = "KMS key is used to encrypt bucket objects"
  deletion_window_in_days = 7
}

module s3_bucket {
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

// populate the data.tf file into the bucket
resource aws_s3_object file_upload {
  bucket = module.s3_bucket.s3_bucket_id

  key    = "input/data.csv"
  source = "${path.module}/../dataset/source-data.csv"
  etag   = filemd5("${path.module}/../dataset/source-data.csv")
}

// create athena database and workgroup and bind them to the above S3 bucket
resource aws_glue_catalog_database superset_database {
  name = "superset-demo-data"

}

resource aws_glue_catalog_table superset_data_table {
  name          = "lottery_numbers"
  database_name = aws_glue_catalog_database.superset_database.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    classification="csv"
    "skip.header.line.count"="1"
    "typeOfData"="file"
  }

  storage_descriptor {
    location      = "s3://${module.s3_bucket.s3_bucket_id}/input/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      name = "my-store-serde"
      serialization_library = "org.apache.hadoop.hive.serde2.OpenCSVSerde"
      parameters = {
        "serialization.format" = 1
        "separatorChar"= ","

      }
    }

    columns {
      name = "draw_date"
      type = "string"
    }
    columns {
      name = "winning_numbers"
      type = "string"
    }
    columns {
      name = "mega_ball"
      type = "int"
    }
    columns {
      name = "multiplier"
      type = "string"
    }
  }
}
