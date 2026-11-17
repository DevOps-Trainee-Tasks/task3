# Task 3 — ECS Fargate

Terraform deploys Ollama, Open WebUI, Prometheus, and Grafana as ECS Fargate services. Their images are built in the sibling `docker_task3` directory and pushed to one existing ECR repository.

## Architecture

| Component | Location | Purpose |
| --- | --- | --- |
| VPC | Two public, two private application, and two private database subnets | Separates the load balancer, ECS tasks, and database. NAT provides outbound access for tasks. |
| ALB | Public subnets | Routes HTTP requests to the four ECS services; public access is limited to `my_ip`. |
| ECS | Private application subnets | Runs two Ollama tasks and one each for WebUI, Prometheus, and Grafana. |
| PostgreSQL RDS | Private database subnets | Stores WebUI data; RDS manages the master password. |
| Secrets Manager | AWS | Stores WebUI credentials and its database URL. |
| CloudWatch Logs | AWS | Receives container logs in `/ecs/task3/{ollama,webui,grafana,prometheus}`. |

The WebUI task runs a `db-init` container before WebUI starts. It enables the PostgreSQL `vector` extension, creates or updates the WebUI database user, and grants access to the `public` schema. This also works when the infrastructure is recreated with a fresh database.

WebUI reaches Ollama through the ALB on port `11434`; Grafana reaches Prometheus through the ALB on port `9090`. The ALB security group allows these internal requests from the NAT gateway's public IP.

## Repository structure

```text
task3/
├── backend.tf                    # S3 backend and state locking
├── locals.tf                     # Region, name, database, SMTP parameter
├── main.tf                       # Provider and module calls
├── variables.tf                  # Terraform inputs
├── terraform_tfvars_example.txt  # Example local inputs
├── modules/
│   ├── vpc/                      # Network and NAT
│   ├── sg/                       # Security groups
│   ├── alb/                      # Listeners and target groups
│   ├── rds/                      # PostgreSQL
│   ├── webui-creds/              # Secrets Manager
│   └── ecs/                      # Cluster, services, IAM, logs
└── .github/workflows/            # Plan and apply
```

The Terraform configuration uses `us-east-1` and the project name `task3` from `locals.tf`.

## Prerequisites

- Terraform and AWS credentials with permissions to deploy this infrastructure.
- An existing ECR repository in `us-east-1` with images tagged `ollama-v2`, `open-webui-v2`, `prometheus-v2`, and `grafana-v2`.
- The S3 bucket configured in `backend.tf` and permissions to access its state object.
- An SSM **SecureString** parameter `/task3/grafana/smtp-password` containing the Gmail App Password for `alert_email`. Grafana needs it to start.

**Check `backend.tf` before using Terraform.** Its current state key is `manual-task1/terraform.tfstate`. If that is Task 1's state, set a separate Task 3 key before initialization. Using Task 1's state can change or destroy its resources.

## Build and push images

Docker and Docker Buildx must be available. Run the build script from the sibling Docker project:

```bash
cd ../docker_task3
./build-and-push.sh ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/REPOSITORY_NAME v2
cd ../task3
```

Replace `ACCOUNT_ID` and `REPOSITORY_NAME` with your existing ECR repository details. The script builds `linux/amd64` images and pushes all four `-v2` tags.

## Set Terraform inputs

Create or edit `terraform.tfvars` using `terraform_tfvars_example.txt` as a template:

```hcl
my_ip = "203.0.113.10/32"
alert_email = "example@gmail.com"
webui_db_username = "webui"
webui_db_password = "REPLACE_WITH_A_PASSWORD"
webui_secret_key = "REPLACE_WITH_A_SECRET_KEY"
ecr_repository_uri = "ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/REPOSITORY_NAME"
```

Replace the example values. Set `my_ip` to your public IP with `/32`, and use the same repository URI as in the build command. `terraform.tfvars` is ignored by Git; WebUI credentials also enter Terraform state, so restrict access to the S3 state bucket.

Grafana uses `alert_email` as its Gmail SMTP username. The SSM parameter must contain that account's App Password; there is no separate `grafana_smtp_username` variable.

## Deploy

From `task3/`, after checking the backend, images, and inputs:

```bash
terraform init
terraform validate
terraform plan
terraform apply
```

If you changed the backend after a previous initialization, use `terraform init -reconfigure`. Review the plan before applying. Terraform creates the ECS cluster and services. The WebUI task additionally pulls `public.ecr.aws/docker/library/postgres:16-alpine` for `db-init`.

## Access and verify

Get the ALB hostname:

```bash
aws elbv2 describe-load-balancers --names task3-alb --region us-east-1 --query 'LoadBalancers[0].DNSName' --output text
```

From the IP specified in `my_ip`, open:

| Service | URL |
| --- | --- |
| Open WebUI | `http://<ALB_DNS>/` |
| Grafana | `http://<ALB_DNS>:3000/` |
| Prometheus | `http://<ALB_DNS>:9090/` |
| Ollama API | `http://<ALB_DNS>:11434/api/tags` |

Check service counts and WebUI initialization logs:

```bash
aws ecs describe-services --cluster task3-cluster --services task3-ollama task3-webui task3-prometheus task3-grafana --region us-east-1 --query 'services[].{name:serviceName,running:runningCount,desired:desiredCount}' --output table
aws logs tail /ecs/task3/webui --follow --region us-east-1
```

Expected running counts: Ollama `2`, each other service `1`. The WebUI log group includes `db-init`. If a task stops, check its ECS service events and CloudWatch logs.

## GitHub Actions

Pull requests to `main` from this repository run `terraform init`, `validate`, and `plan`. A push to `main` or manual workflow dispatch runs `plan` and `apply` in the `terraform-apply` GitHub environment. Set any required deployment approval in that environment before pushing to `main`.

| Type | Name | Purpose |
| --- | --- | --- |
| Variable | `AWS_ROLE_ARN` | AWS OIDC role |
| Variable | `AWS_REGION` | AWS region (`us-east-1`) |
| Variable | `ALLOWED_ACCOUNT_IDS` | Expected account |
| Variable | `ECR_REPOSITORY_URI` | Existing ECR repository |
| Secret | `SSH_CIDR` | ALB access CIDR (`my_ip`) |
| Secret | `ALERT_EMAIL` | Grafana Gmail address |
| Secret | `WEBUI_DB_USERNAME` | Database user |
| Secret | `WEBUI_DB_PASSWORD` | Database password |
| Secret | `WEBUI_SECRET_KEY` | WebUI session secret |

Choose local `terraform apply` or GitHub Actions for a deployment; both must use the intended backend state.
