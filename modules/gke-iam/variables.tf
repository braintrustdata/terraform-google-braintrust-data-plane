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

variable "braintrust_api_bucket_id" {
  type        = string
  description = "The ID of the GCS bucket for Braintrust API (contains code-bundle/ and response/ paths)."
}

variable "brainstore_gcs_bucket_id" {
  type        = string
  description = "The ID of the GCS bucket for Brainstore."
}

# API container doesn't support GCS native storage integration yet, so we use HMAC keys instead. 
variable "braintrust_hmac_key_enabled" {
  type        = bool
  description = "Whether to enable HMAC keys for Braintrust API."
  default     = true
}