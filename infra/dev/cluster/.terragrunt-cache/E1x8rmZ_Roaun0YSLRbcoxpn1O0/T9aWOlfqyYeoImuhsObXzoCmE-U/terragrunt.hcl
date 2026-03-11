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
  cluster_name   = "umgapi-cluster-${local.env}"
  environment    = local.env
  aws_region     = local.env_vars.locals.region
  kubernetes_version = "1.29"

  # Cost-optimized for dev with adequate resources for addons
  instance_types  = ["t3a.medium"]
  desired_size    = 2
  min_size        = 2
  max_size        = 2

  single_nat_gateway = true
  enable_nat_gateway = true  # Save ~$30/month on NAT Gateway costs
}