// user access role for the remote side
#resource aws_iam_role user_access_role {
#
#}

// deployment role for gitops / automation
#resource aws_iam_role deploy_role {
#
#}

// data ingestion role that will upload the dataset into the S3 bucket - ruby app for simplicity


// superset access to athena + s3