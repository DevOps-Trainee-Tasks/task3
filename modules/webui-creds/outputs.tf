output "arn" {
  value = aws_secretsmanager_secret_version.webui.secret_arn
}

output "database_url_secret_arn" {
  value = aws_secretsmanager_secret.database_url.arn
}