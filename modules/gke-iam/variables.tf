#----------------------------------------------------------------------------------------------
# Common
#----------------------------------------------------------------------------------------------
variable "deployment_name" {
  description = "Name of the deployment. Used to prefix resource names."
  type        = string
}

#----------------------------------------------------------------------------------------------
# GKE Cluster
#----------------------------------------------------------------------------------------------

variable "braintrust_kube_namespace" {
  type        = string
  description = "The namespace of the Braintrust service account in the GKE cluster."
  default     = "braintrust"
}

variable "braintrust_kube_svc_account" {
  type        = string
  description = "The service account of the Braintrust API in the GKE cluster."
  default     = "braintrust-api"
}

variable "brainstore_kube_svc_account" {
  type        = string
  description = "The service account of the Brainstore in the GKE cluster."
  default     = "brainstore"
}

variable "braintrust_response_bucket_id" {
  type        = string
  description = "The ID of the GCS bucket for Braintrust response."
}

variable "braintrust_code_bundle_bucket_id" {
  type        = string
  description = "The ID of the GCS bucket for Braintrust code bundle."
}

variable "brainstore_gcs_bucket_id" {
  type        = string
  description = "The ID of the GCS bucket for Brainstore."
}

variable "region" {
  type        = string
  description = "The region to deploy resources to."
}
