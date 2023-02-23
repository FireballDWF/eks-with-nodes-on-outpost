module "kubernetes-addons" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints?ref=v4.21.0/modules/kubernetes-addons"

  eks_cluster_id       = module.eks.cluster_name
  eks_cluster_endpoint = module.eks.cluster_endpoint
  eks_oidc_provider    = ""
  eks_cluster_version  = module.eks.cluster_version

  #---------------------------------------------------------------
  # ARGO CD ADD-ON
  #---------------------------------------------------------------

  enable_argocd         = false
  argocd_manage_add_ons = true # Indicates that ArgoCD is responsible for managing/deploying Add-ons.
  argocd_applications = {
    addons    = local.addon_application
    #workloads = local.workload_application
  }

  argocd_helm_config = {
    #values = [templatefile("${path.module}/manifests/argocd-values.yaml", {})]
    version = "5.0.0"
  }

  #---------------------------------------------------------------
  # ADD-ONS - You can add additional addons here
  # https://aws-ia.github.io/terraform-aws-eks-blueprints/add-ons/
  #---------------------------------------------------------------
  enable_aws_load_balancer_controller  = false
  enable_amazon_eks_aws_ebs_csi_driver = false
  enable_aws_for_fluentbit            = false
  enable_cert_manager                 = false
  enable_cluster_autoscaler           = false
  enable_ingress_nginx                = false
  enable_keda                         = false
  enable_metrics_server               = false
  enable_prometheus                   = false
  enable_traefik                      = false
  enable_vpa                          = false
  enable_yunikorn                     = false
  enable_argo_rollouts                = false
  enable_promtail                     = false
  enable_karpenter                    = false
  enable_calico                       = false
  enable_grafana                      = false
} 
