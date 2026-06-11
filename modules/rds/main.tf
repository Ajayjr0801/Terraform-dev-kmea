locals {
  name = "${var.project}-${var.environment}"
}

resource "aws_db_subnet_group" "this" {
  name       = "${local.name}-db-subnet-group"
  subnet_ids = var.private_subnet_ids
  tags       = { Name = "${local.name}-db-subnet-group" }
}

resource "aws_db_parameter_group" "this" {
  name   = "${local.name}-pg17"
  family = "postgres17"

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  tags = { Name = "${local.name}-pg17" }
}

resource "aws_security_group" "rds" {
  name        = "${local.name}-rds-sg"
  description = "RDS SG - Postgres from named SGs only"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}-rds-sg" }
}

# 5432 only from explicitly named SGs (EKS nodes + jumphost) - no VPC-wide CIDR.
resource "aws_security_group_rule" "postgres_in" {
  for_each = var.source_security_group_ids

  type                     = "ingress"
  description              = "Postgres from ${each.key}"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = each.value
  protocol                 = "tcp"
  from_port                = 5432
  to_port                  = 5432
}

# Password is auto-managed by RDS in Secrets Manager (no plaintext in state/vars).
resource "aws_db_instance" "this" {
  identifier     = "${local.name}-postgres"
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.allocated_storage * 2
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.username

  manage_master_user_password = true

  multi_az               = false # single AZ as requested
  db_subnet_group_name   = aws_db_subnet_group.this.name
  parameter_group_name   = aws_db_parameter_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  backup_retention_period = 7
  skip_final_snapshot     = true
  deletion_protection     = false # set true for prod
  publicly_accessible     = false

  tags = { Name = "${local.name}-postgres" }
}

variable "project" { type = string }
variable "environment" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "source_security_group_ids" {
  description = "Map of label => SG ID allowed to reach Postgres on 5432"
  type        = map(string)
}
variable "engine_version" { type = string }
variable "instance_class" { type = string }
variable "allocated_storage" { type = number }
variable "db_name" { type = string }
variable "username" { type = string }

output "endpoint" { value = aws_db_instance.this.endpoint }
output "secret_arn" { value = aws_db_instance.this.master_user_secret[0].secret_arn }
output "security_group_id" { value = aws_security_group.rds.id }
