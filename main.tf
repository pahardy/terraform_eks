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