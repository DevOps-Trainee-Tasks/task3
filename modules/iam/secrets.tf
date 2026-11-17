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
