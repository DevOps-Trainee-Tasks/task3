resource "aws_efs_file_system" "logs" {
  creation_token = "${var.name_prefix}-logs"

  tags = {
    Name = "${var.name_prefix}-logs"
  }
}

resource "aws_efs_mount_target" "logs" {
  count = length(var.subnet_ids)

  file_system_id  = aws_efs_file_system.logs.id
  subnet_id = var.subnet_ids[count.index]
  security_groups = [var.security_group_id]
}