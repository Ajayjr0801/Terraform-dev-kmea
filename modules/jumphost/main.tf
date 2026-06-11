locals {
  name = "${var.project}-${var.environment}"
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "jumphost" {
  name               = "${local.name}-jumphost-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.jumphost.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Needed for `aws eks update-kubeconfig` from the jumphost.
resource "aws_iam_role_policy" "eks_describe" {
  name = "${local.name}-jumphost-eks-describe"
  role = aws_iam_role.jumphost.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["eks:DescribeCluster", "eks:ListClusters"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "jumphost" {
  name = "${local.name}-jumphost-profile"
  role = aws_iam_role.jumphost.name
}

# Public jumphost. SSM still works; SSH (22) only opens if you list CIDRs
# in allowed_ssh_cidrs — never defaults to 0.0.0.0/0.
resource "aws_security_group" "jumphost" {
  name        = "${local.name}-jumphost-sg"
  description = "Jumphost SG - SSM + optional SSH from allowed CIDRs"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = length(var.allowed_ssh_cidrs) > 0 ? [1] : []
    content {
      description = "SSH from allowed CIDRs"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.allowed_ssh_cidrs
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}-jumphost-sg" }
}

resource "aws_instance" "jumphost" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  associate_public_ip_address = true
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.jumphost.id]
  iam_instance_profile        = aws_iam_instance_profile.jumphost.name

  metadata_options {
    http_tokens   = "required" # IMDSv2
    http_endpoint = "enabled"
  }

  root_block_device {
    encrypted   = true
    volume_size = 20
    volume_type = "gp3"
  }

  tags = { Name = "${local.name}-jumphost" }
}

variable "project" { type = string }
variable "environment" { type = string }
variable "vpc_id" { type = string }
variable "subnet_id" {
  description = "Public subnet ID for the jumphost"
  type        = string
}
variable "allowed_ssh_cidrs" {
  description = "CIDRs allowed to SSH (22). Empty list = no SSH rule (SSM only)."
  type        = list(string)
  default     = []
}
variable "key_name" {
  description = "EC2 key pair name for SSH. Null = SSM only."
  type        = string
  default     = null
}
variable "instance_type" {
  type    = string
  default = "t2.small"
}
variable "ami_id" {
  description = "AMI ID for the jumphost"
  type        = string
}

output "instance_id" { value = aws_instance.jumphost.id }
output "security_group_id" { value = aws_security_group.jumphost.id }

output "public_ip" { value = aws_instance.jumphost.public_ip }
output "role_arn" { value = aws_iam_role.jumphost.arn }
