<<<<<<< HEAD
# Kema Infrastructure (Terraform)

Module-based Terraform for the Kema platform on AWS (`ap-south-1`), with a
per-environment folder layout and S3 + DynamoDB remote state.

Project prefix: `kmea`  ·  VPC name: `kmea-dev-vpc`

## What gets created
| Resource | Module | Notes |
|----------|--------|-------|
| 3 S3 buckets | `s3` | `kmea-dev-doc-library`, `kmea-dev-maindashboard`, `kmea-dev-eco` (all static-site) |
| 3 CloudFront CDNs | `cloudfront` (x3) | one per bucket, serving `index.html` via OAC; 403+404 → /index.html. doc-library = `PriceClass_All` (pay-as-you-go), other two = `PriceClass_200` |
| VPC + 2 public / 2 private subnets | `vpc` | `10.0.0.0/16`, IGW + single NAT |
| EKS (private endpoint) | `eks` | IAM roles + OIDC/IRSA created here; 2 node groups, t3.medium |
| Internal ALB | `alb` | internal-only HTTP listener + IP target group |
| Jumphost | `jumphost` | public subnet + public IP; SSM always, SSH 22 only from `jumphost_allowed_ssh_cidrs` |
| RDS PostgreSQL (single-AZ) | `rds` | `db.t3.medium` (2 vCPU / 4 GB); subnet group + parameter group included |

**Built in AWS console (not Terraform):** API Gateway REST API + VPC Link.

## Security group chain (API GW -> RDS)
```
API Gateway (REST) -> VPC Link -> internal ALB -> EKS nodes :3000-8007 -> RDS :5432
```
| SG | Inbound |
|----|---------|
| `kmea-dev-alb-sg` | 80 + 443 from VPC CIDR (VPC Link ENIs have no referencable SG) |
| EKS node SG (EKS-managed cluster SG) | 3000-8007 from alb-sg; 443 from jumphost-sg |
| `kmea-dev-eks-cluster-sg` | 443 from jumphost-sg (kubectl to private API) |
| `kmea-dev-rds-sg` | 5432 from node SG + jumphost-sg only (no VPC-wide CIDR) |
| `kmea-dev-jumphost-sg` | SSH 22 from `jumphost_allowed_ssh_cidrs` only (empty by default => SSM only) |

App port range (3000-8007) is set by `app_port_from` / `app_port_to` in the
eks module (defaults match Boloindia).

## One-time backend bootstrap
```bash
cd bootstrap
terraform init && terraform apply   # creates kmea-dev-tfstate-ap-south-1 + kmea-dev-tflock
cd ..
```

## Deploy dev
```bash
cd environments/dev
terraform init
terraform plan  -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

## Where to change things
- **Bucket names / count / settings** → `environments/dev/terraform.tfvars` (`s3_buckets`). The map KEY is the exact bucket name (no prefix added).
- **Which buckets get a CDN** → the two `module "cloudfront_*"` blocks in `environments/dev/main.tf` (and their matching OAC policy blocks). Add a third block to add a third CDN.
- **Node groups / sizing** → `node_groups` map in `terraform.tfvars`. Add/remove keys to change the number of groups.
- **Project prefix** → `project` in `terraform.tfvars`.
- **VPC name** → `vpc_name` in `terraform.tfvars`.

## Notes
- Both static buckets stay private; CloudFront reaches them via Origin Access Control. OAC bucket policies live in `environments/dev/main.tf` to avoid an s3 ⇄ cloudfront module cycle.
- Each CDN has a `404 -> /index.html` and `403 -> /index.html` fallback for SPA routing. Remove the 404 block in the cloudfront module if you don't want that.
- RDS master password is managed in Secrets Manager (`manage_master_user_password = true`). Get the ARN from the `rds_secret_arn` output.
- EKS is private — reach the API server from inside the VPC (the jumphost), then `aws eks update-kubeconfig --name <cluster> --region ap-south-1`.
- **Jumphost AMI**: set `jumphost_ami_id` in tfvars to the ap-south-1 AMI *ID* (not the name). Get it with `aws ssm get-parameters --region ap-south-1 --names /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64 --query 'Parameters[0].Value' --output text`. Connect via `aws ssm start-session --target <instance-id>`.
- Single NAT gateway for cost. Switch to per-AZ NAT for prod.

## Layout
```
terraform/
├── bootstrap/            # one-time state backend
├── environments/dev/     # main.tf, variables.tf, terraform.tfvars, provider.tf
└── modules/
    └── vpc/ eks/ rds/ alb/ s3/ cloudfront/
```
=======
# Terraform-dev-kmea
>>>>>>> 0fe2eca24bc82b2bc21ab803973a2eba76fd7072
