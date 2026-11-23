# Task 3 — ECS Fargate

Terraform deploys Ollama, Open WebUI, Prometheus, and Grafana as ECS Fargate services in `us-east-1`. The sibling `docker_task3` directory contains the seven Docker images used by these services.

## Architecture

| Component | Configuration |
| --- | --- |
| Network | VPC `10.0.0.0/24` across `us-east-1a` and `us-east-1b`; two public, two private application, and two private database subnets; one NAT gateway. |
| Load balancers | Public `task3-alb` for WebUI, Grafana, and Prometheus; private `task3-internal-alb` for WebUI-to-Ollama traffic. |
| ECS | Two Ollama tasks, two WebUI tasks, two Prometheus tasks, and one Grafana task in private application subnets. |
| Database | PostgreSQL 16 RDS (`manualdb`); RDS manages the `dbadmin` password in Secrets Manager. The WebUI task runs `db-init` before the application starts. WebUI reads credentials from the manually created `task3/webui-config` secret and builds `DATABASE_URL` using the current RDS address. |
| Metrics | Ollama, WebUI, and Grafana tasks include an `ecs-exporter` sidecar on port 9779. Prometheus discovers tasks through the private Cloud Map domain `task3.local` and scrapes these exporters. Grafana has Prometheus and CloudWatch data sources. |
| Logs | A FireLens `log-router` sidecar sends application logs to CloudWatch Logs and writes them to a separate EFS file system for each service, organized by availability zone. |

Prometheus scrapes itself and the exporters at `ollama.task3.local`, `webui.task3.local`, and `grafana.task3.local`. Prometheus tasks do not include an exporter. Prometheus metric storage is not mounted on EFS; its EFS volume is for the log router.

## Repository structure

```text
task3/
├── backend.tf                   # S3 state and lock file
├── locals.tf                    # Region, database settings, log router image
├── main.tf                      # Infrastructure and image references
├── variables.tf                 # Terraform inputs
├── terraform_tfvars_example.txt # Local input template
├── modules/
│   ├── alb/                     # Public and internal load balancers
│   ├── cloudmap/                # Private service discovery
│   ├── ecs/                     # Task definitions and services
│   ├── efs/                     # Log file systems
│   ├── iam/                     # Task and execution roles
│   ├── rds/                     # PostgreSQL
│   ├── sg/                      # Security groups
│   ├── vpc/                     # Subnets and NAT gateway
│   └── webui-creds/             # WebUI credentials
└── .github/workflows/           # Terraform plan and apply
```

The sibling `docker_task3/` directory contains `ollama`, `open-webui`, `prometheus`, `grafana`, `db-init`, `ecs-exporter`, and `log-router` Dockerfiles and their configurations.

## Before deployment

1. Configure AWS credentials for the intended account in `us-east-1`. Install Terraform, Docker with Buildx, and the AWS CLI.
2. Create the seven ECR repositories `task3/ollama`, `task3/open-webui`, `task3/prometheus`, `task3/grafana`, `task3/db-init`, `task3/ecs-exporter`, and `task3/log-router` if they do not already exist. Build and push images from `docker_task3/` before starting ECS.
3. Ensure the S3 bucket in `backend.tf` exists. **Check its state key before running Terraform:** the committed key is `manual-task1/terraform.tfstate`. If that belongs to Task 1, set a dedicated Task 3 key first to avoid using the other project's state.
4. Create the SSM SecureString parameter `/task2/grafana/smtp-password` containing the Gmail App Password for `alert_email`. This is the exact parameter used by `locals.tf`.
5. Create the `task3/webui-config` secret manually in AWS Secrets Manager (`us-east-1`). It must contain the string keys `webui_db_username`, `webui_db_password`, and `webui_secret_key`. Create it before running `terraform plan`. The secret is not managed by Terraform.

Create `terraform.tfvars` from `terraform_tfvars_example.txt` and replace every example value:

```hcl
my_ip              = "203.0.113.10/32"
alert_email        = "you@example.com"
ecr_repository_uri = "ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/task3"
```

`ecr_repository_uri` is the shared prefix of the seven ECR repository URIs. Keep `terraform.tfvars` out of Git. Sensitive inputs can appear in Terraform state; restrict access to the state bucket. Image tags are set independently in `main.tf` and `locals.tf`. Update their references after pushing new image versions.

## Deploy

From this directory:

```bash
terraform init
terraform validate
terraform plan
terraform apply
```

Review the plan before applying. If you changed the S3 backend since a previous initialization, run `terraform init -reconfigure`.

## Access and checks

Get the public load balancer DNS name:

```bash
aws elbv2 describe-load-balancers --names task3-alb --region us-east-1 --query 'LoadBalancers[0].DNSName' --output text
```

From the IP configured in `my_ip`, use these URLs:

| Service | URL |
| --- | --- |
| Open WebUI | `http://<ALB_DNS>/` |
| Grafana | `http://<ALB_DNS>/grafana/` |
| Prometheus | `http://<ALB_DNS>/prometheus/` |

WebUI reaches Ollama through the internal ALB. Ollama has no public ALB listener.

Check service counts and WebUI initialization logs:

```bash
aws ecs describe-services --cluster task3-cluster --services task3-ollama task3-webui task3-prometheus task3-grafana --region us-east-1 --query 'services[].{name:serviceName,running:runningCount,desired:desiredCount}' --output table
aws logs tail /ecs/task3/webui --follow --region us-east-1
```

In Prometheus, `/targets` should show `ollama-ecs`, `webui-ecs`, and `grafana-ecs`. Grafana's CPU, Memory, and Ephemeral storage dashboards query Prometheus for Ollama metrics; the ALB dashboards use CloudWatch.

## GitHub Actions

`.github/workflows/terraform-plan.yaml` runs `terraform init`, `validate`, and `plan` on pushes to branches other than `main`. `.github/workflows/terraform-apply.yaml` plans and applies the merged commit after a pull request is merged into `main`; it uses the `terraform-apply` GitHub environment. If that environment has required reviewers, the job waits for their approval.

| GitHub setting | Name | Terraform use |
| --- | --- | --- |
| Variable | `AWS_ROLE_ARN` | AWS role assumed through GitHub OIDC. |
| Variable | `AWS_REGION` | AWS region (`us-east-1`). |
| Variable | `ALLOWED_ACCOUNT_IDS` | Expected AWS account. |
| Variable | `ECR_REPOSITORY_URI` | Prefix of the seven ECR repository URIs. |
| Secret | `SSH_CIDR` | Value of `my_ip`. |
| Secret | `ALERT_EMAIL` | Grafana SMTP address. |
| Secret | `WEBUI_DB_USERNAME` | WebUI database user. |
| Secret | `WEBUI_DB_PASSWORD` | WebUI database password. |
| Secret | `WEBUI_SECRET_KEY` | WebUI session key. |

The OIDC role must trust the branch pushes used for planning and the `terraform-apply` environment used after merge. It also needs access to the configured S3 backend and AWS resources.
