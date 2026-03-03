terraform {
  required_version = ">= 1.3.0"

  required_providers {
     aws = {
      source  = "hashicorp/aws"
      version = ">= 5.30"
    }

    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.9.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20.0"
    }
  }


# Remote Backend
  backend "s3" {
    bucket         = "tfstate-dev-us-east-1-lqvonw"
    key            = "eks/dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    use_lockfile = true
  }  

} 



