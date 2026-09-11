# Braintrust Terraform Google Module

This module is used to create the VPC, Databases, Redis, Storage, IAM, and associated resources for the self-hosted Braintrust data plane on Google using Google Kubernetes Engine.

## Module Configuration

Module input variables are defined in [`variables.tf`](variables.tf) and
outputs are defined in [`outputs.tf`](outputs.tf).

## GKE Cluster Modes

GKE Autopilot is the preferred solution for new Braintrust deployments. GKE Standard is supported when customer requirements prevent Autopilot use.
Autopilot remains the module default.

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
    total_min_node_count = 5
    total_max_node_count = 10
  }
}
```

Set the Helm value `google.mode` to `standard`.

Use `braintrust/node-pool` in the Helm node selectors. Set its value to `services` or `brainstore`.

Standard node pools use generated GKE names. Every machine type change replaces the pool. Disk type and disk size changes use GKE surge upgrades.

Bundled Local SSD count changes also require replacement. The module uses one replacement procedure for all machine type changes.

The default surge configuration uses `max_surge = 1` and `max_unavailable = 0`. GKE waits for a new node to reach Ready state before it removes an old node.

If GCP cannot create a surge node, the update waits or fails without an intentional capacity reduction.
Each node has a stable `braintrust/node-pool` label for Helm node selectors.

The Terraform map key sets the workload label. The `services` and `brainstore` keys match the Helm example selectors.
Automatic replacement preserves that label and needs no Helm selector change.

The per-pool `respect_pdb_on_delete` option defaults to `true`. GKE respects Helm-defined PDBs during pool deletion for up to one hour.

Set `respect_pdb_on_delete = false` only to opt out of deletion protection. This option omits `node_drain_config` for new pools.

The module leaves custom drain timeouts unset because those values require project enablement from Google.
The basic PDB option still requires verification against the target GKE project.

The Helm GKE Standard example enables independent PDBs for the API and each Brainstore role with `maxUnavailable: 1`.
One writer can stop briefly during eviction. With multiple writers, the budget permits one unavailable replica.
A writer budget of `minAvailable: 1` blocks voluntary eviction when only one writer exists.

For a resource replacement, Terraform creates the new pool before it deletes the old pool.
Initial nodes per zone equal the total minimum divided by the effective zone count, rounded up.
For example, a minimum of five nodes across three zones creates six initial nodes.
Initial capacity can temporarily exceed the total maximum because of this rounding.
Later autoscaler minimum changes do not replace the pool.
A zero minimum provides no initial capacity guarantee.
The minimum does not represent current load, and smaller nodes must still fit each pod's resource requests.
Terraform waits for GKE pool creation, but it does not verify application readiness or cache recovery.

### Later machine type changes

Machine type changes replace the node pool. Replacement nodes must fit each pod's resource requests.

GKE respects PDBs for up to one hour. After that period, deletion can interrupt workloads.

A Terraform timeout does not cancel the GKE deletion.

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

Verify regional availability for the machine types in use, and set `node_locations` when a machine type is missing from a cluster zone.

### Brainstore Local SSD

The `brainstore` pool must use a machine type with bundled Local SSD. These machine types carry `lssd` in the machine type name, such as `c4a-standard-48-lssd` (Arm), `c4-standard-48-lssd`, `c4d-standard-48-lssd`, or `c3d-standard-30-lssd`. The module validates this in Standard mode.

The number of Local SSD disks is a fixed property of the machine type. GKE selects that fixed count when it creates the node pool.

Customers configure only the machine type. The module has no Local SSD count input.

A single Brainstore writer can have a brief interruption during a node pool replacement.

The replacement deletes the node ephemeral storage. Brainstore treats that storage as a cache and rebuilds its contents.

If replacement capacity allocation fails, Terraform keeps the old pool.

## How to use this module

Choose the example for a new deployment:

| GKE mode | Example |
| --- | --- |
| Autopilot (preferred) | [braintrust-data-plane](examples/braintrust-data-plane) |
| Standard (when Autopilot cannot meet customer requirements) | [braintrust-data-plane-gke-standard](examples/braintrust-data-plane-gke-standard) |

Copy the selected directory into your repository.
Follow its README for setup and deployment.

Both examples use production-sized defaults.
An existing deployment must keep its initial cluster mode.

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

## Isolated workers

The optional `gke_isolated_workers` configuration creates a dedicated Standard cluster in the same project and VPC.
It supports either primary cluster mode and uses a separate subnet and the shared deployment KMS key.
Its services and worker pools use separate node identities.
The default worker pool uses Intel C4 nodes with nested virtualization and raw local SSD.

[Isolated worker configuration and acceptance procedure](ISOLATED_WORKERS.md)
