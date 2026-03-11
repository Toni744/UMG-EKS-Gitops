# Environment and region configuration for dev environment

locals {
    environment = "dev"
    region      = "<REGION>"
    project     = "umg-eks"
    
    tags = {
        Environment = local.environment
        Project     = local.project
        ManagedBy   = "Terragrunt"
    }
}