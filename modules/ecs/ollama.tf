resource "aws_cloudwatch_log_group" "ollama" {
  name = "/ecs/${var.name_prefix}/ollama"
}

resource "aws_ecs_task_definition" "ollama" {
  family = "${var.name_prefix}-ollama"
  requires_compatibilities = ["FARGATE"]
  network_mode = "awsvpc"
  cpu = 2048
  memory = 8192
  execution_role_arn = var.execution_role_arn

  container_definitions = jsonencode([var.log_router, {
    name = "ollama"
    image = var.ollama_image

    portMappings = [{
      containerPort = 11434
    }]

    logConfiguration = {
      logDriver = "awsfirelens"
      options = {
        Name = "file"
        Path = "/logs/ollama"
        Mkdir = "true"
      }
    }
  }])
  volume {
    name = "logs"

    efs_volume_configuration {
      file_system_id = var.logs_efs_id
      transit_encryption = "ENABLED"
    }
  }
}

resource "aws_ecs_service" "ollama" {
  name = "${var.name_prefix}-ollama"
  cluster = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.ollama.arn
  launch_type = "FARGATE"
  desired_count = 2

  network_configuration {
    subnets = var.private_subnet_ids
    security_groups = [var.ollama_security_group_id]
  }

  load_balancer {
    target_group_arn = var.ollama_target_group_arn
    container_name = "ollama"
    container_port = 11434
  }
}
