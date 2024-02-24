// user access role for the remote side
resource aws_iam_policy athena_access_policy {
  policy = <<EOF
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Sid": "s3global",
			"Action": "s3:*",
			"Effect": "Allow",
			"Resource": "arn:aws:s3:::superset-demo-sacrebleu"
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
			"Resource": "arn:aws:athena:eu-west-1:249331700140:workgroup/*"
		},
		{
			"Sid": "eksglobal",
			"Action": "eks:*",
			"Effect": "Allow",
			"Resource": "arn:aws:eks:eu-west-1:249331700140:eks/*"
		},
		{
			"Sid": "kmsuse",
			"Action": [
				"kms:CreateAlias",
				"kms:CreateKey",
				"kms:Decrypt",
				"kms:DescribeCustomKeyStores",
				"kms:DescribeKey",
				"kms:Encrypt",
				"kms:GetKeyPolicy",
				"kms:GetKeyRotationStatus",
				"kms:GetParametersForImport",
				"kms:GetPublicKey",
				"kms:ListAliases",
				"kms:ListGrants",
				"kms:ListKeyPolicies",
				"kms:ListKeys",
				"kms:ListResourceTags",
				"kms:ListRetirableGrants",
				"kms:ReEncryptFrom",
				"kms:ReEncryptTo",
				"kms:ReplicateKey",
				"kms:Sign",
				"kms:TagResource",
				"kms:UntagResource",
				"kms:Verify",
				"kms:VerifyMac"
			],
			"Effect": "Allow",
			"Resource": "arn:aws:kms:eu-west-1:249331700140:*"
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
    ]
  })
}

resource aws_iam_role_policy_attachment athena_role_policy_attachment {
  policy_arn = aws_iam_policy.athena_access_policy.arn
  role = aws_iam_role.athena_access_role.id
}

// deployment role for gitops / automation
#resource aws_iam_role deploy_role {
#
#}

// data ingestion role that will upload the dataset into the S3 bucket - ruby app for simplicity


// superset access to athena + s3