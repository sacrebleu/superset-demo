data "aws_region" "deployment_region" {
  name = local.region
}

data "aws_availability_zones" "available" {}

data "aws_caller_identity" "current" {}

locals {
  name = "Superset-demo"
  tags = {
    app         = "Superset"
    provisioner = "Terraform"
    env         = "demo"
  }

  cluster_version = "1.29"
  region          = "eu-west-1" // ireland for convenience

  vpc_cidr = var.vpc_cidr_range
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)
}