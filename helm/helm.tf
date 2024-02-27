// provisions resources into the eks cluster specified in eks.tf
provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

# ensure kubeconfig is updated with details for the cluster
resource "null_resource" "kubectl" {
  provisioner "local-exec" {
    command = "aws eks --region ${data.aws_region.deployment_region.name} update-kubeconfig --name ${data.aws_eks_cluster.superset_cluster.name}"
  }
}

resource helm_release nginx-ingress-controller {
  name = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"

  chart = "ingress-nginx"

  version = "4.9.1"

  depends_on = [null_resource.kubectl]
}

data aws_iam_role athena_access_role {
  name = "superset_athena_access_role"
}

resource "helm_release" "superset" {
  name       = "superset"
  repository = "https://apache.github.io/superset"
  chart      = "superset"

  version = "0.12.6"

  values = [
    templatefile("${path.module}/config/superset-values.yaml",
      {
        account_id = data.aws_caller_identity.current.account_id,
        rolename = data.aws_iam_role.athena_access_role.name
      })
  ]

  depends_on = [null_resource.kubectl]
}