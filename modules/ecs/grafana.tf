resource "aws_cloudwatch_log_group" "grafana" {
  name = "/ecs/${var.name_prefix}/grafana"
}

resource "aws_ecs_task_definition" "grafana" {
  family = "${var.name_prefix}-grafana"
  requires_compatibilities = ["FARGATE"]
  network_mode = "awsvpc"
  cpu = 512
  memory = 1024
  execution_role_arn = var.execution_role_arn
  task_role_arn = var.grafana_task_role_arn

  container_definitions = jsonencode([{
    name = "grafana"
    image = var.grafana_image

    portMappings = [{
      containerPort = 3000
    }]

    environment = [
    {
      name = "ALERT_EMAIL"
      value = var.alert_email
    },
    {
      name = "PROMETHEUS_URL"
      value = "http://${var.alb_dns}:9090"
    },
    {
      name = "GF_SMTP_ENABLED"
      value = "true"
    },
    {
      name = "GF_SMTP_HOST"
      value = "smtp.gmail.com:587"
    },
    {
      name = "GF_SMTP_USER"
      value = var.alert_email
    },
    {
      name = "GF_SMTP_FROM_ADDRESS"
      value = var.alert_email
    }]

    secrets = [{
      name = "GF_SMTP_PASSWORD"
      valueFrom = var.smtp_password_parameter_arn
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group = aws_cloudwatch_log_group.grafana.name
        awslogs-region = var.aws_region
        awslogs-stream-prefix = "grafana"
      }
    }
  }])
}

resource "aws_ecs_service" "grafana" {
  name = "${var.name_prefix}-grafana"
  cluster = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.grafana.arn
  launch_type = "FARGATE"
  desired_count = 1

  network_configuration {
    subnets = var.private_subnet_ids
    security_groups = [var.grafana_security_group_id]
  }

  load_balancer {
    target_group_arn = var.grafana_target_group_arn
    container_name = "grafana"
    container_port = 3000
  }
}
