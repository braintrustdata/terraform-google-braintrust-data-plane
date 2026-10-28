mock_provider "google" {}
mock_provider "google-beta" {}
mock_provider "random" {}

variables {
  deployment_name      = "sql-disk-test"
  postgres_network     = "projects/test/global/networks/test"
  postgres_kms_cmek_id = "projects/test/locations/us-central1/keyRings/test/cryptoKeys/test"
}

run "default_growth" {
  command = plan
  module { source = "./modules/database" }
  assert {
    condition     = google_sql_database_instance.braintrust.settings[0].disk_autoresize && google_sql_database_instance.braintrust.settings[0].disk_autoresize_limit == 0
    error_message = "Automatic disk growth must remain enabled without a custom limit."
  }
}

run "reject_small_disk" {
  command = plan
  module { source = "./modules/database" }
  variables {
    postgres_disk_size = 9
  }
  expect_failures = [var.postgres_disk_size]
}

run "n2_accepts_ten_gb_disk" {
  command = plan
  module { source = "./modules/database" }
  variables { postgres_disk_size = 10 }
  assert {
    condition     = google_sql_database_instance.braintrust.settings[0].disk_size == 10
    error_message = "N2 must retain support for a 10 GB SSD."
  }
}

run "c4a_accepts_twenty_gb_disk" {
  command = plan
  module { source = "./modules/database" }
  variables {
    postgres_machine_type = "db-c4a-highmem-8"
    postgres_disk_size    = 20
  }
  assert {
    condition     = google_sql_database_instance.braintrust.settings[0].disk_size == 20
    error_message = "C4A must accept the 20 GB Hyperdisk minimum."
  }
}
