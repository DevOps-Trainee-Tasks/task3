terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
provider "aws" {
  region = local.aws_region
}

data "aws_caller_identity" "current" {}

module "vpc" {
  source = "./modules/vpc"
  nat_gateway_public_subnet_index = 0
  name_prefix = local.project

cidr = "10.0.0.0/24"

  available_zones_list = [
    "us-east-1a",
    "us-east-1b"
  ]
  public_subnets = [
    "10.0.0.0/27",
    "10.0.0.32/27"
  ]
  private_servers_subnets = [
    "10.0.0.64/27",
    "10.0.0.96/27"
  ]
  private_db_subnets = [
    "10.0.0.128/27",
    "10.0.0.160/27"
  ]
}

module "sg" {
  source = "./modules/sg"
  main_vpc_id = module.vpc.vpc_id

  security_groups = {
    alb_sg = {
      ingress_ports_tcp = [80, 3000, 9090, 11434]
      allowed_cidr_blocks = [var.my_ip, "${module.vpc.nat_public_ip}/32"]
      allowed_security_groups = []
    }

    ollama_sg = {
      ingress_ports_tcp = [11434]
      allowed_cidr_blocks = []
      allowed_security_groups = ["alb_sg"]
    }

    webui_sg = {
      ingress_ports_tcp = [8080]
      allowed_cidr_blocks = []
      allowed_security_groups = ["alb_sg"]
    }

    grafana_sg = {
      ingress_ports_tcp = [3000]
      allowed_cidr_blocks = []
      allowed_security_groups = ["alb_sg"]
    }

    prometheus_sg = {
      ingress_ports_tcp = [9090]
      allowed_cidr_blocks = []
      allowed_security_groups = ["alb_sg"]
    }

    rds_sg = {
      ingress_ports_tcp = [5432]
      allowed_cidr_blocks = []
      allowed_security_groups = ["webui_sg"]
    }

    efs_sg = {
      ingress_ports_tcp = [2049]
      allowed_cidr_blocks = []
      allowed_security_groups = [
        "ollama_sg",
        "webui_sg",
        "grafana_sg",
        "prometheus_sg"
      ]
    }
  }
}


module "alb" {
    source = "./modules/alb"

    name_prefix = local.project
    vpc_id = module.vpc.vpc_id
    public_subnet_ids = module.vpc.public_subnet_ids
    security_groups_id = module.sg.security_group_ids["alb_sg"]
    ollama_port = 11434
}

module "rds" {
    source = "./modules/rds"

    name_prefix = local.project
    private_db_subnet_ids = module.vpc.private_db_subnet_ids
    rds_security_group_id = module.sg.security_group_ids["rds_sg"]
    instance_class = local.rds_instance_class
    db_name = local.rds_db_name
    db_username = local.rds_db_username
    engine_version = local.rds_engine_version
    allocated_storage = local.rds_allocated_storage
}


module "webui_credentials" {
  source = "./modules/webui-creds"

  name_prefix = local.project
  db_username = var.webui_db_username
  db_password = var.webui_db_password
  webui_secret_key = var.webui_secret_key

  db_host = module.rds.address
  db_name = local.rds_db_name
}

module "iam" {
  source = "./modules/iam"

  name_prefix = local.project
  webui_secret_arn = module.webui_credentials.arn
  database_url_secret_arn = module.webui_credentials.database_url_secret_arn
  rds_master_secret_arn = module.rds.master_secret_arn
  smtp_password_parameter_arn = local.smtp_password_parameter_arn
}

module "efs" {
  source = "./modules/efs"

  name_prefix = local.project
  subnet_ids = module.vpc.private_servers_subnet_ids
  security_group_id = module.sg.security_group_ids["efs_sg"]
}

module "ecs" {
  source = "./modules/ecs"

  name_prefix = local.project
  execution_role_arn = module.iam.execution_role_arn
  grafana_task_role_arn = module.iam.grafana_task_role_arn
  aws_region = local.aws_region
  private_subnet_ids = module.vpc.private_servers_subnet_ids
  alb_dns = module.alb.alb_dns

  ollama_image = "${var.ecr_repository_uri}:ollama-v2"
  webui_image = "${var.ecr_repository_uri}:open-webui-v2"
  prometheus_image = "${var.ecr_repository_uri}:prometheus-v2"
  grafana_image = "${var.ecr_repository_uri}:grafana-v2"
  db_init_image = "${var.ecr_repository_uri}:db-init-v2"

  ollama_security_group_id = module.sg.security_group_ids["ollama_sg"]
  webui_security_group_id = module.sg.security_group_ids["webui_sg"]
  prometheus_security_group_id = module.sg.security_group_ids["prometheus_sg"]
  grafana_security_group_id = module.sg.security_group_ids["grafana_sg"]

  ollama_target_group_arn = module.alb.ollama_target_group_arn
  webui_target_group_arn = module.alb.webui_target_group_arn
  prometheus_target_group_arn = module.alb.prometheus_target_group_arn
  grafana_target_group_arn = module.alb.grafana_target_group_arn

  webui_secret_arn = module.webui_credentials.arn
  database_url_secret_arn = module.webui_credentials.database_url_secret_arn
  alert_email = var.alert_email

  db_host = module.rds.address
  db_name = local.rds_db_name
  rds_master_secret_arn = module.rds.master_secret_arn
  smtp_password_parameter_arn = local.smtp_password_parameter_arn

  logs_efs_id = module.efs.file_system_id
  log_router = local.log_router
}
