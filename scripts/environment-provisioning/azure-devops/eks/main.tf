terraform {
  backend "s3" {    
  }
}

provider "aws" {
  region     = var.region  
}

locals {
  cluster_name = var.cluster_name
  vpc_name = var.vpc_name
  vpc_cidr_block = var.vpc_cidr_block
  private_subnets = var.private_subnets
  public_subnets = var.public_subnets
  instance_type = var.instance_type

  existing_vpc_id = var.existing_vpc_id
  existing_vpc_private_subnets = var.existing_vpc_private_subnets
  
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token 
}

data "aws_availability_zones" "available" {

}

module "vpc" {
  count = (var.existing_vpc_id == "none" ? 1 : 0)
  source  = "terraform-aws-modules/vpc/aws"
  
  name                 = local.vpc_name
  cidr                 = local.vpc_cidr_block
  azs                  = data.aws_availability_zones.available.names
  private_subnets      = local.private_subnets
  public_subnets       = local.public_subnets
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "17.24.0"
  cluster_name    = local.cluster_name
  cluster_version = "1.20"

  vpc_id =  (var.existing_vpc_id == "none" ? module.vpc[0].vpc_id : local.existing_vpc_id)
  subnets = (var.existing_vpc_id == "none" ? module.vpc[0].private_subnets : local.existing_vpc_private_subnets)

  workers_group_defaults = {
    root_volume_type = "gp2"
  }

  worker_groups = [
    {
      name                          = "worker-group-1"
      instance_type                 = local.instance_type
      asg_desired_capacity          = 2
    },
    {
      name                          = "worker-group-2"
      instance_type                 = local.instance_type
      asg_desired_capacity          = 2
    },
  ]
}
