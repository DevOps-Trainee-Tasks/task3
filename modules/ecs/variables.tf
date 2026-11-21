variable "name_prefix" {
  type = string
}

variable "execution_role_arn" {
  type = string
}

variable "grafana_task_role_arn" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "alb_dns" {
  type = string
}

variable "internal_alb_dns" {
  type = string
}

variable "ollama_image" {
  type = string
}

variable "webui_image" {
  type = string
}

variable "prometheus_image" {
  type = string
}

variable "grafana_image" {
  type = string
}

variable "ecs_exporter_image" {
  type = string
}

variable "ollama_security_group_id" {
  type = string
}

variable "webui_security_group_id" {
  type = string
}

variable "prometheus_security_group_id" {
  type = string
}

variable "grafana_security_group_id" {
  type = string
}

variable "ollama_target_group_arn" {
  type = string
}

variable "webui_target_group_arn" {
  type = string
}

variable "prometheus_target_group_arn" {
  type = string
}

variable "grafana_target_group_arn" {
  type = string
}

variable "webui_secret_arn" {
  type = string
}

variable "database_url_secret_arn" {
  type = string
}

variable "alert_email" {
  type = string
}

variable "db_host" {
  type = string
}

variable "db_name" {
  type = string
}

variable "rds_master_secret_arn" {
  type = string
}

variable "smtp_password_parameter_arn" {
  type = string
}

variable "db_init_image" {
  type = string
}

variable "log_router" {}

variable "logs_efs_ids" {
  type = map(string)
}

variable "service_discovery_arns" {
  type = map(string)
}

variable "logs_task_role_arn" {
  type = string
}