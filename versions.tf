terraform {
  required_version = ">= 1.0.1"

  required_providers {
  
  # just inherit from terraform-aws-eks module
  #  aws = {
  #    source  = "hashicorp/aws"
  #    version = ">= 4.47"
  #  }

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14"
    }
  }
}
