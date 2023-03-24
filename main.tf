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
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]   #TODO: determine if can use prefix list, or at least restrict to my ISP

  vpc_id     = module.vpc.vpc_id
  control_plane_subnet_ids = module.vpc.public_subnets
  subnet_ids = module.vpc.private_subnets
  
   self_managed_node_groups = {
    
    outpost = {
      name = local.name

      min_size      = 2
      max_size      = 5
      desired_size  = 2
      instance_type = local.instance_type
      enable_monitoring = true
  
      launch_template_name            = "self-managed-ex-outposts-servers-v2"
      launch_template_use_name_prefix = true
      launch_template_description     = "Self managed node group example for outposts servers launch template"

      #ami_id    = "ami-0a1c44441afe98327" #RHEL 8.4 # al2 "ami-094a7f9c1df01b2c3"
 
      #bootstrap_extra_args = <<-EOT
      #  --container-runtime containerd 
      #EOT

      #pre_bootstrap_user_data = <<-EOT

      #EOT

      post_bootstrap_user_data = <<-EOT
      export TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
      export INSTANCEID=`curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id`
      NetworkInterfaceId=`aws ec2 create-network-interface --description "LNI" --subnet-id ${module.vpc.outpost_subnets[1]} --tag-specifications 'ResourceType=network-interface,Tags=[{Key=node.k8s.amazonaws.com/no_manage,Value=true},{Key=multus,Value=true},{Key=cluster,Value=${module.eks.cluster_name}},{Key=Zone,Value=${data.aws_outposts_outpost.shared.availability_zone}},{Key=Name,Value=LNI of '$INSTANCEID'},{Key=Owner,Value=filiatra@amazon.com}]' --output text --query 'NetworkInterface.NetworkInterfaceId'`
      echo "Created LNI $NetworkInterfaceId"
      aws ec2 attach-network-interface  --device-index 1 --network-interface-id $NetworkInterfaceId --instance-id $INSTANCEID
      /bin/yum install -y amazon-cloudwatch-agent
      /bin/curl https://ams-configuration-artifacts-us-west-2.s3.us-west-2.amazonaws.com/configurations/cloudwatch/latest/linux-cloudwatch-config.json -o /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.d/ams-accelerate-config.json
      /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.d/ams-accelerate-config.json
      cat <<-EOF > /etc/sysconfig/network-scripts/ifcfg-eth1
      DEVICE=eth1
      TYPE=ETHERNET
      ONBOOT=yes
      BOOTPROTO=dhcp
      DEFROUTE=no
      IPV4_FAILURE_FATAL=no
      IPV6INIT=no
      NM_CONTROLLED=no
      PEERDNS=no
      EC2SYNC=no
      EOF

      cat <<-EOF > /var/lib/cloud/scripts/per-boot/lni-setup.sh
      /sbin/dhclient -r -lf /var/lib/dhclient/dhclient--eth1.lease -pf /var/run/dhclient-eth1.pid eth1
      /usr/sbin/ifconfig eth1 down
      /sbin/ip addr flush eth1
      /sbin/ifup eth1
      /sbin/iptables -t nat -I POSTROUTING -j RETURN -d 192.168.0.0/22
      EOF
      chmod +x /var/lib/cloud/scripts/per-boot/lni-setup.sh
      /var/lib/cloud/scripts/per-boot/lni-setup.sh
      EOT
      # TODO: for reuse CIDR block in above iptables line needs to be dynamically looked up (or parameterized)

      subnet_ids = [module.vpc.outpost_subnets[0]]
      network_interfaces = [
        {
          description                 = "ENI"
          delete_on_termination       = true
          device_index                = 0
          associate_public_ip_address = false
          #subnet_id                   = module.vpc.outpost_subnets[0]
        }
      ]
      
      timeouts = {
        create = "80m"
        update = "80m"
        delete = "80m"
      }    
      tags = {
        ExtraTag = "Self managed node group for Outposts Servers Extended Clusters"
      }     
    }

  }

  # Local clusters will automatically add the node group IAM role to the aws-auth configmap
  # TODO: test if following are still needed
  create_aws_auth_configmap = true
  manage_aws_auth_configmap = true
  aws_auth_roles = [
  #  data.aws_outposts_outpost.shared.arn,
    { 
      rolearn = data.aws_caller_identity.current.arn
      username = "role1"
      groups = ["system:masters"]
    }
  ]

  aws_auth_accounts = [
    data.aws_caller_identity.current.account_id
  ]

 cluster_addons = {

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
  
  node_security_group_additional_rules = {
    ingress_http = {
      description = "Node port 80"
      protocol    = "tcp"
      from_port   = 80
      to_port     = 80
      type        = "ingress"
      cidr_blocks = [local.vpc_cidr, "192.168.0.0/16"]
    }
    ingress_icmp = {
      description = "Node icmp"
      protocol    = "icmp"
      from_port   = -1
      to_port     = -1
      type        = "ingress"
      cidr_blocks = [local.vpc_cidr, "192.168.0.0/16"]
    }
  }

  # Self Managed Node Group(s)
  self_managed_node_group_defaults = {
    update_launch_template_default_version = true
    iam_role_additional_policies = {
      AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",  
      AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
      CloudWatchAgentServerPolicy  = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  #    additional = data.aws_iam_policy.AWSLoadBalancerControllerIAMPolicy.arn
    }
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
  version = ">= 3.19.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 10)]

  # Outpost is using single AZ specified in `outpost_az`
  outpost_subnets = ["10.50.80.0/20", "10.50.96.0/20"]
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

  enable_flow_log                      = true
  create_flow_log_cloudwatch_iam_role  = true
  create_flow_log_cloudwatch_log_group = true
  
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
    "kubernetes.io/cluster/${local.name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    "kubernetes.io/cluster/${local.name}" = "shared"
  }

  outpost_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    "kubernetes.io/cluster/${local.name}" = "shared"
  }

  tags = local.tags
}

