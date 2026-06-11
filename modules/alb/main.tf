locals {
  name = "${var.project}-${var.environment}"
}

resource "aws_security_group" "alb" {
  name        = "${local.name}-alb-sg"
  description = "Internal ALB SG"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from within VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # API Gateway (REST) VPC Link ENIs sit in the VPC and have no referencable
  # SG, so the VPC CIDR is the correct source here (the one CIDR-based rule
  # in the chain).
  ingress {
    description = "HTTPS from VPC (API Gateway VPC Link)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}-alb-sg" }
}

resource "aws_lb" "internal" {
  name               = "${local.name}-int-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.private_subnet_ids
  tags               = { Name = "${local.name}-int-alb" }
}

resource "aws_lb_target_group" "this" {
  name        = "${local.name}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/healthz"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
  }

  tags = { Name = "${local.name}-tg" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.internal.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

variable "project" { type = string }
variable "environment" { type = string }
variable "vpc_id" { type = string }
variable "vpc_cidr" { type = string }
variable "private_subnet_ids" { type = list(string) }

output "alb_arn" { value = aws_lb.internal.arn }
output "alb_dns_name" { value = aws_lb.internal.dns_name }
output "listener_arn" { value = aws_lb_listener.http.arn }
output "alb_security_group_id" { value = aws_security_group.alb.id }
output "target_group_arn" { value = aws_lb_target_group.this.arn }
