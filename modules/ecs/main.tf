resource "aws_ecs_cluster" "main" {
  name = "${var.name_prefix}-cluster"
  setting {
  name = "containerInsights"
  value = "enhanced"
  }
  tags = {
  Name = "${var.name_prefix}-logs"
}
}