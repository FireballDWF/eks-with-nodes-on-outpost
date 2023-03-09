locals {
  name            = "filiatra-eks-outpost-tf"
  region          = "us-west-2"
  cluster_version = "1.25"
  instance_type   = "c6id.4xlarge"
  outposts_name   = "[Scout02 28 06292022]" 
  vpc_cidr        = "10.50.0.0/16"
  azs             = [data.aws_outposts_outpost.shared.availability_zone, "us-west-2a"] #slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Owner = "filiatra@amazon.com"
    GithubRepo = "https://github.com/FireballDWF/eks-with-nodes-on-outpost"
  }

  #---------------------------------------------------------------
  # ARGOCD ADD-ON APPLICATION
  #---------------------------------------------------------------

  addon_application = {
    path               = "chart"
    repo_url           = "https://github.com/sharepointoscar/ssp-eks-add-ons.git"
    add_on_application = true
  }

  #---------------------------------------------------------------
  # ARGOCD WORKLOAD APPLICATION
  #---------------------------------------------------------------

  workload_application = {
    path               = "envs/dev"
    repo_url           = "https://github.com/sharepointoscar/ssp-eks-workloads.git"
    add_on_application = false
  }
}