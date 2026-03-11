# UMG EKS GitOps - ArgoCD Setup

EKS cluster with ArgoCD GitOps continuous deployment.

## Prerequisites

- **AWS Account** with permissions to create EKS, VPC, IAM, and EC2 resources
- **AWS CLI** - Configure with `aws configure`
- **kubectl** - Kubernetes command-line tool
- **Terraform** - Infrastructure as code
- **Terragrunt** - Terraform wrapper
- **Docker** - For building container images (if modifying the app)
- **Git** - For version control and GitHub integration

Install these on Linux:

```bash
# AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Terraform
wget https://releases.hashicorp.com/terraform/1.7.0/terraform_1.7.0_linux_amd64.zip
unzip terraform_1.7.0_linux_amd64.zip && sudo mv terraform /usr/local/bin/

# Terragrunt
wget https://github.com/gruntwork-io/terragrunt/releases/download/v0.55.20/terragrunt_linux_amd64
chmod +x terragrunt_linux_amd64 && sudo mv terragrunt_linux_amd64 /usr/local/bin/terragrunt

# Docker
curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh
```

Then configure AWS:

```bash
aws configure
# Enter: AWS Access Key ID, Secret Access Key, Region (<REGION>), Output format (json)

# Verify access
aws sts get-caller-identity
```

## Quick Start

```bash
# 1. Deploy cluster
cd infra/dev/cluster
terragrunt apply

# 2. Configure kubectl
aws eks update-kubeconfig --region <REGION> --name umgapi-cluster-dev

# 3. Install ArgoCD
bash scripts/install-argocd.sh

# 4. Access ArgoCD
kubectl port-forward -n argocd svc/argocd-server 8080:443 &
# Open: https://localhost:8080
# Login: admin / (password from script output)

# 5. ArgoCD will auto-sync your app from the deploy/ folder
```

## Structure

- `app/` - Your containerized application
- `infra/` - Terraform/Terragrunt infrastructure
- `deploy/` - Kubernetes manifests (ArgoCD watches this folder)
  - `deployment.yaml` - App deployment (namespace, deployment, configmap, service)
  - `argocd/` - ArgoCD configuration (RBAC, Application manifest)
- `scripts/install-argocd.sh` - ArgoCD installation script

## How It Works

```
You push code
    ↓
GitHub Actions builds & pushes image to ECR
    ↓
You update image tag in deploy/deployment.yaml & push
    ↓
ArgoCD detects change in main branch
    ↓
ArgoCD (only service account with deploy permission) applies manifests
    ↓
App rolls out automatically
```

**Security:** 
- RBAC restricts deployment permissions to ArgoCD service account only
- Kyverno admission webhook **blocks all kubectl apply** attempts from users
- Only ArgoCD can create/update/delete deployments

## What You Get

- EKS Cluster (1.32) with 2 x t3.medium nodes
- **ArgoCD** for GitOps continuous deployment
- **Kyverno** admission webhook to enforce deployment policies
- App deployed with LoadBalancer service (external access)
- RBAC + Webhook restricting deployments to ArgoCD only

## Cleanup

```bash
# Remove ArgoCD
helm uninstall argocd -n argocd

# Destroy cluster
cd infra/dev/cluster
terragrunt destroy
```

## Troubleshooting

```bash
# Check pod status
kubectl get pods -n app

# View logs
kubectl logs -n app deployment/umgapi-app

# Describe pod for errors
kubectl describe pod -n app
```

FastAPI application on EKS with automated CI/CD pipeline: GitHub Actions → ECR → ArgoCD → Kubernetes.

## System Architecture

```
GitHub (main branch)
  ↓ Push code
GitHub Actions
  ↓ Build & push image to ECR
ECR (Container Registry)
  ↓ Update manifest in /deploy
Git Repository
  ↓ Detect change
ArgoCD
  ↓ Apply manifests
EKS Cluster
  ↓ Rolling update
FastAPI Application
```

**Note:** For larger projects with multiple environments and overlays, combining ArgoCD with Kustomize provides powerful templating and patch management capabilities.


## CI/CD Pipeline Setup

The pipeline automatically builds and deploys when you push to `main`.

### GitHub Actions Workflow

