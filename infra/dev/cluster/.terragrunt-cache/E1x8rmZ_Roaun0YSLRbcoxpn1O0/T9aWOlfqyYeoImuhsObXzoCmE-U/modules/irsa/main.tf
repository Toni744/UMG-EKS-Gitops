# VPC CNI IAM Role with IRSA (for network permissions)
resource "aws_iam_role" "vpc_cni" {
  name = "${var.cluster_name}-vpc-cni-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        Federated = "arn:aws:iam::${var.aws_account_id}:oidc-provider/${replace(var.cluster_oidc_issuer_url, "https://", "")}"
      }
      Condition = {
        StringEquals = {
          "${replace(var.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-node"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "vpc_cni" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.vpc_cni.name
}

# ── IAM Role for Application (IRSA) ────────────────────────────────────────

resource "aws_iam_role" "app_role" {
  name = "${var.cluster_name}-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        Federated = "arn:aws:iam::${var.aws_account_id}:oidc-provider/${replace(var.cluster_oidc_issuer_url, "https://", "")}"
      }
      Condition = {
        StringEquals = {
          "${replace(var.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:umgapi:app-sa"
        }
      }
    }]
  })

  tags = var.tags
}

# Add application-specific AWS permissions here as needed
# Example: S3 access, DynamoDB, etc.
# resource "aws_iam_role_policy_attachment" "app_s3_policy" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
#   role       = aws_iam_role.app_role.name
# }
