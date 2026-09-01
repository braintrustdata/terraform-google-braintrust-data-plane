# Braintrust Terraform Google Module

This module is used to create the VPC, Databases, Redis, Storage, IAM, and associated resources for the self-hosted Braintrust data plane on Google using Google Kubernetes Engine.

## Module Configuration

Module input variables are defined in [`variables.tf`](variables.tf) and
outputs are defined in [`outputs.tf`](outputs.tf).

## GKE Cluster Modes

The module supports GKE Autopilot and GKE Standard clusters. Autopilot remains the default and is recommended.

Standard mode creates separate `api` and `brainstore` node pools. The Brainstore pool uses Local SSD storage for Kubernetes ephemeral storage.

> [!WARNING]
> A deployment must keep its initial `gke_cluster_mode`.
> A mode change replaces the GKE cluster and causes data-plane downtime.
> The replacement cluster requires redeployment of the Braintrust Helm release.

### Configure Standard mode

Set `gke_cluster_mode` to `standard`.

```hcl
gke_cluster_mode = "standard"
```

Adjust the default node pools for the workload and regional quota.

Set `node_locations` for a machine type that is unavailable in one or more zones.
Leave `node_locations` unset to use the cluster node locations.

```hcl
gke_standard_node_pools = {
  api = {
    machine_type         = "c4-standard-16"
    total_min_node_count = 2
    total_max_node_count = 10
  }
  brainstore = {
    machine_type         = "c4-standard-48-lssd"
    total_min_node_count = 3
    total_max_node_count = 10
    node_locations = [
      "us-central1-a",
      "us-central1-b",
      "us-central1-c",
    ]
  }
}
```

Set the Helm value `google.mode` to `standard`.

Use the `api` and `brainstore` pool names in the Helm node selectors.

The C4 machine series requires Hyperdisk boot disks. The default node-pool configuration uses `hyperdisk-balanced`.

The `c4-standard-48-lssd` machine type includes Local SSD disks. GKE configures those disks as node ephemeral storage.

## How to use this module

To use this module, **copy the [`examples/braintrust-data-plane`](examples/braintrust-data-plane) directory to a new Terraform directory in your own repository**. Follow the instructions in the [README.md](examples/braintrust-data-plane/README.md) file in that directory to configure the module for your environment.

Please review the README.md in the examples for all Pre-deployment and Post-Deployment steps in order to deploy Braintrust on Google.

The default configuration is a large production-sized deployment. Please consider that when testing and adjust the configuration to use smaller sized resources.

## Development Setup

This section is only relevant if you are a contributor who wants to make changes to this module. All others can skip this section.

1. Clone the repository
2. Install [mise](https://mise.jdx.dev/about.html):

    ```bash
    curl https://mise.run | sh
    echo 'eval "$(mise activate zsh)"' >> "~/.zshrc"
    echo 'eval "$(mise activate zsh --shims)"' >> ~/.zprofile
    exec $SHELL
    ```

3. Run `mise install` to install required tools
4. Run `mise run setup` to install pre-commit hooks

## TODO

- This module will fail the first time it is deployed due to timing issue with the private connection for the VPC. Exploring ways to fix this still without adding a module depends on which causes issues.
- Explore customer support module like AWS module
- Explore using Terraform to enable google services instead of CLI/GUI
