resource "aws_lb" "alb" {
  name = "${var.name_prefix}-alb"
  subnets = var.public_subnet_ids
  security_groups = [var.security_groups_id]
  idle_timeout = 180
}

resource "aws_lb" "internal" {
  name = "${var.name_prefix}-internal-alb"
  internal = true
  subnets = var.private_subnet_ids
  security_groups = [var.internal_security_group_id]
  idle_timeout = 180
}

resource "aws_lb_listener" "internal" {
  load_balancer_arn = aws_lb.internal.arn
  port = 80

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.ollama.arn
  }
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
    path = "/grafana/api/health"
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

resource "aws_lb_listener" "webui" {
  load_balancer_arn = aws_lb.alb.arn
  port = 80

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.webui.arn
  }
}

resource "aws_lb_listener_rule" "grafana" {
  listener_arn = aws_lb_listener.webui.arn

  condition {
    path_pattern {
      values = ["/grafana", "/grafana/*"]
    }
  }

  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.grafana.arn
  }
}

resource "aws_lb_listener_rule" "prometheus" {
  listener_arn = aws_lb_listener.webui.arn

  condition {
    path_pattern {
      values = ["/prometheus", "/prometheus/*"]
    }
  }

  transform {
    type = "url-rewrite"

    url_rewrite_config {
      rewrite {
        regex = "^/prometheus/?(.*)$"
        replace = "/$1"
      }
    }
  }

  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.prometheus.arn
  }
}