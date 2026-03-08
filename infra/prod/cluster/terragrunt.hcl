include "root" {
  path = find_in_parent_folders()
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env      = local.env_vars.locals.environment
}

terraform {
  source = "../../../modules/eks"
}

inputs = {
  cluster_name   = "automate-cluster-${local.env}"
  environment    = local.env
  aws_region     = local.env_vars.locals.aws_region

  # HA setup — multi-node, dedicated NAT gateways per AZ
  instance_types  = ["t3.medium"]
  desired_size    = 3
  min_size        = 2
  max_size        = 6

  single_nat_gateway = false   # one NAT GW per AZ for prod resilience
}