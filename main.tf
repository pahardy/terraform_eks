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

#get the EBS CSI IAM policy
data "http" "ebs_csi_iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-ebs-csi-driver/master/docs/example-iam-policy.json"

  # Optional request headers
  request_headers = {
    Accept = "application/json"
  }
}

#Acquiring the policy from AWS
resource "aws_iam_policy" "ebs_csi_iam_policy" {
  name = "${var.aws_region}-AmazonEKS_EBS_CSI_Driver_Policy"
  description = "EBS CSI IAM Policy for the EKS cluster"
  path = "/"
  policy = data.http.ebs_csi_iam_policy.response_body
}

output "ebs_csi_iam_policy_arn" {
  value = aws_iam_policy.ebs_csi_iam_policy.arn
}

#Create an IAM role and associate it with the policy created above
resource "aws_iam_role" "ebs_csi_iam_role" {
  name = "${var.aws_region}-ebs-csi-iam-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Federated = "${module.eks.oidc_provider_arn}"
        }
        Condition = {
          StringEquals = {
            "${module.eks.oidc_provider_arn}:sub": "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          }
        }

      },
    ]
  })

  tags = {
    Environment = "terraform"
    Owner = "Patrick"
  }
}

# Associate EBS CSI IAM Policy to EBS CSI IAM Role
resource "aws_iam_role_policy_attachment" "ebs_csi_iam_role_policy_attach" {
  policy_arn = aws_iam_policy.ebs_csi_iam_policy.arn
  role       = aws_iam_role.ebs_csi_iam_role.name
}

output "ebs_csi_iam_role_arn" {
  description = "EBS CSI IAM Role ARN"
  value = aws_iam_role.ebs_csi_iam_role.arn
}

#Installation of EBS CSI addon
resource "aws_eks_addon" "ebs_eks_addon" {
  depends_on = [aws_iam_role_policy_attachment.ebs_csi_iam_role_policy_attach]
  cluster_name = module.eks.cluster_name
  addon_name   = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.ebs_csi_iam_role.arn 
}