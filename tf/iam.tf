// user access role for the remote side
resource aws_iam_policy athena_access_policy {
  policy = <<EOF
{
	"Version": "2012-10-17",
	"Statement": [
		{
            "Sid": "listbuckets",
            "Effect": "Allow",
            "Action": ["s3:ListBucket"],
            "Resource": ["arn:aws:s3:::superset-demo-sacrebleu-data"]
        },
        {
            "Sid": "allowobjectmanipulation",
            "Effect": "Allow",
            "Action": [
                "s3:GetBucketLocation",
                "s3:GetObject",
                "s3:ListBucket",
                "s3:ListBucketMultipartUploads",
                "s3:ListMultipartUploadParts",
                "s3:AbortMultipartUpload",
                "s3:CreateBucket",
                "s3:PutObject"
            ],
            "Resource": [
              "arn:aws:s3:::superset-demo-sacrebleu-data",
              "arn:aws:s3:::superset-demo-sacrebleu-data/*"
            ]
        },
        {
			"Action": [
				"athena:ListDatabases",
                "athena:ListTableMetadata",
				"glue:GetDatabases",
                "glue:GetTables",
                "athena:GetTableMetadata",
                "glue:GetTable"
			],
			"Effect": "Allow",
			"Resource": [
				"arn:aws:athena:${local.region}:${data.aws_caller_identity.current.account_id}:*",
				"arn:aws:glue:${local.region}:${data.aws_caller_identity.current.account_id}:*"
			],
			"Sid": "dblist"
		},
		{
			"Sid": "athenaqueryexec",
			"Action": [
				"athena:GetQueryExecution",
				"athena:GetQueryExecutions",
				"athena:GetQueryResults",
				"athena:GetQueryResultsStream",
				"athena:GetQueryRuntimeStatistics",
				"athena:StartQueryExecution",
				"athena:StopQueryExecution"
			],
			"Effect": "Allow",
			"Resource": "arn:aws:athena:${local.region}:${data.aws_caller_identity.current.account_id}:workgroup/primary"
		},
		{
			"Sid": "kmsuse",
			"Action": [
				"kms:Decrypt",
				"kms:DescribeKey",
				"kms:Encrypt",
				"kms:GetKeyPolicy",
				"kms:GetKeyRotationStatus",
				"kms:GetParametersForImport",
				"kms:GetPublicKey",
				"kms:ListAliases",
				"kms:ListKeyPolicies",
				"kms:ListKeys",
				"kms:ReEncryptFrom",
				"kms:ReEncryptTo",
				"kms:ReplicateKey",
				"kms:Sign",
				"kms:TagResource",
				"kms:UntagResource",
				"kms:Verify",
				"kms:VerifyMac",
                "kms:GenerateDataKey"
			],
			"Effect": "Allow",
			"Resource": "arn:aws:kms:${local.region}:${data.aws_caller_identity.current.account_id}:*"
		}
	]
}
  EOF
  name = "superset-athena-access-policy"
}

resource aws_iam_role athena_access_role {
  name = "superset_athena_access_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
      {
        Action = "sts:AssumeRoleWithWebIdentity",
        Effect = "Allow",
        Sid = "SupersetPodAssumeRole",
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
      }
    ]
  })
}


// amend kms key policy

resource aws_iam_role_policy_attachment athena_role_policy_attachment {
  policy_arn = aws_iam_policy.athena_access_policy.arn
  role = aws_iam_role.athena_access_role.id
}