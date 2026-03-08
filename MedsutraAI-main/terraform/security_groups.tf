# Security Groups for AI Cancer Detection Platform
# Implements network security controls for EKS, RDS, Lambda, and other services

# Security Group for EKS Cluster Control Plane
resource "aws_security_group" "eks_cluster" {
  name        = "${var.project_name}-${var.environment}-eks-cluster-sg"
  description = "Security group for EKS cluster control plane"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.environment}-eks-cluster-sg"
  }
}

# Allow EKS cluster to communicate with worker nodes
resource "aws_security_group_rule" "eks_cluster_ingress_workstation_https" {
  description       = "Allow workstation to communicate with the cluster API Server"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  security_group_id = aws_security_group.eks_cluster.id
}

# Allow EKS cluster egress to worker nodes
resource "aws_security_group_rule" "eks_cluster_egress" {
  description       = "Allow cluster egress to worker nodes"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_cluster.id
}

# Security Group for EKS Worker Nodes
resource "aws_security_group" "eks_nodes" {
  name        = "${var.project_name}-${var.environment}-eks-nodes-sg"
  description = "Security group for EKS worker nodes - allows inter-pod communication"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name                                                = "${var.project_name}-${var.environment}-eks-nodes-sg"
    "kubernetes.io/cluster/${var.project_name}-${var.environment}" = "owned"
  }
}

# Allow worker nodes to communicate with each other (inter-pod communication)
resource "aws_security_group_rule" "eks_nodes_ingress_self" {
  description              = "Allow nodes to communicate with each other"
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  source_security_group_id = aws_security_group.eks_nodes.id
  security_group_id        = aws_security_group.eks_nodes.id
}

# Allow worker nodes to receive traffic from cluster control plane
resource "aws_security_group_rule" "eks_nodes_ingress_cluster" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_cluster.id
  security_group_id        = aws_security_group.eks_nodes.id
}

# Allow worker nodes to receive HTTPS traffic from cluster control plane
resource "aws_security_group_rule" "eks_nodes_ingress_cluster_https" {
  description              = "Allow pods to communicate with the cluster API Server"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_cluster.id
  security_group_id        = aws_security_group.eks_nodes.id
}

# Allow worker nodes egress to internet
resource "aws_security_group_rule" "eks_nodes_egress" {
  description       = "Allow worker nodes to communicate with the internet"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_nodes.id
}

# Security Group for RDS PostgreSQL
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Security group for RDS PostgreSQL - allows connections from Lambda and EKS only"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-sg"
  }
}

# Allow RDS to receive connections from Lambda
resource "aws_security_group_rule" "rds_ingress_lambda" {
  description              = "Allow Lambda functions to connect to RDS"
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lambda.id
  security_group_id        = aws_security_group.rds.id
}

# Allow RDS to receive connections from EKS nodes
resource "aws_security_group_rule" "rds_ingress_eks" {
  description              = "Allow EKS nodes to connect to RDS"
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_nodes.id
  security_group_id        = aws_security_group.rds.id
}

# No egress rules for RDS - database doesn't need outbound connections

# Security Group for Lambda Functions
resource "aws_security_group" "lambda" {
  name        = "${var.project_name}-${var.environment}-lambda-sg"
  description = "Security group for Lambda functions with outbound access to required services"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.environment}-lambda-sg"
  }
}

# Allow Lambda egress to RDS
resource "aws_security_group_rule" "lambda_egress_rds" {
  description              = "Allow Lambda to connect to RDS"
  type                     = "egress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.rds.id
  security_group_id        = aws_security_group.lambda.id
}

# Allow Lambda egress to HTTPS (for AWS services via VPC endpoints and internet)
resource "aws_security_group_rule" "lambda_egress_https" {
  description       = "Allow Lambda to make HTTPS requests"
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.lambda.id
}

# Allow Lambda egress to HTTP (for external APIs if needed)
resource "aws_security_group_rule" "lambda_egress_http" {
  description       = "Allow Lambda to make HTTP requests"
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.lambda.id
}

# Security Group for Application Load Balancer (for EKS ingress)
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.environment}-alb-sg"
  }
}

# Allow ALB to receive HTTPS traffic from internet
resource "aws_security_group_rule" "alb_ingress_https" {
  description       = "Allow HTTPS traffic from internet"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
}

# Allow ALB to receive HTTP traffic from internet (for redirect to HTTPS)
resource "aws_security_group_rule" "alb_ingress_http" {
  description       = "Allow HTTP traffic from internet for redirect to HTTPS"
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
}

# Allow ALB egress to EKS nodes
resource "aws_security_group_rule" "alb_egress_eks" {
  description              = "Allow ALB to forward traffic to EKS nodes"
  type                     = "egress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_nodes.id
  security_group_id        = aws_security_group.alb.id
}

# Allow EKS nodes to receive traffic from ALB
resource "aws_security_group_rule" "eks_nodes_ingress_alb" {
  description              = "Allow EKS nodes to receive traffic from ALB"
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.eks_nodes.id
}

# Security Group for Redis (used by Agent Orchestrator)
resource "aws_security_group" "redis" {
  name        = "${var.project_name}-${var.environment}-redis-sg"
  description = "Security group for Redis - allows connections from EKS nodes only"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.environment}-redis-sg"
  }
}

# Allow Redis to receive connections from EKS nodes
resource "aws_security_group_rule" "redis_ingress_eks" {
  description              = "Allow EKS nodes to connect to Redis"
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_nodes.id
  security_group_id        = aws_security_group.redis.id
}

# No egress rules for Redis - it doesn't need outbound connections
