resource "aws_ecs_cluster" "main" {
  name = "${var.name_prefix}-cluster"
  tags = {
  Name = "${var.name_prefix}-logs"
}
}