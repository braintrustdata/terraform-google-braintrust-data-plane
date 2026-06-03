override_module {
  target = module.kms
  outputs = {
    kms_key_id = "projects/test/locations/us/keyRings/test/cryptoKeys/test"
  }
}

override_module {
  target = module.database
  outputs = {
    postgres_instance_name = "braintrust-postgres"
    postgres_instance_ip   = "10.0.0.2"
    postgres_username      = "braintrust"
    postgres_password      = "test-password"
  }
}

override_module {
  target = module.redis
  outputs = {
    redis_instance_port   = 6379
    redis_instance_host   = "10.0.0.3"
    redis_server_ca_certs = []
    redis_auth_string     = "test-auth"
  }
}

override_module {
  target = module.storage
  outputs = {
    api_bucket_name        = "braintrust-api"
    brainstore_bucket_name = "braintrust-brainstore"
  }
}

override_module {
  target = module.gke-iam
  outputs = {
    braintrust_service_account = "braintrust@test.iam.gserviceaccount.com"
    brainstore_service_account = "brainstore@test.iam.gserviceaccount.com"
    braintrust_hmac_access_id  = "access-id"
    braintrust_hmac_secret     = "secret"
  }
}

variables {
  deployment_name            = "braintrust"
  deploy_gke_cluster         = false
  create_vpc                 = false
  existing_network_self_link = "projects/test-project/global/networks/braintrust"
  existing_subnet_self_link  = "projects/test-project/regions/us-central1/subnetworks/braintrust"
}

run "default_url_security_outputs_are_empty" {
  command = plan

  assert {
    condition     = output.braintrust_data_plane_unsafe_url_request_mode == "" && output.braintrust_data_plane_url_security_dns_servers == "" && output.braintrust_data_plane_url_security_allow_cidrs == ""
    error_message = "Empty URL-security inputs should produce empty Braintrust data plane outputs."
  }
}

run "configured_url_security_outputs_are_normalized" {
  command = plan

  variables {
    unsafe_url_request_mode  = " reject "
    url_security_dns_servers = " 1.1.1.1,8.8.8.8 "
    url_security_allow_cidrs = " 10.0.0.0/8,192.168.0.0/16 "
  }

  assert {
    condition = alltrue([
      output.braintrust_data_plane_unsafe_url_request_mode == "reject",
      output.braintrust_data_plane_url_security_dns_servers == "1.1.1.1,8.8.8.8",
      output.braintrust_data_plane_url_security_allow_cidrs == "10.0.0.0/8,192.168.0.0/16",
    ])
    error_message = "Non-empty URL-security inputs should be normalized in individual Braintrust data plane outputs."
  }
}
