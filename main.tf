 provider "aws" {
  region = ""
}

terraform {
  backend "s3" {
    bucket = ""
    key    = ""
    region = ""
  }
}

provider "kubernetes" {
  host                   = module.eks_blueprints.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_blueprints.eks_cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks_blueprints.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_blueprints.eks_cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", "", "--profile", "", "--region", "" ]
      command     = "aws"
    }
  }
}

locals {
  tags = {
    Terraform  = "True"
    GithubRepo = "github.com/aws-ia/terraform-aws-eks-blueprints"
    Name       = ""
  }
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks_blueprints.eks_cluster_id
}

############################################################################
########################  EKS cluster  module  #############################
############################################################################
module "eks_blueprints" {
  source             = "github.com/aws-ia/terraform-aws-eks-blueprints?ref=v4.25.0"
  cluster_name       = ""
  cluster_version    = ""
  vpc_id             = ""
  
  private_subnet_ids = ["", ""]
  cluster_security_group_additional_rules = {
    ingress_for-vpc-cidr-api = {
      description = "VPC CIDR to K8s API"
      protocol    = "tcp"
      from_port   = 0
      to_port     = 443
      type        = "ingress"
      cidr_blocks = [""]
    }
  }
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true
  enable_cluster_encryption       = false
  /* ingress_vpn = {
            description                   = "Access from VPN"
            protocol                      = "tcp"
            from_port                     = 80
            to_port                       = 80
            type                          = "ingress"
            cidr_blocks = [""]
        }

    } */
  create_cloudwatch_log_group = true
  cluster_enabled_log_types   = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  create_iam_role      = true
  iam_role_name        = ""
  iam_role_description = "Role used by the  cluster"

  managed_node_groups = {
    node = {
      node_group_name = "managed-ondemand"
      disk_size       = 50
     # disk_type       = gp3
      min_size        = 1
      desired_size    = 5
      max_size        = 14
      /* ami_type              = "BOTTLEROCKET_x86_64"
            launch_template_os    = "bottlerocket" */
      instance_types = ["c5.xlarge", "m5.xlarge"]
      k8s_labels = {
        Environment = ""
      }
    }
  }

  map_roles = [
        {
            rolearn  = ""
            username = ""
            groups   = ["system:bootstrappers", "system:nodes"]
        },
        {
            rolearn  = ""
            username = ""
            groups   = ["system:admins", "system:masters"]
        },
        {
            rolearn  = ""
            username = ""
            groups   = ["system:masters", "system:admins","system:nodes","system:bootstrappers"]
        },
        {
            rolearn  = ""
            username = ""
            groups   = ["system:bootstrappers", "system:nodes", "system:masters", "system:admins"]
        },
        {
            rolearn  = ""
            username = ""
            groups   = ["system:bootstrappers", "system:nodes"]
        },
        {
            rolearn  = ""
            username = ""
            groups   = ["system:masters"]
        }
    ]
    
  tags = local.tags
  enable_irsa = true

}

data "aws_eks_node_group" "node" {
  cluster_name    = module.eks_blueprints.eks_cluster_id
  node_group_name = split(":", module.eks_blueprints.managed_node_groups[0].node.managed_nodegroup_id[0])[1]
}

resource "aws_autoscaling_group_tag" "node" {
  autoscaling_group_name = data.aws_eks_node_group.node.resources[0].autoscaling_groups[0].name

  tag {
    key                 = "Name"
    value               = data.aws_eks_node_group.node.tags.Name
    propagate_at_launch = true
  }
}

############################################################################
########################  EKS cluster  addons  #############################
############################################################################
module "eks_blueprints_kubernetes_addons" {
    source = "github.com/aws-ia/terraform-aws-eks-blueprints//modules/kubernetes-addons"

    eks_cluster_id               = module.eks_blueprints.eks_cluster_id
    eks_cluster_endpoint         = module.eks_blueprints.eks_cluster_endpoint
    eks_cluster_version          = module.eks_blueprints.eks_cluster_version
    eks_worker_security_group_id = module.eks_blueprints.worker_node_security_group_id


    # EKS Managed Add-ons
    enable_amazon_eks_vpc_cni            = false
    enable_amazon_eks_coredns            = true
    enable_amazon_eks_kube_proxy         = true
    /* enable_amazon_eks_aws_ebs_csi_driver = true */

    # Add-ons
    enable_aws_load_balancer_controller = true
    aws_load_balancer_controller_helm_config = {
        namespace = "kube-system"
        version   = "1.4.7"
    }

    enable_ingress_nginx = true
    ingress_nginx_helm_config = {
        namespace = "kube-system"
        version = "4.5.2"
    }
    
    enable_metrics_server   = true
    metrics_server_helm_config = {
        namespace = "kube-system"
    }
}

resource "kubernetes_namespace" "this" {
  metadata {
    name = ""
  }
}
