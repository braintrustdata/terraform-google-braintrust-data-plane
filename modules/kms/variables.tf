#----------------------------------------------------------------------------------------------
# Common
#----------------------------------------------------------------------------------------------
variable "deployment_name" {
  description = "Name of the deployment. Used to prefix resource names."
  type        = string
}

variable "custom_labels" {
  type        = map(string)
  description = "Optional labels to apply to all resources that support labels."
  default     = {}
}
