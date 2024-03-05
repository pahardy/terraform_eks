#obtain the default VPC id
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default_subnets" {
  filter {
    name   = "vpc-id"
    values = [ data.aws_vpc.default.id ]
  }
}

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

  vpc_id = data.aws_vpc.default.id
  subnet_ids = data.aws_subnets.default_subnets.ids

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