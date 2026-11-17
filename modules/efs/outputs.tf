output "file_system_id" {
  value = aws_efs_file_system.logs.id
  depends_on = [aws_efs_mount_target.logs]
}