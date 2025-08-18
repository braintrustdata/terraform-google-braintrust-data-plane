# Braintrust Terraform Google Module

This module is currently beta status. There may be breaking changes that require a complete deletion and re-deployment

This module is used to create the VPC, Databases, Redis, Storage, IAM, and associated resources for the self-hosted Braintrust data plane on Google using Google Kubernetes Engine.

## Module Configuration

All module input variables and outputs are documented here:
[`module-docs.md`](module-docs.md)

## How to use this module

To use this module, **copy the [`examples/braintrust-data-plane`](examples/braintrust-data-plane) directory to a new Terraform directory in your own repository**. Follow the instructions in the [`README.md`](examples/braintrust-data-plane/README.md) file in that directory to configure the module for your environment.

The default configuration is a large production-sized deployment. Please consider that when testing and adjust the configuration to use smaller sized resources.

## Prereqs

- Google Project created
- All necessary APIs and services enabled. Steps to do so are below.

### Enabling APIs

With GCP, their services or APIs are disabled by default in a project. When trying to deploy the necessary resources for the Braintrust Module, if the necessary Services are not enabled, the Terraform Apply will fail. These services can be enabled via the console, or using the below script with a Google Cloud Shell, they can be enabled programmatically. Also need to explore enabling them via TF instead.

1. Open a new Cloud Shell and set the project to the project that Braintrust will be deployed into.

```bash
gcloud config set project "project id"
```

2. The below code will enable all the services that are required for Braintrust. Some of these may already be enabled

```bash
services_to_enable=("storage-api.googleapis.com" "storage-component.googleapis.com" "storage.googleapis.com" "redis.googleapis.com" "secretmanager.googleapis.com" "servicenetworking.googleapis.com" "logging.googleapis.com" "monitoring.googleapis.com" "oslogin.googleapis.com" "dns.googleapis.com" "cloudresourcemanager.googleapis.com" "compute.googleapis.com" "cloudkms.googleapis.com" "autoscaling.googleapis.com" "iam.googleapis.com" "iamcredentials.googleapis.com" "vpcaccess.googleapis.com" "sts.googleapis.com") 

for service in ${services_to_enable[*]}; do
      echo $service
      gcloud services enable $service
done
```

3. Wait 5~ minutes for the services to be enabled.

## Customized Deployments

It is highly recommended to use our root module to deploy Braintrust. It will make support and upgrades far easier. However, if you need to customize the deployment, you can pick and choose from our submodules since they are easily composable.

Look at our `main.tf` as a reference for how to configure the submodules. For example, if you wanted to re-use an existing VPC, you could remove the `module.main_vpc` block and pass in the existing VPC's ID, subnets, and security group IDs to the `services`, `database`, and `redis` modules.


## Development Setup

This section is only relevant if you are a contributor who wants to make changes to this module. All others can skip this section.

1. Clone the repository
2. Install [mise](https://mise.jdx.dev/about.html):
    ```
    curl https://mise.run | sh
    echo 'eval "$(mise activate zsh)"' >> "~/.zshrc"
    echo 'eval "$(mise activate zsh --shims)"' >> ~/.zprofile
    exec $SHELL
    ```
3. Run `mise install` to install required tools
4. Run `mise run setup` to install pre-commit hooks

## TODO

- Logging is configured to use the default project log sink, need to determine if a custom log sink will be needed. Project related resources and brainstore docker logs are being sent to it.
- The default brainstore instance sizes may be too large for your project quota
- This module will fail the first time it is deployed due to timing issue with the private connection for the VPC. Exploring ways to fix this still without adding a module depends on which causes issues.