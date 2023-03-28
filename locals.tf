locals {
  name            = "filiatra-eks-outpost-tf"
  region          = "us-west-2"
  cluster_version = "1.25"
  instance_type   = "c6id.4xlarge"
  outposts_name   = "[Scout02 28 06292022]" 
  vpc_cidr        = "10.50.0.0/16"
  local_network_cidr = "192.168.0.0/22"
  azs             = [data.aws_outposts_outpost.shared.availability_zone, "us-west-2a"] #slice(data.aws_availability_zones.available.names, 0, 3)
  cluster_endpoint_access = "pl-08dfb5b75e612d050"   # This is mine, everyone else must specify their own. 

  tags = {
    Owner = "filiatra@amazon.com"
  }

}