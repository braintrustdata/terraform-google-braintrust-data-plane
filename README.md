# Braintrust Terraform Google Module

This module is used to create the VPC, Databases, Redis, Storage, IAM, and associated resources for the self-hosted Braintrust data plane on Google using Google Kubernetes Engine.

## Module Configuration

Module input variables are defined in [`variables.tf`](variables.tf) and
outputs are defined in [`outputs.tf`](outputs.tf).

## GKE Cluster Modes

The module supports GKE Autopilot and GKE Standard clusters. Autopilot remains the default and is recommended.

Standard mode creates separate `services` and `brainstore` node pools. The defaults use the Arm C4A (Axion) machine series. The Brainstore pool uses Local SSD storage for Kubernetes ephemeral storage.

Node auto-upgrade is always enabled, because clusters enrolled in a release channel reject node pools that disable it. Node upgrades and repairs recreate node ephemeral storage, so treat Local SSD contents as a cache that Brainstore rebuilds.

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
  services = {
    machine_type         = "c4a-standard-16"
    total_min_node_count = 2
    total_max_node_count = 10
  }
  brainstore = {
    machine_type         = "c4a-standard-48-lssd"
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

Use `braintrust/node-pool` in the Helm node selectors. Set its value to `services` or `brainstore`.

Standard node pools use generated GKE names. Machine type, disk type, and disk size changes use the native GKE upgrade strategy.

The default surge configuration uses `max_surge = 1` and `max_unavailable = 0`. GKE waits for a new node to reach Ready state before it removes an old node.

If GCP cannot create a surge node, the update waits or fails without an intentional capacity reduction.

An Arm-to-x86 architecture change requires a separate node pool migration.

Each node has a stable `braintrust/node-pool` label for Helm node selectors.

For a resource replacement, Terraform creates the new pool before it deletes the old pool. Terraform does not verify replacement capacity.

The project needs temporary quota for surge nodes or both pool versions. A resource replacement can interrupt workloads.

The C4A machine series requires Hyperdisk boot disks. The default node-pool configuration uses `hyperdisk-balanced`. Set `disk_type` when a pool uses a machine series that does not support Hyperdisk.

### Arm and x86 nodes

The default node pools use the Arm C4A machine series.

GKE applies a `kubernetes.io/arch=arm64:NoSchedule` taint to Arm nodes by default. The module disables this taint for all Standard node pools.

Braintrust images support Arm and x86. The container runtime selects the correct image after the scheduler assigns a node.

The cluster is dedicated to Braintrust, so the architecture taint adds no workload protection. Braintrust workloads need no architecture tolerations.

Customers select only the node pool machine types. The module does not expose architecture taint behavior as an input.

The x86 C4 series is also supported. C4A is available in fewer regions than C4, so use the C4 equivalents when C4A is unavailable in the deployment region.

```hcl
gke_standard_node_pools = {
  services = {
    machine_type         = "c4-standard-16"
    total_min_node_count = 2
    total_max_node_count = 10
  }
  brainstore = {
    machine_type         = "c4-standard-48-lssd"
    total_min_node_count = 5
    total_max_node_count = 10
  }
}
```

Confirm regional availability for the machine types in use, and set `node_locations` when a machine type is missing from a cluster zone.

### Brainstore Local SSD

The `brainstore` pool must use a machine type with bundled Local SSD. These machine types carry `lssd` in the machine type name, such as `c4a-standard-48-lssd` (Arm), `c4-standard-48-lssd`, `c4d-standard-48-lssd`, or `c3d-standard-30-lssd`. The module validates this in Standard mode.

The number of Local SSD disks is a fixed property of the machine type. GKE selects that fixed count when it creates the node pool.

Customers configure only the machine type. The module has no Local SSD count input.

The singleton Brainstore writer can have a brief interruption during a node pool replacement.

The replacement deletes the node ephemeral storage. Brainstore treats that storage as a cache and rebuilds its contents.

If replacement capacity allocation fails, Terraform keeps the old pool.

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
