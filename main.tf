provider "aws" {
  region  = local.region
}

provider "kubernetes" {
  host                   = module.eks_blueprints.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_blueprints.eks_cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks_blueprints.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_blueprints.eks_cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

data "aws_availability_zones" "available" {}

data "aws_caller_identity" "current" {}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks_blueprints.eks_cluster_id
}

data "aws_outposts_outpost" "shared" {
  name = "[Scout02 28 06292022]"
}

locals {
  name            = "filiatra-eks-outpost-tf"
  region          = "us-west-2"
  cluster_version = "1.24"

  vpc_cidr = "10.50.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Owner = "filiatra@amazon.com"
    Blueprint  = local.name
    GithubRepo = "github.com/aws-ia/terraform-aws-eks-blueprints"
  }
}

#---------------------------------------------------------------
# EKS Blueprints
#---------------------------------------------------------------

module "eks_blueprints" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints"

  cluster_name    = local.name
  cluster_version = local.cluster_version

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets
  cluster_endpoint_private_access = true

  self_managed_node_groups = {
    self_outpost = {
      node_group_name    = "self-mng-outpost"
      subnet_ids         = module.vpc.outpost_subnets
      launch_template_os = "amazonlinux2eks"

      enable_monitoring = true

      custom_ami_id    = "ami-094a7f9c1df01b2c3"
      instance_type    = "c6id.4xlarge"
      desired_capacity = 3
      min_size         = 2
      max_size         = 5

      #block_device_mappings = [
      #  {
      #    device_name = "/dev/xvda"
      #    volume_type = "gp2"
      #    volume_size = 100
      #  }
      #]
    }
  }

  tags = local.tags
}

module "eks_blueprints_kubernetes_addons" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints/modules/kubernetes-addons"

  eks_cluster_id           = module.eks_blueprints.eks_cluster_id
  eks_cluster_endpoint     = module.eks_blueprints.eks_cluster_endpoint
  eks_oidc_provider        = module.eks_blueprints.oidc_provider
  eks_cluster_version      = module.eks_blueprints.eks_cluster_version
  auto_scaling_group_names = module.eks_blueprints.self_managed_node_group_autoscaling_groups

  # EKS Managed Add-ons
  enable_amazon_eks_vpc_cni            = true
  enable_amazon_eks_coredns            = true
  enable_amazon_eks_kube_proxy         = true
  #enable_amazon_eks_aws_ebs_csi_driver = true
  enable_metrics_server                = true
  enable_aws_load_balancer_controller  = true


  tags = local.tags
}

#---------------------------------------------------------------
# Supporting Resources
#---------------------------------------------------------------

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 10)]

  # Outpost is using single AZ specified in `outpost_az`
  outpost_subnets = ["10.50.80.0/24", "10.50.90.0/24"]
  outpost_arn     = data.aws_outposts_outpost.shared.arn
  outpost_az      = data.aws_outposts_outpost.shared.availability_zone

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  # Manage so we can name
  manage_default_network_acl    = true
  default_network_acl_tags      = { Name = "${local.name}-default" }
  manage_default_route_table    = true
  default_route_table_tags      = { Name = "${local.name}-default" }
  manage_default_security_group = true
  default_security_group_tags   = { Name = "${local.name}-default" }

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  outpost_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.tags
}
