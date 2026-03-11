# UMG EKS GitOps

FastAPI application on EKS with automated CI/CD pipeline: GitHub Actions → ECR → ArgoCD → Kubernetes.

## System Architecture

```
GitHub (main branch)
  ↓ Push code
GitHub Actions
  ↓ Build & push image
ECR (Container Registry)
  ↓ Update manifest
Kustomization (Git)
  ↓ Detect change
ArgoCD
  ↓ Sync cluster
EKS Cluster
  ↓ Rolling update
FastAPI Application
```
## Quick Start (Linux)

### 1. Install Tools

```bash
sudo apt-get update && sudo apt-get install -y terraform terragrunt awscli kubectl
aws configure
aws sts get-caller-identity
```

### 2. Deploy EKS Cluster

```bash
cd infra/dev/cluster
terragrunt init
terragrunt apply

# Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name automate-cluster-dev
kubectl get nodes
```

### 3. Deploy Application

```bash
# Using Kustomize (includes app + ArgoCD)
kubectl apply -k deploy/kustomize/

# Verify
kubectl get pods -n default
kubectl get pods -n argocd
```

### 4. Access ArgoCD

```bash
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath="{.data.password}" | base64 -d

kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open: https://localhost:8080
# Login: admin / <password above>
```

## CI/CD Pipeline Setup

The pipeline automatically builds and deploys when you push to `main`.

### GitHub Actions Workflow

**File:** `.github/workflows/ci.yaml`

**Triggers on:** Push to `main` in `app/` directory

**Steps:**
1. Build Docker image (multi-stage, Python 3.12)
2. Push to ECR with commit SHA tag
3. Update `deploy/kustomize/kustomization.yaml` with new image
4. Commit back to repository

### Enable Pipeline

1. **Create IAM Role for GitHub Actions OIDC:**
   ```json
   {
     "Effect": "Allow",
     "Principal": {
       "Federated": "arn:aws:iam::014772274523:oidc-provider/token.actions.githubusercontent.com"
     },
     "Action": "sts:AssumeRoleWithWebIdentity",
     "Condition": {
       "StringEquals": {
         "token.actions.githubusercontent.com:sub": "repo:Toni744/UMG-EKS-Gitops:ref:refs/heads/main"
       }
     }
   }
   ```

2. **Add ECR Permissions to Role:**
   - `ecr:GetAuthorizationToken`
   - `ecr:BatchCheckLayerAvailability`
   - `ecr:PutImage`
   - `ecr:InitiateLayerUpload`
   - `ecr:UploadLayerPart`
   - `ecr:CompleteLayerUpload`

3. **Add GitHub Secret:**
   - Go to: Settings → Secrets and variables → Actions
   - Add: `AWS_ROLE_ARN` = `arn:aws:iam::014772274523:role/GitHubActionsRole`

### Test Pipeline

```bash
# Edit app
echo 'print("New version")' >> app/app.py

# Commit and push
git add app/app.py
git commit -m "feat: new feature"
git push origin main

# Monitor
# 1. GitHub Actions: https://github.com/Toni744/UMG-EKS-Gitops/actions
# 2. ArgoCD UI: https://localhost:8080 (via port-forward)
# 3. kubectl: kubectl rollout status deployment/umgapi-app -n default
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
  ├── kubernetes/              # App manifests (01-08)
  ├── kustomize/               # Kustomization + image patches
  ├── argocd/                  # ArgoCD Application + ingress
  └── ingress/                 # NGINX Ingress

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
kubectl logs deployment/umgapi-app -n default -f
kubectl logs deployment/argocd-server -n argocd -f
```

### Scale Application

```bash
kubectl scale deployment umgapi-app --replicas=5 -n default
kubectl get hpa umgapi-app -n default
```

### Update App Code

```bash
# Edit app/app.py
# Commit and push to main
# GitHub Actions builds and pushes to ECR
# ArgoCD auto-syncs within 3 minutes
# Monitor: kubectl rollout status deployment/umgapi-app -n default
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

```bash
# Remove application and ArgoCD
kubectl delete -k deploy/kustomize/

# Destroy infrastructure
cd infra/dev/cluster
terragrunt destroy
```

## Troubleshooting

```bash
# Pods not running
kubectl describe pod <pod-name> -n default
kubectl logs <pod-name> -n default --previous

# Cluster issues
aws eks describe-cluster --name automate-cluster-dev --region us-east-1
kubectl get nodes

# GitHub Actions failing
# Check: https://github.com/Toni744/UMG-EKS-Gitops/actions
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
- [Kustomize](https://kustomize.io/)
```
