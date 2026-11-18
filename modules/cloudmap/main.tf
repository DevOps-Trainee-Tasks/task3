resource "aws_service_discovery_private_dns_namespace" "main" {
  name = "${var.name_prefix}.local"
  vpc = var.vpc_id
}

resource "aws_service_discovery_service" "main" {
  for_each = toset(var.service_names)

  name = each.key

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id
    routing_policy = "MULTIVALUE"

    dns_records {
      type = "A"
      ttl = 10
    }
  }
}