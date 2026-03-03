# Optional since we already init helm provider (just to make it self contained)
data "aws_eks_cluster" "eks_v2" {
  name = aws_eks_cluster.main.name
}

# Optional since we already init helm provider (just to make it self contained)
data "aws_eks_cluster_auth" "eks_v2" {
  name = aws_eks_cluster.main.name
}

# provider "kubernetes" {
#   host                   = data.aws_eks_cluster.eks_v2.endpoint
#   cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks_v2.certificate_authority[0].data)
#   token                  = data.aws_eks_cluster_auth.eks_v2.token
# }

# provider "helm" {
#   kubernetes = {
#     host                   = data.aws_eks_cluster.eks_v2.endpoint
#     cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks_v2.certificate_authority[0].data)
#     token                  = data.aws_eks_cluster_auth.eks_v2.token
#   }
# }

resource "kubernetes_storage_class_v1" "efs" {
  metadata {
    name = "efs"
  }

  storage_provisioner = "efs.csi.aws.com"

  parameters = {
    provisioningMode = "efs-ap"
    fileSystemId     = aws_efs_file_system.data.id
    directoryPerms   = "700"
  }

  mount_options = ["iam"]

  depends_on = [helm_release.efs_csi]
}


resource "helm_release" "efs_csi" {
  name       = "aws-efs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-efs-csi-driver"
  chart      = "aws-efs-csi-driver"
  version    = "3.4.0" # use latest stable version
  namespace  = "kube-system"

  set = [
  {
    name  = "controller.serviceAccount.create"
    value = "true"
  },
  {
    name  = "controller.serviceAccount.name"
    value = "efs-csi-controller-sa"
  },

 {
  name  = "controller.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
  value = module.efs_csi_irsa_role.iam_role_arn
}
]
}



data "aws_subnet" "private" {
  for_each = toset(data.terraform_remote_state.vpc.outputs.private_subnet_ids)
  id       = each.value
}

locals {
  private_subnets_cidr_blocks = [
    for s in data.aws_subnet.private : s.cidr_block
  ]
}



resource "aws_efs_file_system" "data" {

  creation_token = "cluster_name-data"
  tags = {
    Name = "eks.cluster_name-data"
  }
}

resource "aws_efs_mount_target" "data" {
  count           = length(data.terraform_remote_state.vpc.outputs.private_subnet_ids)
  file_system_id  = aws_efs_file_system.data.id
  subnet_id       = data.terraform_remote_state.vpc.outputs.private_subnet_ids[count.index]
  security_groups = [aws_security_group.allow-efs.id]
}

resource "aws_security_group" "allow-efs" {
  name        = "cluster_name-allow-efs-sg"
  description = "Allow EFS access for EKS cluster."
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = local.private_subnets_cidr_blocks
  }

  tags = {
    Name = "Allow EFS access for cluster_name"
  }
}

module "efs_csi_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.19.0"

  role_name = "efs-csi-irsa-role"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true
  attach_efs_csi_policy = true

  oidc_providers = {
    one = {
      provider_arn               = local.oidc_provider_arn
      namespace_service_accounts = ["kube-system:efs-csi-controller-sa"]
    }
  }

  
}

