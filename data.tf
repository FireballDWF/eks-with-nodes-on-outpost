data "aws_availability_zones" "available" {}

data "aws_caller_identity" "current" {}

data "aws_outposts_outpost" "shared" {
  name = local.outposts_name
}

#data "aws_iam_policy" "AWSLoadBalancerControllerIAMPolicy" {
#  name = "AWSLoadBalancerControllerIAMPolicy"
#}
