terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  common_tags = merge(
    var.tags,
    {
      Environment = var.environment
      ManagedBy   = "Terragrunt"
    }
  )
}

module "networking" {
  source = "./modules/networking"

  cluster_name       = var.cluster_name
  vpc_cidr           = var.vpc_cidr
  single_nat_gateway = var.single_nat_gateway
  enable_nat_gateway = var.enable_nat_gateway
  tags               = local.common_tags
}

module "iam" {
  source = "./modules/iam"

  cluster_name = var.cluster_name
  tags         = local.common_tags
}

module "cluster" {
  source = "./modules/cluster"

  cluster_name       = var.cluster_name
  kubernetes_version = var.kubernetes_version
  role_arn           = module.iam.cluster_role_arn
  subnet_ids         = concat(module.networking.public_subnet_ids, module.networking.private_subnet_ids)
  security_group_id  = module.networking.cluster_sg_id
  tags               = local.common_tags
}

module "node_group" {
  source = "./modules/node_group"

  cluster_name      = var.cluster_name
  node_role_arn     = module.iam.node_role_arn
  subnet_ids        = var.enable_nat_gateway ? module.networking.private_subnet_ids : module.networking.public_subnet_ids
  security_group_id = module.networking.node_sg_id
  instance_types    = var.instance_types
  desired_size      = var.desired_size
  min_size          = var.min_size
  max_size          = var.max_size
  tags              = local.common_tags

  depends_on = [module.cluster]
}

module "irsa" {
  source = "./modules/irsa"

  cluster_name            = var.cluster_name
  cluster_oidc_issuer_url = module.cluster.cluster_oidc_issuer_url
  aws_account_id          = data.aws_caller_identity.current.account_id
  tags                    = local.common_tags
}

