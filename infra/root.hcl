# ── Root terragrunt.hcl ──────────────────────────────────────────────────────
# Every environment inherits this file via find_in_parent_folders().
# It wires up the S3 remote state backend dynamically per environment.

locals {
  # Parse the env.hcl from the calling environment directory
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env      = local.env_vars.locals.environment
  region   = local.env_vars.locals.region

  # S3 state bucket — one bucket, keys partitioned by env + module
  state_bucket = "your-tfstate-bucket"   # <-- replace with your bucket name
  lock_table   = "terraform-lock"
}

# ── Remote state backend (generated per module path) ─────────────────────────
remote_state {
  backend = "s3"

  config = {
    bucket         = local.state_bucket
    key            = "${local.env}/eks/terraform.tfstate"
    region         = local.region
    encrypt        = true
    dynamodb_table = local.lock_table
  }

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# ── AWS provider (generated into each module directory) ───────────────────────
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"

  contents = <<EOF
provider "aws" {
  region = "${local.region}"

  default_tags {
    tags = {
      Environment = "${local.env}"
      ManagedBy   = "Terragrunt"
      Project     = "automate-all-the-things"
    }
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
      command     = "aws"
    }
  }
}
EOF
}