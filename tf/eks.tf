################################################################################
# EKS Module
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  enable_irsa                    = true
  create_iam_role                = true

  cluster_name                   = local.name
  cluster_version                = local.cluster_version
  iam_role_name                  = "superset_cluster_role"
  cluster_endpoint_public_access = true

  enable_cluster_creator_admin_permissions = true

  create_kms_key = false

  cluster_encryption_config = {
    provider_key_arn = aws_kms_key.cluster_key.arn
    resources = [
      "secrets"
    ]
  }

  # Enable EFA support by adding necessary security group rules
  # to the shared node security group
  enable_efa_support = true

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent    = true
      before_compute = true
      configuration_values = jsonencode({
        env = {
          # Reference docs https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
    eks-pod-identity-agent = {
      most_recent = true
    }
  }

  vpc_id     = aws_vpc.demo_vpc.id
  subnet_ids = [for o in aws_subnet.demo_private_subnet : o.id]

  eks_managed_node_groups = {
    # Complete
    superset_demo = {
      name            = "demo-superset-nodegroup"
      use_name_prefix = true

      subnet_ids = [for o in aws_subnet.demo_private_subnet : o.id]

      min_size     = 1
      max_size     = 3
      desired_size = 3

      ami_id                     = data.aws_ami.eks_default.image_id
      enable_bootstrap_user_data = true

      capacity_type        = "SPOT"
      force_update_version = true
      instance_types       = ["t3a.medium", "t3.medium", "t2.medium"]
      labels = {
        GithubRepo = "terraform-aws-eks"
        GithubOrg  = "terraform-aws-modules"
      }

      update_config = {
        max_unavailable_percentage = 33 # or set `max_unavailable`
      }

      description = "EKS managed node group for superset demo"

      ebs_optimized           = true
      disable_api_termination = false
      enable_monitoring       = true

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 75
            volume_type           = "gp3"
            iops                  = 3000
            throughput            = 150
            delete_on_termination = true
          }
        }
      }

      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 2
        instance_metadata_tags      = "disabled"
      }

      iam_role_name            = "superset_nodegroup_role"
      iam_role_additional_policies = {
        EBCCSIPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }

      tags = local.tags
    }

  }

  tags = local.tags
}

resource "aws_security_group" "remote_access" {
  name_prefix = "${local.name}-remote-access"
  description = "Allow remote SSH access"
  vpc_id      = aws_vpc.demo_vpc.id

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(local.tags, { Name = "${local.name}-remote" })
}

data "aws_ami" "eks_default" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amazon-eks-node-${local.cluster_version}-v*"]
  }
}