output "redis_instance_name" {
  value = google_redis_instance.braintrust.name
}

output "redis_instance_host" {
  value = google_redis_instance.braintrust.host
}

output "redis_instance_port" {
  value = google_redis_instance.braintrust.port
}

output "redis_server_ca_certs" {
  value = google_redis_instance.braintrust.server_ca_certs
}

