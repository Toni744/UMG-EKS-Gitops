# Networking module: VPC, subnets, gateways, route tables

data "aws_availability_zones" "available" {
  state = "available"
}

# Limit to 2 AZs for cost optimization
locals {
  az_count = 2
  azs      = slice(data.aws_availability_zones.available.names, 0, local.az_count)
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.tags,
    { Name = "${var.cluster_name}-vpc" }
  )
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    { Name = "${var.cluster_name}-igw" }
  )
}

resource "aws_subnet" "public" {
  count                   = local.az_count
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-public-${count.index + 1}"
      "kubernetes.io/role/elb" = "1"
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    }
  )
}

resource "aws_subnet" "private" {
  count             = local.az_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + local.az_count)
  availability_zone = local.azs[count.index]

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-private-${count.index + 1}"
      "kubernetes.io/role/internal-elb" = "1"
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    }
  )
}

resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(data.aws_availability_zones.available.names)) : 0
  domain = "vpc"

  depends_on = [aws_internet_gateway.main]

  tags = merge(
    var.tags,
    { Name = "${var.cluster_name}-eip-${count.index + 1}" }
  )
}

resource "aws_nat_gateway" "main" {
  count         = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(data.aws_availability_zones.available.names)) : 0
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  depends_on    = [aws_internet_gateway.main]

  tags = merge(
    var.tags,
    { Name = "${var.cluster_name}-nat-${count.index + 1}" }
  )
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(
    var.tags,
    { Name = "${var.cluster_name}-public-rt" }
  )
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  count  = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(data.aws_availability_zones.available.names)) : 0
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(
    var.tags,
    { Name = "${var.cluster_name}-private-rt-${count.index + 1}" }
  )
}

resource "aws_route_table_association" "private" {
  count          = var.enable_nat_gateway ? length(aws_subnet.private) : 0
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = var.single_nat_gateway ? aws_route_table.private[0].id : aws_route_table.private[count.index].id
}

# ── Security Groups for EKS ─────────────────────────────────────────────────

resource "aws_security_group" "eks_cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "Security group for EKS cluster"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.node_group.id]
    description     = "Allow traffic from worker nodes"
  }

  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "udp"
    security_groups = [aws_security_group.node_group.id]
    description     = "Allow UDP traffic from worker nodes"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    var.tags,
    { Name = "${var.cluster_name}-cluster-sg" }
  )
}

resource "aws_security_group" "node_group" {
  name        = "${var.cluster_name}-node-sg"
  description = "Security group for EKS nodes"
  vpc_id      = aws_vpc.main.id

  # Allow cluster to nodes
  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster.id]
    description     = "Allow TCP from cluster"
  }

  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "udp"
    security_groups = [aws_security_group.eks_cluster.id]
    description     = "Allow UDP from cluster"
  }

  # Allow node-to-node communication (pod networking, CNI)
  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.node_group.id]
    description     = "Allow TCP between nodes (pod networking)"
  }

  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "udp"
    security_groups = [aws_security_group.node_group.id]
    description     = "Allow UDP between nodes (pod networking)"
  }

  # Allow Kubelet API (for cluster health checks)
  ingress {
    from_port       = 10250
    to_port         = 10250
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster.id]
    description     = "Allow Kubelet API access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    var.tags,
    { Name = "${var.cluster_name}-node-sg" }
  )
}
