# tflint-ignore-file: terraform_module_pinned_source

module "braintrust-data-plane" {
  source = "github.com/braintrustdata/terraform-google-braintrust-data-plane"
  # Append '?ref=<version_tag>' to lock to a specific version of the module.

  ### Examples below are shown with the module defaults. You do not have to uncomment them
  ### unless you want to change the default value.
  ### The default values are for production-sized deployments.

  # This is primarily used for labeling and naming resources in your Google Project.
  # Do not change this after deployment.
  deployment_name = "braintrust"

  ### Network configuration
  # WARNING: You should choose these values carefully after discussing with your networking team.
  # Changing them after the fact is not possible and will require a complete rebuild of your Braintrust deployment.
  # CIDR block for the VPC. The core Braintrust services will be deployed in this VPC.
  # You might need to adjust this so it does not conflict with any other VPC CIDR blocks you intend to peer with Braintrust.

  # The CIDR range for the subnet to deploy resources to.
  # subnet_cidr_range = "10.0.0.0/24"
  #
  # Private Service Access range for Cloud SQL and Memorystore. Defaults to a Google-selected /16.
  # Set these if you need the private services peering range to avoid overlap with existing networks.
  # Smaller ranges are supported, but reduce future expansion headroom.
  # Changing this after deployment can require rebuilding dependent resources.
  # private_service_access_prefix_length = 16
  # private_service_access_address       = "10.10.0.0"

  ### GKE Cluster configuration
  # Note: By default we deploy a GKE cluster. You must set deploy_gke_cluster to false to not deploy a GKE cluster, if you will provide your own GKE cluster.
  # deploy_gke_cluster = true
  # gke_cluster_is_private = false # Default the cluster will be public and use public IPs addresses for the control plane
  # gke_control_plane_authorized_cidrs = null # Allow all IPs to access the control plane
  # gke_enable_private_endpoint = false # Make sure the control plane endpoint is public
  # gke_control_plane_cidr = "10.0.1.0/28" # CIDR block for the control plane if it's Private
  # Optional GKE Pod and Service IP ranges. Set these only if you need to control the secondary ranges
  # used by the cluster, especially to avoid overlap with peered VPCs or corporate networks.
  # Most deployments should leave the Service range unset unless they intentionally need a custom Service CIDR.
  # You can either provide CIDR blocks, netmask sizes such as "/20", or secondary range names
  # that already exist on the subnet.
  # Do not set both forms for the same range type. Changing these after deployment is disruptive.
  # gke_pods_ipv4_cidr_block = "10.20.0.0/20"
  # gke_services_ipv4_cidr_block = "10.30.0.0/22"
  # gke_pods_secondary_range_name = "braintrust-pods"
  # gke_services_secondary_range_name = "braintrust-services"

  ### Database configuration
  # postgres_version = "POSTGRES_17"
  # postgres_machine_type = "db-perf-optimized-N-8"
  # postgres_availability_type = "REGIONAL"
  # postgres_disk_size = 1000
  # Does this auto expand? how do we handle that?
  # How do we control disk perf IOPS/etc

  ### Redis configuration
  # redis_version = "REDIS_7_2"
  # redis_memory_size_gb = 3


  ### Advanced configuration
  # gcs_additional_allowed_origins = []

  # Optional Braintrust data plane URL-security config. Leave unset or empty to omit these
  # values. When unsafe_url_request_mode is omitted, the application defaults to warn.
  # unsafe_url_request_mode  = "reject"
  # url_security_dns_servers = "1.1.1.1,8.8.8.8"
  # url_security_allow_cidrs = "10.0.0.0/8,192.168.0.0/16"

}
