# Environment and region configuration for prod environment

locals {
    environment = "prod"
    region      = "us-east-1"
    project     = "umg-eks"
    
    tags = {
        Environment = local.environment
        Project     = local.project
        ManagedBy   = "Terragrunt"
    }
}