**File:** `.github/workflows/ci.yaml`

**Triggers on:** Push to `main` in `app/` directory

**Steps:**
1. Build Docker image (multi-stage, Python 3.12)
2. Push to ECR with commit SHA tag
3. Update `deploy/deployment.yaml` with new image tag
4. Commit back to repository

### Adding Secrets to the Github Pipeline

1. **Create AWS OIDC Provider for GitHub:**

```bash
# Set variables
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account ID: $AWS_ACCOUNT_ID"

# Create OIDC provider
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 \
  --region us-east-1

echo "✓ OIDC Provider created"
```

2. **Create IAM Role for GitHub Actions:**

```bash
# Create trust policy
cat > /tmp/trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::AWS_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          \"token.actions.githubusercontent.com:sub\": \"repo:YOUR_GITHUB_USERNAME/YOUR_REPO_NAME:ref:refs/heads/main\"
        }
      }
    }
  ]
}
EOF

# Replace account ID
sed -i "s/AWS_ACCOUNT_ID/$AWS_ACCOUNT_ID/g" /tmp/trust-policy.json

# Create role
aws iam create-role \
  --role-name github-oidc-ecr-role \
  --assume-role-policy-document file:///tmp/trust-policy.json

echo "✓ IAM Role created"
```

2. **Add ECR Permissions to Role:**

```bash
# Create ECR policy
cat > /tmp/ecr-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:DescribeRepositories"
      ],
      "Resource": "*"
    }
  ]
}
EOF

# Replace account ID
sed -i "s/AWS_ACCOUNT_ID/$AWS_ACCOUNT_ID/g" /tmp/ecr-policy.json

# Attach policy to role
aws iam put-role-policy \
  --role-name github-oidc-ecr-role \
  --policy-name ecr-push-policy \
  --policy-document file:///tmp/ecr-policy.json

echo "✓ ECR policy attached"
```

3. **Get Your Role ARN:**

```bash
export ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/github-oidc-ecr-role"
echo "Your Role ARN: $ROLE_ARN"
```

4. **Add GitHub Secret:**

- Go to: https://github.com/YOUR_GITHUB_USERNAME/YOUR_REPO_NAME
- Click **Settings** → **Secrets and variables** → **Actions**
- Click **"New repository secret"**
- Name: `AWS_ROLE_ARN`
- Value: `arn:aws:iam::YOUR_AWS_ACCOUNT_ID:role/github-oidc-ecr-role` (use your account ID)
- Click **"Add secret"**

### Test Pipeline

```bash
# Edit app
echo 'print("New version")' >> app/app.py

# Commit and push
git add app/app.py
git commit -m "feat: new feature"
git push origin main

# Monitor
# 1. GitHub Actions: https://github.com/YOUR_GITHUB_USERNAME/YOUR_REPO_NAME/actions
# 2. ArgoCD UI: https://localhost:8080 (via port-forward)
# 3. kubectl: kubectl rollout status deployment/umgapi-app -n app
```

## Project Structure

```
infra/
  ├── root.hcl                 # Global Terraform config
  ├── dev/ & prod/             # Environment configs
  └── modules/eks/             # EKS cluster modules
      ├── modules/iam/         # IRSA setup
      ├── modules/networking/  # VPC/networking
      ├── modules/cluster/     # EKS control plane
      └── modules/node_group/  # Worker nodes

deploy/
  ├── kubernetes/              # App manifests
  ├── deployment.yaml          # Main deployment manifest
  ├── argocd/                  # ArgoCD Application config
  └── ingress/                 # NGINX Ingress (optional)

app/
  ├── app.py                   # FastAPI app
  ├── requirements.txt         # Python deps
  └── dockerfile               # Multi-stage Docker build

.github/workflows/
  └── ci.yaml                  # GitHub Actions workflow
```

## Common Operations

### View Logs

```bash
kubectl logs deployment/umgapi-app -n app -f
kubectl logs deployment/argocd-server -n argocd -f
```

### Scale Application

```bash
kubectl scale deployment umgapi-app --replicas=5 -n app
kubectl get hpa umgapi-app -n app
```

### Update App Code

