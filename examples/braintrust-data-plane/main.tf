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

  ### GKE Cluster configuration
  # Note: By default we deploy a GKE cluster. You must set deploy_gke_cluster to false to not deploy a GKE cluster, if you will provide your own GKE cluster.
  # deploy_gke_cluster = true
  # gke_cluster_is_private = false # Default the cluster will be public and use public IPs addresses for the control plane
  # gke_control_plane_authorized_cidrs = null # Allow all IPs to access the control plane
  # gke_enable_private_endpoint = false # Make sure the control plane endpoint is public
  # gke_control_plane_cidr = "10.0.1.0/28" # CIDR block for the control plane if it's Private

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

}
