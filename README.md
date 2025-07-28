# terraform-google-braintrust-data-plane

This module is currently alpha status and does not contain all necessary resources for a proper braintrust deployment yet.

- By Default everything is encrypted by default using google's KMS keys. Customer Manged Keys should be work fine, however this hasn't been tested yet.
- Logging is configured to use the default project log sink, need to determine if a custom log sink will be needed. Project related resources and brainstore docker logs are being sent to it.
- The default brainstore instance sizes are too large for the default CPU limit, recommend using `c4a-standard-4-lssd` for now. Need to explore requesting a quota limit increase via TF or Code
- The API layer is missing from this module along with the remote support module
- This module will fail the first time it is deployed due to timing issue with the private connection for the VPC. Exploring ways to fix this still without adding a module depends on which causes issues.

## Prereqs

- Google Project created
- All necessary APIs and services enabled. Steps to do so are below.
- A google secret created containing the brainstore license key.

### Enabling APIs

With GCP, their services or APIs are disabled by default in a project. When trying to deploy the necessary resources for the Braintrust Module, if the necessary Services are not enabled, the Terraform Apply will fail. These services can be enabled via the console, or using the below script with a Google Cloud Shell, they can be enabled programmatically. Also need to explore enabling them via TF instead.

1. Open a new Cloud Shell and set the project to the project that Braintrust will be deployed into.

```bash
gcloud config set project "project id"
```

2. The below code will enable all the services that are required for Braintrust. Some of these may already be enabled

```bash
services_to_enable=("storage-api.googleapis.com" "storage-component.googleapis.com" "storage.googleapis.com" "secretmanager.googleapis.com" "servicenetworking.googleapis.com" "logging.googleapis.com" "monitoring.googleapis.com" "oslogin.googleapis.com" "dns.googleapis.com" "cloudresourcemanager.googleapis.com" "compute.googleapis.com" "cloudkms.googleapis.com" "autoscaling.googleapis.com" "iam.googleapis.com" "iamcredentials.googleapis.com" "vpcaccess.googleapis.com" "sts.googleapis.com") 

for service in ${services_to_enable[*]}; do
      echo $service
      gcloud services enable $service
done
```

3. Wait 5~ minutes for the services to be enabled.