```bash
# Edit app/app.py
# Commit and push to main
# GitHub Actions builds and pushes to ECR
# ArgoCD auto-syncs within 3 minutes
# Monitor: kubectl rollout status deployment/umgapi-app -n app
```

### Access S3 or AWS Services

Application uses IRSA (IAM Roles for Service Accounts) - credentials automatically injected:

```python
import boto3
s3 = boto3.client('s3')
response = s3.list_buckets()  # Works with IRSA
```

Update permissions in: `infra/modules/eks/modules/irsa/main.tf`

### Configure Environment

Edit `infra/dev/env.hcl` or `infra/prod/env.hcl`:
- `region`
- `vpc_cidr`
- `cluster_name`
- `kubernetes_version`

## Configuration

### S3 Backend

```bash
# Create bucket
aws s3 mb s3://my-tfstate-bucket-$(date +%s)

# Update infra/root.hcl with bucket name
```

### Kubernetes Resources

- **Deployment:** 2 replicas, rolling update
- **HPA:** Auto-scale 2-10 pods based on CPU/memory
- **Service:** ClusterIP (internal)
- **Network Policy:** Pod isolation enabled
- **Pod Disruption Budget:** High availability
- **IRSA:** Secure AWS access without credentials

### Application Config

Edit `deploy/kubernetes/03-configmap.yaml`:
- `app_name`
- `log_level`
- Other env vars

## Cleanup

### Kubernetes Resources Only (Keep Cluster)

```bash
# Option 1: Delete via ArgoCD (recommended)
kubectl delete application umgapi-app -n argocd
# ArgoCD will automatically delete all managed resources

# Option 2: Manual deletion
kubectl delete -f deploy/kubernetes/ -n app
kubectl delete namespace app

# Verify cleanup
kubectl get all -n app
```

### ArgoCD Only (Keep Cluster)

```bash
# Delete ArgoCD application first
kubectl delete application umgapi-app -n argocd

# Uninstall ArgoCD via Helm
helm uninstall argocd -n argocd
kubectl delete namespace argocd

# Delete Kyverno (if installed)
helm uninstall kyverno -n kyverno
kubectl delete namespace kyverno
```

### Full Teardown (Delete Everything)

```bash
# 1. Delete Kubernetes resources first
kubectl delete application umgapi-app -n argocd 2>/dev/null || true
helm uninstall argocd -n argocd 2>/dev/null || true
helm uninstall kyverno -n kyverno 2>/dev/null || true

# 2. Delete namespaces
kubectl delete namespace app argocd kyverno 2>/dev/null || true

# 3. Destroy infrastructure
cd infra/dev/cluster
terragrunt destroy

# 4. (Optional) Delete ECR images
aws ecr batch-delete-image \
  --repository-name umgapi \
  --image-ids "$(aws ecr list-images --repository-name umgapi --query 'imageIds[*]' --output json)" \
  --region <REGION>

# 5. (Optional) Delete S3 state bucket
aws s3 rb s3://your-tfstate-bucket --force
```

### Verify Full Cleanup

```bash
# Check no resources remain
kubectl get all --all-namespaces | grep -E "app|argocd|kyverno"
aws eks list-clusters --region <REGION>
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=*umgapi*" --region <REGION>
```

## Troubleshooting

```bash
# Pods not running
kubectl describe pod <pod-name> -n app
kubectl logs <pod-name> -n app --previous

# Cluster issues
aws eks describe-cluster --name umgapi-cluster-dev --region <REGION>
kubectl get nodes

# GitHub Actions failing
# Check: https://github.com/YOUR_GITHUB_USERNAME/YOUR_REPO_NAME/actions
# Common: Missing AWS_ROLE_ARN secret

# ArgoCD not syncing
kubectl describe application umgapi-app -n argocd
kubectl logs deployment/argocd-server -n argocd
```

## Resources

- [AWS EKS](https://docs.aws.amazon.com/eks/)
- [Terragrunt](https://terragrunt.gruntwork.io/)
- [ArgoCD](https://argo-cd.readthedocs.io/)
- [GitHub Actions](https://docs.github.com/en/actions)
- [Kustomize](https://kustomize.io/) - Useful for larger projects with multiple overlays
```
