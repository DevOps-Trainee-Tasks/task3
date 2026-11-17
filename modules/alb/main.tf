resource "aws_lb" "alb" {
  name = "${var.name_prefix}-alb"
  subnets = var.public_subnet_ids
  security_groups = [var.security_groups_id]
  idle_timeout = 180
}

resource "aws_lb_target_group" "ollama" {
  name = "${var.name_prefix}-ollama"
  vpc_id = var.vpc_id
  port = var.ollama_port
  protocol = "HTTP"
  target_type = "ip"

  health_check {
    path = "/api/tags"
  }
}

resource "aws_lb_target_group" "webui" {
  name = "${var.name_prefix}-webui"
  vpc_id = var.vpc_id
  port = 8080
  protocol = "HTTP"
  target_type = "ip"

  health_check {
    path = "/"
    matcher = "200-399"
  }
}

resource "aws_lb_target_group" "grafana" {
  name = "${var.name_prefix}-grafana"
  vpc_id = var.vpc_id
  port = 3000
  protocol = "HTTP"
  target_type = "ip"

  health_check {
    path = "/api/health"
  }
}

resource "aws_lb_target_group" "prometheus" {
  name = "${var.name_prefix}-prometheus"
  vpc_id = var.vpc_id
  port = 9090
  protocol = "HTTP"
  target_type = "ip"

  health_check {
    path = "/-/healthy"
  }
}

resource "aws_lb_listener" "ollama" {
  load_balancer_arn = aws_lb.alb.arn
  port = var.ollama_port
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.ollama.arn
  }
}

resource "aws_lb_listener" "webui" {
  load_balancer_arn = aws_lb.alb.arn
  port = 80
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.webui.arn
  }
}

resource "aws_lb_listener" "grafana" {
  load_balancer_arn = aws_lb.alb.arn
  port = 3000
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.grafana.arn
  }
}

resource "aws_lb_listener" "prometheus" {
  load_balancer_arn = aws_lb.alb.arn
  port = 9090
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.prometheus.arn
  }
}