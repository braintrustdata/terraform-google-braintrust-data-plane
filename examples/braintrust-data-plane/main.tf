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

  ### Database configuration
  # postgres_version = "POSTGRES_17"
  # postgres_machine_type = "db-perf-optimized-N-8"
  # postgres_availability_type = "REGIONAL"
  # postgres_disk_size = 1000
  # postgres_backup_start_time = "00:30"
  # postgres_maintenance_window = {
  #   day = 1, hour = 8, update_track = "stable"
  # }

  ### Redis configuration
  # redis_version = "REDIS_7_2"
  # redis_memory_size_gb = 3

  ### Storage configuration
  # gcs_additional_allowed_origins = []
  # gcs_bucket_retention_days = 7
  # gcs_versioning_enabled = true
  # gcs_storage_class = "STANDARD"
  # gcs_uniform_bucket_level_access = true

  ### GKE IAM configuration 
  # Note: These values must match the kubernetes namespace and service account names when deploying the helm chart

  # braintrust_kube_namespace = "braintrust"
  # braintrust_kube_svc_account = "braintrust-api"
  # brainstore_kube_svc_account = "brainstore"

  ### GKE Cluster configuration
  # Note: By default we do not deploy a GKE cluster. You must set deploy_gke_cluster to true to deploy a GKE cluster.

  # deploy_gke_cluster = true 

  # gke_cluster_is_private = true
  # gke_control_plane_cidr = "10.0.1.0/28"
  # gke_control_plane_authorized_cidr = "<your_internal or external cidr/24>"
  # gke_node_type = "c4a-standard-16-lssd"
  # gke_release_channel = "REGULAR"
  # gke_enable_private_endpoint = true
  # gke_node_count = 1
  # gke_deletion_protection = true
}