# Required for Outposts Servers to enable LNI behavior per https://docs.aws.amazon.com/outposts/latest/server-userguide/local-network-interface.html#enable-lni
resource "null_resource" "outpost_server_subnets" {
  provisioner "local-exec" {
    command = "aws ec2 modify-subnet-attribute --subnet-id ${module.vpc.outpost_subnets[1]} --enable-lni-at-device-index 1"
  }
}

resource "null_resource" "update_kubeconfig" {
  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${local.region}"
  }
}

# yaml sources
# https://raw.githubusercontent.com/metallb/metallb/v0.13.9/config/manifests/metallb-native.yaml
# https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/master/config/multus/v3.9.2-eksbuild.1/aws-k8s-multus.yaml
# https://github.com/k8snetworkplumbingwg/reference-deployment/blob/master/multus-dhcp/dhcp-daemonset.yml

data "kubectl_path_documents" "multus" {
    pattern = "./manifests/aws-k8s-multus.yaml"
}
resource "kubectl_manifest" "multus_manifests" {
    depends_on = [ module.eks ]  
    for_each  = toset(data.kubectl_path_documents.multus.documents)
    yaml_body = each.value
}

data "kubectl_path_documents" "metallb" {
    pattern = "./manifests/metallb-native.yaml"
}
resource "kubectl_manifest" "metallb_manifests" {
    depends_on = [ module.eks ]  
    for_each  = toset(data.kubectl_path_documents.metallb.documents)
    yaml_body = each.value
}

data "kubectl_path_documents" "lni" {
    pattern = "./manifests/lni.yaml"
}
resource "kubectl_manifest" "lni_manifests" {
    depends_on = [ kubectl_manifest.multus_manifests ]  
    for_each  = toset(data.kubectl_path_documents.lni.documents)
    yaml_body = each.value
}

data "kubectl_path_documents" "metallb_pool" {
    pattern = "./manifests/metallb-l2-pool.yaml"
}
resource "kubectl_manifest" "metallb_pool_manifests" {
    depends_on = [ kubectl_manifest.metallb_manifests ]  
    for_each  = toset(data.kubectl_path_documents.metallb_pool.documents)
    yaml_body = each.value
}

data "kubectl_path_documents" "dhcp" {
    pattern = "./manifests/metallb-l2-pool.yaml"
}
resource "kubectl_manifest" "dhcp_manifests" {
    depends_on = [ kubectl_manifest.lni_manifests ]  
    for_each  = toset(data.kubectl_path_documents.dhcp.documents)
    yaml_body = each.value
}

data "kubectl_path_documents" "nginx" {
    pattern = "./manifests/nginx.yaml"
}

resource "kubectl_manifest" "nginx_manifests" {
    depends_on = [ kubectl_manifest.metallb_pool_manifests, kubectl_manifest.dhcp_manifests ]  
    for_each  = toset(data.kubectl_path_documents.nginx.documents)
    yaml_body = each.value
}

# does not appear to be needed anymore
#resource "null_resource" "create_memberlist" {
#  depends_on = [ kubectl_manifest.metallb_manifests ]  
#  provisioner "local-exec" {
#    command = "kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey=\"$(openssl rand -base64 128)\""
#  }
#}
