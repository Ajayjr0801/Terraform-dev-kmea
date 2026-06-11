locals {
  name         = "${var.project}-${var.environment}"
  cluster_name = "${local.name}-eks"

  # Managed node groups (no custom launch template) attach the EKS-managed
  # cluster security group to every node - that SG is the "node SG" here.
  node_security_group_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

#####################
# Security group
#####################
resource "aws_security_group" "cluster" {
  name        = "${local.name}-eks-cluster-sg"
  description = "EKS control plane SG"
  vpc_id      = var.vpc_id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${local.name}-eks-cluster-sg" }
}

#####################
# Cluster (PRIVATE endpoint only)
# IAM cluster role  -> iam.tf
# OIDC provider     -> oidc.tf
#####################
resource "aws_eks_cluster" "this" {
  name     = local.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.eks_version

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = false
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  depends_on = [aws_iam_role_policy_attachment.cluster_policy]
  tags       = { Name = local.cluster_name }
}

#####################
# Managed node groups (in private subnets)
# Node IAM role -> iam.tf
# Driven by var.node_groups so you can run N groups with independent sizing.
#####################
resource "aws_eks_node_group" "this" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${local.name}-${each.key}"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = each.value.instance_types

  scaling_config {
    desired_size = each.value.desired_size
    min_size     = each.value.min_size
    max_size     = each.value.max_size
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [aws_iam_role_policy_attachment.node]
  tags       = { Name = "${local.name}-${each.key}" }
}

#####################
# Data-path SG rules
# internal ALB -> nodes on the app port range (mirrors Boloindia
# sg-0ad3dca9... -> node, ports 3000-8007), and jumphost -> 443.
#####################
resource "aws_security_group_rule" "nodes_from_alb_app_ports" {
  type                     = "ingress"
  description              = "Internal ALB to app target ports"
  security_group_id        = local.node_security_group_id
  source_security_group_id = var.alb_security_group_id
  protocol                 = "tcp"
  from_port                = var.app_port_from
  to_port                  = var.app_port_to
}

# kubectl from the jumphost to the private API endpoint.
resource "aws_security_group_rule" "cluster_from_jumphost_443" {
  type                     = "ingress"
  description              = "Jumphost to private EKS API"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = var.jumphost_security_group_id
  protocol                 = "tcp"
  from_port                = 443
  to_port                  = 443
}

# Carries over Boloindia's jumphost -> node 443 rule.
resource "aws_security_group_rule" "nodes_from_jumphost_443" {
  type                     = "ingress"
  description              = "Jumphost to nodes on 443"
  security_group_id        = local.node_security_group_id
  source_security_group_id = var.jumphost_security_group_id
  protocol                 = "tcp"
  from_port                = 443
  to_port                  = 443
}

#####################
# Cluster access for the jumphost role (without this, the SG/network path
# works but kubectl gets "Unauthorized" - the IAM role must be granted entry).
#####################
resource "aws_eks_access_entry" "jumphost" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = var.jumphost_role_arn
}

resource "aws_eks_access_policy_association" "jumphost_admin" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = var.jumphost_role_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.jumphost]
}
