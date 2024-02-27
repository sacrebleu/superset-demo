resource "aws_kms_key" "cluster_key" {
  enable_key_rotation = true
  tags = {
    app         = "Superset"
    env         = "demo"
    provisioner = "Terraform"
  }
}


// amend the kms key policy for the cluster once it is built
resource "aws_kms_key_policy" "eks_cluster_policy" {
  key_id = aws_kms_key.cluster_key.id

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "Default",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "arn:aws:iam::249331700140:root"
        },
        "Action" : "kms:*",
        "Resource" : "*"
      },
      {
        "Sid" : "KeyAdministration",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "arn:aws:iam::249331700140:user/terraform"
        },
        "Action" : [
          "kms:Update*",
          "kms:UntagResource",
          "kms:TagResource",
          "kms:ScheduleKeyDeletion",
          "kms:Revoke*",
          "kms:ReplicateKey",
          "kms:Put*",
          "kms:List*",
          "kms:ImportKeyMaterial",
          "kms:Get*",
          "kms:Enable*",
          "kms:Disable*",
          "kms:Describe*",
          "kms:Delete*",
          "kms:Create*",
          "kms:CancelKeyDeletion"
        ],
        "Resource" : "*"
      },
      {
        "Sid" : "KeyUsage",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : module.eks.cluster_iam_role_arn
        },
        "Action" : [
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Encrypt",
          "kms:DescribeKey",
          "kms:Decrypt"
        ],
        "Resource" : "*"
      },
      {
        "Sid" : "KeyUsageRolw",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : aws_iam_role.athena_access_role.arn
        },
        "Action" : [
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Encrypt",
          "kms:DescribeKey",
          "kms:Decrypt"
        ],
        "Resource" : "*"
      },
      {
        "Sid" : "athenausage",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "athena.amazonaws.com"
        },
        "Action" : [
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Encrypt",
          "kms:DescribeKey",
          "kms:Decrypt"
        ],
        "Resource" : "*"
      }
    ]
  })
}