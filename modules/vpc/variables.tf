variable "project" { type = string }
variable "environment" { type = string }
variable "vpc_name" {
  description = "Explicit Name tag for the VPC (independent of project prefix)"
  type        = string
}
variable "vpc_cidr" { type = string }
variable "public_subnet_cidrs" { type = list(string) }
variable "private_subnet_cidrs" { type = list(string) }
