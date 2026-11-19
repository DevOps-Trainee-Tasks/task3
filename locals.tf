locals {
    aws_region = "us-east-1"
    project = "task3"
    smtp_password_parameter_arn = "arn:aws:ssm:${local.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/task2/grafana/smtp-password"
    rds_instance_class = "db.t4g.micro"
    rds_db_name = "manualdb"
    rds_db_username = "dbadmin"
    rds_engine_version = "16"
    rds_allocated_storage = 20
    log_router = {
        name  = "log-router"
        image = "${var.ecr_repository_uri}/log-router:v4"

        firelensConfiguration = {
        type = "fluentbit"
        options = {
            config-file-type  = "file"
            config-file-value = "/extra.conf"
        }
        }

        mountPoints = [{
        sourceVolume  = "logs"
        containerPath = "/logs"
  }]
}
}
