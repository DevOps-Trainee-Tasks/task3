resource "aws_secretsmanager_secret" "webui" {
  name_prefix = "${var.name_prefix}/webui-"
}

resource "aws_secretsmanager_secret_version" "webui" {
  secret_id = aws_secretsmanager_secret.webui.id

  secret_string = jsonencode({
    db_username = var.db_username
    db_password = var.db_password
    webui_secret_key = var.webui_secret_key
  })
}

resource "aws_secretsmanager_secret" "database_url" {
  name_prefix = "${var.name_prefix}/webui-database-url-"
}

resource "aws_secretsmanager_secret_version" "database_url" {
  secret_id = aws_secretsmanager_secret.database_url.id
  secret_string = "postgresql://${urlencode(var.db_username)}:${urlencode(var.db_password)}@${var.db_host}:5432/${var.db_name}"
}