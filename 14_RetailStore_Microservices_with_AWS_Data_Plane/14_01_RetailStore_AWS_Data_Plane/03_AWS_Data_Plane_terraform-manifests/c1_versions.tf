terraform {
  # Minimum Terraform CLI version required
  required_version = ">= 1.10.5"

  # Required providers and version constraints
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.22"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.11"
    }
  }

  # Remote backend configuration using S3 
  backend "s3" {
    bucket         = "tfstate-dev-us-east-1-lqvonw"         
    key            = "retail-persistent-endpoints/dev/terraform.tfstate"            
    region         = "us-east-1"                            
    encrypt        = true                                   
    use_lockfile   = true     
  }
}

provider "aws" {
  # AWS region to use for all resources (from variables)
  region = var.aws_region
}


# Secondary provider specifically for Cart's DynamoDB table
provider "aws" {
  alias  = "west2"
  region = "us-west-2"
}


# Get EKS auth token
data "aws_eks_cluster_auth" "eks" {
  name = data.terraform_remote_state.eks.outputs.eks_cluster_name
}

# Kubernetes provider
provider "kubernetes" {
  alias                  = "eks"
  host                   = data.terraform_remote_state.eks.outputs.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.eks_cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.eks.token
}

# Helm provider

# ======================================
# Helm provider (uses Kubernetes provider)
# ======================================
provider "helm" {
  # Use the same Kubernetes cluster as above
  kubernetes = {
    config_path = "~/.kube/config" # optional; only if local kubeconfig is available
  }
}
