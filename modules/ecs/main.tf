resource "aws_ecs_cluster" "main" {
  name = "${var.name_prefix}-cluster"
  setting {
  name = "containerInsights"
  value = "enhanced"
  }
}

resource "aws_iam_role" "execution" {
  name = "${var.name_prefix}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "execution" {
  role = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "secrets" {
  name = "${var.name_prefix}-ecs-secrets"
  role = aws_iam_role.execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "ssm:GetParameters"
      ]
      Resource = [
        var.webui_secret_arn,
        var.database_url_secret_arn,
        var.rds_master_secret_arn,
        var.smtp_password_parameter_arn
      ]
    }]
  })
}

resource "aws_iam_role_policy" "grafana" {
  name = "${var.name_prefix}-grafana-cloudwatch"
  role = aws_iam_role.execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "cloudwatch:ListMetrics",
        "cloudwatch:GetMetricData"
      ]
      Resource = "*"
    }]
  })
}

