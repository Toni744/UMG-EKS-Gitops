include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env      = local.env_vars.locals.environment
}

terraform {
  source = "../../modules/eks"
}

inputs = {
  cluster_name   = "automate-cluster-${local.env}"
  environment    = local.env
  aws_region     = local.env_vars.locals.region

  # Cost-optimized HA setup — cheaper instances, fewer nodes
  instance_types  = ["t3a.small"]
  desired_size    = 1
  min_size        = 1
  max_size        = 2

  single_nat_gateway = true   # Cost savings over per-AZ NAT GWs
}