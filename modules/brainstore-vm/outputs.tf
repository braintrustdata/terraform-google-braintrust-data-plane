output "brainstore_reader_instance_group_manager_name" {
  value = google_compute_region_instance_group_manager.brainstore_reader.name
}

output "brainstore_writer_instance_group_manager_name" {
  value = google_compute_region_instance_group_manager.brainstore_writer.name
}

output "brainstore_reader_load_balancer_ip" {
  value = google_compute_address.brainstore_reader_frontend_lb.address
}

output "brainstore_writer_load_balancer_ip" {
  value = google_compute_address.brainstore_writer_frontend_lb.address
}

output "brainstore_reader_port" {
  value = var.brainstore_port
}

output "brainstore_writer_port" {
  value = var.brainstore_port
}