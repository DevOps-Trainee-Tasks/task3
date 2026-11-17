resource "aws_cloudwatch_log_group" "webui" {
  name = "/ecs/${var.name_prefix}/webui"
}

resource "aws_ecs_task_definition" "webui" {
  family = "${var.name_prefix}-webui"
  requires_compatibilities = ["FARGATE"]
  network_mode = "awsvpc"
  cpu = 1024
  memory = 2048
  execution_role_arn = aws_iam_role.execution.arn

  container_definitions = jsonencode([
  {
    name = "db-init"
    image = "public.ecr.aws/docker/library/postgres:16-alpine"
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

    command = ["sh", "-ec", <<-SCRIPT
      until pg_isready; do sleep 3; done

      psql -v ON_ERROR_STOP=1 \
        -v dbuser="$WEBUI_DB_USERNAME" \
        -v dbpass="$WEBUI_DB_PASSWORD" <<'SQL'
      CREATE EXTENSION IF NOT EXISTS vector;

      SELECT format('CREATE ROLE %I LOGIN', :'dbuser')
      WHERE NOT EXISTS (
        SELECT 1 FROM pg_roles WHERE rolname = :'dbuser'
      ) \gexec

      SELECT format('ALTER ROLE %I PASSWORD %L', :'dbuser', :'dbpass') \gexec
      SELECT format('GRANT USAGE, CREATE ON SCHEMA public TO %I', :'dbuser') \gexec
      SQL
    SCRIPT
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group = aws_cloudwatch_log_group.webui.name
        awslogs-region = var.aws_region
        awslogs-stream-prefix = "db-init"
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
      value = "http://${var.alb_dns}:11434"
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
      logDriver = "awslogs"
      options = {
        awslogs-group = aws_cloudwatch_log_group.webui.name
        awslogs-region = var.aws_region
        awslogs-stream-prefix = "webui"
      }
    }
  }
  ])
}

resource "aws_ecs_service" "webui" {
  name = "${var.name_prefix}-webui"
  cluster = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.webui.arn
  launch_type = "FARGATE"
  desired_count = 1

  network_configuration {
    subnets = var.private_subnet_ids
    security_groups = [var.webui_security_group_id]
  }

  load_balancer {
    target_group_arn = var.webui_target_group_arn
    container_name = "webui"
    container_port = 8080
  }

  depends_on = [aws_iam_role_policy.secrets]
}
