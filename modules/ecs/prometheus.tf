resource "aws_cloudwatch_log_group" "prometheus" {
  name = "/ecs/${var.name_prefix}/prometheus"
}

resource "aws_ecs_task_definition" "prometheus" {
  family = "${var.name_prefix}-prometheus"
  requires_compatibilities = ["FARGATE"]
  network_mode = "awsvpc"
  cpu = 512
  memory = 1024
  execution_role_arn = var.execution_role_arn
  task_role_arn = var.logs_task_role_arn

  container_definitions = jsonencode([var.log_router, {
    name = "prometheus"
    image = var.prometheus_image
    command = [
      "--config.file=/etc/prometheus/prometheus.yml",
      "--storage.tsdb.path=/prometheus",
      "--storage.tsdb.retention.size=2GB",
      "--web.external-url=http://${var.alb_dns}/prometheus/",
      "--web.route-prefix=/"
    ]

    portMappings = [{
      containerPort = 9090
    }]

    logConfiguration = {
      logDriver = "awsfirelens"
    }
  }])
  volume {
    name = "logs"

    efs_volume_configuration {
      file_system_id = var.logs_efs_ids["prometheus"]
      transit_encryption = "ENABLED"
    }
  }
}

resource "aws_ecs_service" "prometheus" {
  name = "${var.name_prefix}-prometheus"
  cluster = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.prometheus.arn
  launch_type = "FARGATE"
  desired_count = 2

  network_configuration {
    subnets = var.private_subnet_ids
    security_groups = [var.prometheus_security_group_id]
  }

  service_registries {
    registry_arn = var.service_discovery_arns["prometheus"]
  }

  load_balancer {
    target_group_arn = var.prometheus_target_group_arn
    container_name = "prometheus"
    container_port = 9090
  }
}
