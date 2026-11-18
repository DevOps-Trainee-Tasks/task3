resource "aws_cloudwatch_log_group" "webui" {
  name = "/ecs/${var.name_prefix}/webui"
}

resource "aws_ecs_task_definition" "webui" {
  family = "${var.name_prefix}-webui"
  requires_compatibilities = ["FARGATE"]
  network_mode = "awsvpc"
  cpu = 1024
  memory = 2048
  execution_role_arn = var.execution_role_arn

  container_definitions = jsonencode([
    var.log_router,
  {
    name = "db-init"
    image = var.db_init_image
    essential = false

    environment = [
      {
        name = "PGHOST"
        value = var.db_host
      },
      {
        name = "PGDATABASE"
        value = var.db_name
      }
    ]

    secrets = [
      {
        name = "PGUSER"
        valueFrom = "${var.rds_master_secret_arn}:username::"
      },
      {
        name = "PGPASSWORD"
        valueFrom = "${var.rds_master_secret_arn}:password::"
      },
      {
        name = "WEBUI_DB_USERNAME"
        valueFrom = "${var.webui_secret_arn}:db_username::"
      },
      {
        name = "WEBUI_DB_PASSWORD"
        valueFrom = "${var.webui_secret_arn}:db_password::"
      }
    ]

    logConfiguration = {
      logDriver = "awsfirelens"
      options = {
        Name = "file"
        Path = "/logs/webui"
        Mkdir = "true"
      }
    }
  },
  {
    name = "webui"
    image = var.webui_image

    dependsOn = [{
      containerName = "db-init"
      condition = "SUCCESS"
    }]

    portMappings = [{
      containerPort = 8080
    }]

    environment = [{
      name = "OLLAMA_BASE_URL"
      value = "http://${var.internal_alb_dns}"
    }]

    secrets = [
      {
        name = "WEBUI_SECRET_KEY"
        valueFrom = "${var.webui_secret_arn}:webui_secret_key::"
      },
      {
        name = "DATABASE_URL"
        valueFrom = var.database_url_secret_arn
      }
    ]

    logConfiguration = {
      logDriver = "awsfirelens"
      options = {
        Name = "file"
        Path = "/logs/webui"
        Mkdir = "true"
      }
    }
  }
  ])
  volume {
    name = "logs"

    efs_volume_configuration {
      file_system_id = var.logs_efs_ids["webui"]
      transit_encryption = "ENABLED"
    }
  }
}

resource "aws_ecs_service" "webui" {
  name = "${var.name_prefix}-webui"
  cluster = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.webui.arn
  launch_type = "FARGATE"
  desired_count = 2

  network_configuration {
    subnets = var.private_subnet_ids
    security_groups = [var.webui_security_group_id]
  }

  load_balancer {
    target_group_arn = var.webui_target_group_arn
    container_name = "webui"
    container_port = 8080
  }
}
