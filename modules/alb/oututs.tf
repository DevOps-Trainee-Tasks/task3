output "ollama_target_group_arn" {
  value = aws_lb_target_group.ollama.arn
}

output "webui_target_group_arn" {
  value = aws_lb_target_group.webui.arn
}

output "grafana_target_group_arn" {
  value = aws_lb_target_group.grafana.arn
}

output "prometheus_target_group_arn" {
  value = aws_lb_target_group.prometheus.arn
}

output "alb_dns" {
  value = aws_lb.alb.dns_name
}

output "internal_alb_dns" {
  value = aws_lb.internal.dns_name
}