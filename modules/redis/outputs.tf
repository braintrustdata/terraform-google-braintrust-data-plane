output "redis_instance_name" {
  value = google_redis_instance.braintrust.name
}

output "redis_instance_ip" {
  value = google_redis_instance.braintrust.host
}