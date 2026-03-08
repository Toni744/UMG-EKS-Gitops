# Environment and region configuration for dev environment

locals {
    environment = "dev"
    region      = "us-east-1"
    project     = "umg-eks"
    
    tags = {
        Environment = local.environment
        Project     = local.project
        ManagedBy   = "Terragrunt"
    }
}