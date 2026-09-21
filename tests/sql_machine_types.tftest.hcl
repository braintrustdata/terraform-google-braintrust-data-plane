mock_provider "google" {}
mock_provider "google-beta" {}
mock_provider "random" {}

variables {
  deployment_name      = "sql-test"
  postgres_network     = "projects/test/global/networks/test"
  postgres_kms_cmek_id = "projects/test/locations/us-central1/keyRings/test/cryptoKeys/test"
}

run "n2_defaults" {
  command = plan
  module { source = "./modules/database" }
  assert {
    condition = (
      google_sql_database_instance.braintrust.settings[0].edition == "ENTERPRISE_PLUS" &&
      google_sql_database_instance.braintrust.settings[0].disk_type == "PD_SSD"
    )
    error_message = "The machine type must select compatible edition and storage settings."
  }
  assert {
    condition     = google_sql_database_instance.braintrust.settings[0].data_cache_config[0].data_cache_enabled == true
    error_message = "The module must keep the data cache enabled."
  }
}

# Mock providers do not verify Cloud SQL machine capabilities.
# Cloud SQL rejects this cache configuration during a real apply.
run "c4a_two_cpu_keeps_cache_enabled" {
  command = plan
  module { source = "./modules/database" }
  variables { postgres_machine_type = "db-c4a-highmem-2" }
  assert {
    condition = (
      google_sql_database_instance.braintrust.settings[0].edition == "ENTERPRISE_PLUS" &&
      google_sql_database_instance.braintrust.settings[0].disk_type == "HYPERDISK_BALANCED"
    )
    error_message = "The machine type must select compatible edition and storage settings."
  }
  assert {
    condition     = google_sql_database_instance.braintrust.settings[0].data_cache_config[0].data_cache_enabled == true
    error_message = "The module must keep the data cache enabled."
  }
}

run "c4a_four_cpu" {
  command = plan
  module { source = "./modules/database" }
  variables { postgres_machine_type = "db-c4a-highmem-4" }
  assert {
    condition = (
      google_sql_database_instance.braintrust.settings[0].edition == "ENTERPRISE_PLUS" &&
      google_sql_database_instance.braintrust.settings[0].disk_type == "HYPERDISK_BALANCED"
    )
    error_message = "The machine type must select compatible edition and storage settings."
  }
  assert {
    condition     = google_sql_database_instance.braintrust.settings[0].data_cache_config[0].data_cache_enabled == true
    error_message = "The module must keep the data cache enabled."
  }
}

run "c4" {
  command = plan
  module { source = "./modules/database" }
  variables { postgres_machine_type = "db-perf-optimized-C4-2" }
  assert {
    condition = (
      google_sql_database_instance.braintrust.settings[0].edition == "ENTERPRISE_PLUS" &&
      google_sql_database_instance.braintrust.settings[0].disk_type == "HYPERDISK_BALANCED"
    )
    error_message = "The machine type must select compatible edition and storage settings."
  }
  assert {
    condition     = google_sql_database_instance.braintrust.settings[0].data_cache_config[0].data_cache_enabled == true
    error_message = "The module must keep the data cache enabled."
  }
}

run "hyperdisk_performance" {
  command = plan
  module { source = "./modules/database" }
  variables {
    postgres_machine_type                = "db-c4a-highmem-4"
    postgres_disk_provisioned_iops       = 12000
    postgres_disk_provisioned_throughput = 500
  }
  assert {
    condition = (
      google_sql_database_instance.braintrust.settings[0].data_disk_provisioned_iops == 12000 &&
      google_sql_database_instance.braintrust.settings[0].data_disk_provisioned_throughput == 500
    )
    error_message = "The resource must receive custom Hyperdisk performance settings."
  }
}

run "reject_ssd_performance" {
  command = plan
  module { source = "./modules/database" }
  variables {
    postgres_disk_provisioned_iops = 4000
  }
  expect_failures = [var.postgres_disk_provisioned_iops]
}

run "reject_small_hyperdisk" {
  command = plan
  module { source = "./modules/database" }
  variables {
    postgres_machine_type = "db-c4a-highmem-2"
    postgres_disk_size    = 10
  }
  expect_failures = [var.postgres_disk_size]
}

run "reject_unknown_series" {
  command = plan
  module { source = "./modules/database" }
  variables {
    postgres_machine_type = "db-unknown-2"
  }
  expect_failures = [var.postgres_machine_type]
}

run "reject_low_iops" {
  command = plan
  module { source = "./modules/database" }
  variables {
    postgres_disk_provisioned_iops = 2999
    postgres_machine_type          = "db-c4a-highmem-2"
  }
  expect_failures = [var.postgres_disk_provisioned_iops]
}

run "reject_low_throughput" {
  command = plan
  module { source = "./modules/database" }
  variables {
    postgres_disk_provisioned_throughput = 139
    postgres_machine_type                = "db-c4a-highmem-2"
  }
  expect_failures = [var.postgres_disk_provisioned_throughput]
}

run "reject_enterprise_n4" {
  command = plan
  module { source = "./modules/database" }
  variables { postgres_machine_type = "db-custom-N4-2-16384" }
  expect_failures = [var.postgres_machine_type]
}

run "reject_enterprise_custom" {
  command = plan
  module { source = "./modules/database" }
  variables { postgres_machine_type = "db-custom-2-8192" }
  expect_failures = [var.postgres_machine_type]
}

run "reject_enterprise_shared_core" {
  command = plan
  module { source = "./modules/database" }
  variables { postgres_machine_type = "db-f1-micro" }
  expect_failures = [var.postgres_machine_type]
}

run "reject_ssd_throughput" {
  command = plan
  module { source = "./modules/database" }
  variables { postgres_disk_provisioned_throughput = 200 }
  expect_failures = [var.postgres_disk_provisioned_throughput]
}
