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

  container_definitions = jsonencode([{
    name = "prometheus"
    image = var.prometheus_image

    portMappings = [{
      containerPort = 9090
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group = aws_cloudwatch_log_group.prometheus.name
        awslogs-region = var.aws_region
        awslogs-stream-prefix = "prometheus"
      }
    }
  }])
}

resource "aws_ecs_service" "prometheus" {
  name = "${var.name_prefix}-prometheus"
  cluster = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.prometheus.arn
  launch_type = "FARGATE"
  desired_count = 1

  network_configuration {
    subnets = var.private_subnet_ids
    security_groups = [var.prometheus_security_group_id]
  }

  load_balancer {
    target_group_arn = var.prometheus_target_group_arn
    container_name = "prometheus"
    container_port = 9090
  }
}
