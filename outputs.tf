output "vpc_private_subnet_cidr" {
  description = "VPC private subnet CIDR"
  value       = module.vpc.private_subnets_cidr_blocks
}

output "vpc_public_subnet_cidr" {
  description = "VPC public subnet CIDR"
  value       = module.vpc.public_subnets_cidr_blocks
}

output "vpc_cidr" {
  description = "VPC CIDR"
  value       = module.vpc.vpc_cidr_block
}

output "outpost_subnets" {
  description = "List of IDs of outpost subnets"
  value       = module.vpc.outpost_subnets
}

output "outpost_subnets_cidr_blocks" {
  description = "List of cidr_blocks of outpost subnets"
  value       = module.vpc.outpost_subnets_cidr_blocks
}

output "eks_cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks_blueprints.eks_cluster_id
}

output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = module.eks_blueprints.configure_kubectl
}
