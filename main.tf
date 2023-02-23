provider "aws" {
  region  = local.region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", local.region]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", local.region]
    }
  }
}

provider "kubectl" {
  apply_retry_count      = 10
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", local.region]
  }
}

################################################################################
# EKS Module
################################################################################

module "eks" {
  source = "github.com/terraform-aws-modules/terraform-aws-eks"

  cluster_name    = local.name
  cluster_version = local.cluster_version

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]

  vpc_id     = module.vpc.vpc_id
  control_plane_subnet_ids = module.vpc.public_subnets
  subnet_ids = module.vpc.private_subnets

  self_managed_node_groups = {
    
    outpost = {
      name = local.name

      min_size      = 1
      max_size      = 5
      desired_size  = 1
      instance_type = local.instance_type
      enable_monitoring = true
      launch_template_os = "amazonlinux2eks"
      subnet_ids         = module.vpc.outpost_subnets
      #custom_ami_id    = "ami-0b0af3577fe5e3532" #RHEL 8.4 # al2 "ami-094a7f9c1df01b2c3"
      # must align with device-name in ami
      # for RHEL, use /dev/sda1
      #block_device_mappings = [
      #  {
      #    device_name = "/dev/sda1"
      #    volume_type = "gp2"
      #    volume_size = 20
      #  }
      #]
      # currently not using LocalClusters, so following is commented out
      # Additional information is required to join local clusters to EKS
      bootstrap_extra_args = <<-EOT
        --container-runtime containerd 
      EOT
    }

  }

  # Local clusters will automatically add the node group IAM role to the aws-auth configmap
  create_aws_auth_configmap = true
  manage_aws_auth_configmap = true
  aws_auth_node_iam_role_arns_non_windows = [
    data.aws_outposts_outpost.shared.arn,
    data.aws_caller_identity.current.arn
  ]

 cluster_addons = {
    #coredns = {
    #  preserve    = true
    #  most_recent = true

    #  timeouts = {
    #    create = "25m"
    #    delete = "10m"
    #  }
    #}
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }
  # Extend cluster security group rules
  cluster_security_group_additional_rules = {
    ingress_vpc_https = {
      description = "Remote host to control plane"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      type        = "ingress"
      cidr_blocks = [local.vpc_cidr]
    }
  }

  # Self Managed Node Group(s)
  self_managed_node_group_defaults = {
  #  iam_role_additional_policies = {
  #    additional = data.aws_iam_policy.AWSLoadBalancerControllerIAMPolicy.arn
  #  }
    autoscaling_group_tags = {
      "k8s.io/cluster-autoscaler/enabled" : true,
      "k8s.io/cluster-autoscaler/${local.name}" : "owned",
    }
    instance_refresh = {
      strategy = "Rolling"
      preferences = {
        min_healthy_percentage = 66
      }
    }
  }

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
