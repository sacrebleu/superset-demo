data "aws_region" "deployment_region" {
  name = local.region
}

data "aws_availability_zones" "available" {}

data "aws_caller_identity" "current" {}

locals {
  oidc_provider_id = "C4516BD4093B4AC403BED3255F3550A6"
  region          = "eu-west-1" // ireland for convenience
  cluster_name    = "Superset-demo"
  oidc_provider   = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/oidc.eks.${local.region}.amazonaws.com/id/${local.oidc_provider_id}"
}

data aws_eks_cluster superset_cluster {
  name = local.cluster_name
}