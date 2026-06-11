terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

variable "project" { type = string }
variable "environment" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "eks_version" { type = string }

variable "node_groups" {
  description = "Map of node group name => sizing/instance config."
  type = map(object({
    instance_types = list(string)
    desired_size   = number
    min_size       = number
    max_size       = number
  }))
}

variable "addon_versions" {
  description = "Add-on versions. Leave null to let AWS pick the default for the cluster version. Use `aws eks describe-addon-versions` to pin."
  type = object({
    vpc_cni    = optional(string)
    coredns    = optional(string)
    kube_proxy = optional(string)
    ebs_csi    = optional(string)
  })
  default = {}
}

output "cluster_name" { value = aws_eks_cluster.this.name }
output "cluster_endpoint" { value = aws_eks_cluster.this.endpoint }
output "cluster_security_group_id" { value = aws_security_group.cluster.id }
output "oidc_provider_arn" { value = aws_iam_openid_connect_provider.this.arn }
output "node_role_arn" { value = aws_iam_role.node.arn }

variable "alb_security_group_id" {
  description = "Internal ALB SG - allowed into nodes on the app port range"
  type        = string
}

variable "jumphost_security_group_id" {
  description = "Jumphost SG - allowed to cluster API and nodes on 443"
  type        = string
}

variable "app_port_from" {
  description = "Low end of the app target port range"
  type        = number
  default     = 3000
}

variable "app_port_to" {
  description = "High end of the app target port range"
  type        = number
  default     = 8007
}

output "node_security_group_id" { value = local.node_security_group_id }

variable "jumphost_role_arn" {
  description = "Jumphost IAM role ARN - granted cluster-admin via EKS access entry"
  type        = string
}
