output "service_arns" {
  value = {
    for name, service in aws_service_discovery_service.main :
    name => service.arn
  }
}