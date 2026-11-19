output "execution_role_arn" {
  value      = aws_iam_role.execution.arn
  depends_on = [aws_iam_role_policy_attachment.execution, aws_iam_role_policy.secrets]
}

output "grafana_task_role_arn" {
  value      = aws_iam_role.grafana.arn
  depends_on = [aws_iam_role_policy.grafana]
}

output "logs_task_role_arn" {
  value      = aws_iam_role.logs.arn
  depends_on = [aws_iam_role_policy.logs]
}