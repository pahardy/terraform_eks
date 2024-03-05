/*
Creates a VPC, EKS cluster, and EBS addon for persistent storage. Large contribution
from Terraform tutorial site: https://developer.hashicorp.com/terraform/tutorials/kubernetes/eks
*/

#Create a separate VPC for the EKS cluster
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "terraform-vpc"
  cidr = var.vpc_cidr

  azs = ["ca-central-1a", "ca-central-1b", "ca-central-1d"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
  enable_dns_hostnames = true

  tags = {
    Environment = "terraform"
    Owner = "Patrick"
  }
}

#Create the EKS cluster using the Terraform EKS module
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.5.0"

  cluster_name = "terraform-eks"
  cluster_version = "1.29"
  cluster_endpoint_public_access = true
  enable_cluster_creator_admin_permissions = true
  cluster_ip_family = "ipv4"

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  vpc_id = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    nodegroup1 = {
      name = "nodegroup1"
      instance_types = [ "m5.xlarge" ]
      min_size = 3
      max_size = 7
      desired_size = 5
    }
  }

  tags = {
    Environment = "terraform"
    Owner = "Patrick"
  }
}

/*
Add the EBS addon for persistent storage for pods/containers to be hosted in the EKS cluster
Large contribution here from Stacksimplify (via Udemy course):
https://github.com/stacksimplify/terraform-on-aws-eks/blob/main/18-EBS-CSI-Install-using-EKS-AddOn/02-ebs-addon-terraform-manifests/c4-01-ebs-csi-datasources.tf
*/

data "aws_iam_policy" "ebs_csi_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

module "irsa-ebs-csi" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "4.7.0"

  create_role                   = true
  role_name                     = "AmazonEKSTFEBSCSIRole-${module.eks.cluster_name}"
  provider_url                  = module.eks.oidc_provider
  role_policy_arns              = [data.aws_iam_policy.ebs_csi_policy.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
}

resource "aws_eks_addon" "ebs-csi" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.20.0-eksbuild.1"
  service_account_role_arn = module.irsa-ebs-csi.iam_role_arn
  tags = {
    "eks_addon" = "ebs-csi"
    "terraform" = "true"
  }
}