# EKS Deployment Guide

## Architecture Overview

This project deploys a FastAPI application on Amazon EKS with the following components:

### Infrastructure (Terraform/Terragrunt)

**Modular Structure:**
- `modules/networking/` - VPC, subnets, NAT gateways, route tables
- `modules/iam/` - IAM roles and security groups
- `modules/cluster/` - EKS control plane
- `modules/node_group/` - EKS worker nodes with auto-scaling
- `modules/addons/` - Kubernetes add-ons (VPC CNI, CoreDNS, kube-proxy)
- `modules/irsa/` - IAM Roles for Service Accounts (IRSA) for cluster and application

### Application (Kubernetes)

**Manifests:**
- `01-namespace.yaml` - Application namespace
- `02-service-account.yaml` - Kubernetes Service Account with IRSA annotation
- `03-configmap.yaml` - Application configuration
- `04-deployment.yaml` - FastAPI deployment with 2 replicas
- `05-service.yaml` - ClusterIP service
- `06-hpa.yaml` - Horizontal Pod Autoscaler (2-10 replicas)
- `07-network-policy.yaml` - Pod network isolation
- `08-pdb.yaml` - Pod Disruption Budget for high availability

## Deployment Steps

### 1. Prerequisites

```bash
# Install required tools
brew install terraform terragrunt aws-cli kubectl
# or for Linux: apt-get install terraform terragrunt awscli kubectl

# Configure AWS credentials
aws configure

# Verify connectivity
aws sts get-caller-identity
```

### 2. Customize Configuration

**Edit environment-specific files:**

```bash
# For development
nano infra/dev/env.hcl
# Update: region, vpc_cidr if needed

# For production
nano infra/prod/env.hcl
```

**Update S3 backend bucket:**

```bash
# Edit root.hcl
nano infra/root.hcl
# Replace "your-tfstate-bucket" with your actual S3 bucket name
# Create bucket if needed:
aws s3 mb s3://my-tfstate-bucket-$(date +%s)
```

### 3. Deploy Infrastructure (Dev Environment)

```bash
cd infra/dev/cluster

# Initialize Terragrunt (downloads modules, generates files)
terragrunt init

# Plan the deployment
terragrunt plan -out=tfplan

# Apply the plan
terragrunt apply tfplan

# Get outputs
terragrunt output
```

**Key outputs to note:**
- `cluster_endpoint` - Kubernetes API endpoint
- `cluster_id` - EKS cluster name
- `configure_kubectl` - Command to update kubeconfig

### 4. Configure kubectl

```bash
# From the terragrunt outputs, run the configure_kubectl command
aws eks update-kubeconfig --region us-east-1 --name automate-cluster-dev

# Verify connection
kubectl get nodes
kubectl get pods --all-namespaces
```

### 5. Deploy FastAPI Application

```bash
cd deploy/kubernetes

# Apply all manifests (numbered order for dependencies)
kubectl apply -f 01-namespace.yaml
kubectl apply -f 02-service-account.yaml
kubectl apply -f 03-configmap.yaml
kubectl apply -f 04-deployment.yaml
kubectl apply -f 05-service.yaml
kubectl apply -f 06-hpa.yaml
kubectl apply -f 07-network-policy.yaml
kubectl apply -f 08-pdb.yaml

# Or use kustomize for clean deployment
cd ../kustomize
kubectl apply -k .
```

### 6. Verify Deployment

```bash
# Check pods
kubectl get pods -n default

# Check deployment status
kubectl rollout status deployment/fastapi-app -n default

# Check HPA
kubectl get hpa -n default

# Check service
kubectl get svc -n default

# View logs
kubectl logs -f deployment/fastapi-app -n default

# Test the application (port-forward)
kubectl port-forward svc/fastapi-app 8080:80 -n default
curl http://localhost:8080/
```

## IRSA (IAM Roles for Service Accounts) Setup

The application uses IRSA to securely access AWS services without storing credentials.

### How It Works

1. **Terraform creates:**
   - OIDC provider for the EKS cluster
   - IAM role `automate-cluster-{env}-app-role` with trust relationship to service account
   - IRSA annotation added to service account pointing to the role ARN

2. **Kubernetes IRSA webhook:**
   - Mutates pod specs to inject AWS credentials via environment variables
   - Uses temporary STS credentials with 1-hour expiration
   - No long-term credentials stored

3. **Application can:**
   - Access AWS services (S3, DynamoDB, etc.) via boto3/SDK
   - Credentials automatically rotated

### Example: Access S3 from Application

```python
# In your FastAPI app
import boto3

s3_client = boto3.client('s3')
response = s3_client.list_buckets()  # Uses IRSA credentials automatically
```

### Extend IRSA Permissions

Edit `infra/modules/eks/modules/irsa/main.tf` and add statements to `aws_iam_role_policy` "app_policy":

```hcl
Statement = [{
  Effect = "Allow"
  Action = [
    "s3:GetObject",
    "s3:PutObject",
    "dynamodb:Query",
    "logs:PutLogEvents"
  ]
  Resource = [
    "arn:aws:s3:::my-bucket/*",
    "arn:aws:dynamodb:*:*:table/my-table",
    "arn:aws:logs:*:*:*"
  ]
}]
```

Then reapply: `terragrunt apply`

## Scaling & Performance

### Automatic Scaling

**Pod level:** HPA scales pods based on CPU/Memory (2-10 replicas)
```bash
kubectl get hpa
kubectl top pods  # View current resource usage
```

**Node level:** EKS node group auto-scales (dev: 1-2 nodes, prod: 2-6 nodes)
```bash
kubectl get nodes
aws autoscaling describe-auto-scaling-groups
```

### Resource Requests/Limits

Current settings in deployment:
- **Requests:** 100m CPU, 128Mi RAM (minimum guaranteed)
- **Limits:** 500m CPU, 512Mi RAM (maximum allowed)

Adjust in `04-deployment.yaml` based on load testing.

## Cleanup

### Remove Application
```bash
kubectl delete -k deploy/kustomize/
```

### Destroy Infrastructure (DEV)
```bash
cd infra/dev/cluster
terragrunt destroy
```

**Warning:** This will terminate all AWS resources (EKS, VPC, NAT gateways, etc).

## Troubleshooting

### Pods not starting

```bash
# Check pod events
kubectl describe pod <pod-name> -n default

# Check node resources
kubectl top nodes
kubectl describe nodes

# Check logs
kubectl logs <pod-name> -n default --previous
```

### IRSA not working

```bash
# Verify service account annotation
kubectl get sa app-sa -n default -o yaml
# Should have: eks.amazonaws.com/role-arn: arn:aws:iam::...

# Check AWS_ROLE_ARN env var in pod
kubectl exec <pod-name> -n default -- env | grep AWS

# Verify OIDC provider
aws iam list-open-id-connect-providers

# Test STS assume role
aws sts assume-role-with-web-identity \
  --role-arn arn:aws:iam::ACCOUNT:role/... \
  --role-session-name test \
  --web-identity-token $OIDC_TOKEN
```

### Cluster connectivity

```bash
# Check kubeconfig
cat ~/.kube/config | grep server

# Test cluster endpoint
curl -k https://<cluster-endpoint>/api/v1/namespaces

# Check security groups allow your IP
aws ec2 describe-security-groups --group-ids sg-xxxxx
```

## Additional Resources

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Terragrunt Documentation](https://terragrunt.gruntwork.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [IRSA Guide](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
