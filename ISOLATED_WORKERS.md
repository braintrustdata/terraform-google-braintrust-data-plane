# Isolated worker infrastructure

The optional `gke_isolated_workers` configuration creates a separate GKE Standard cluster in the primary project and VPC.
The primary cluster retains its original Autopilot or Standard mode.
The default configuration creates no isolated worker resources.

The cluster name uses `<deployment_name>-gke-isolated-workers`.
For names above the 40-character cluster limit, the deployment prefix uses truncation and a six-character hash.
A cluster name change requires cluster replacement and worker Helm release redeployment.

The root module calls the VPC, isolation network, KMS, cluster, and node pool modules directly.
The isolation network module owns the worker subnet, firewall rules, private DNS, and external-dns IAM.
The cluster module owns both node identities and their required project roles.
Child modules contain no module calls.

The isolated cluster contains a `services` pool and an `isolated-workers` pool.
The services pool hosts the worker controller, external-dns, and eligible GKE system Pods.
It defaults to two `e2-standard-2` nodes across two available zones, with standard boot disks.
It has no nested virtualization or raw local SSD.
The default machine is `c4-standard-16-lssd`, with Ubuntu, nested virtualization, and raw local SSD.
Intel C3 and C4 machine types with bundled local SSD are supported configuration choices.
The target region, quota, and GKE version must support the selected machine.

Terraform creates infrastructure only.
The worker Helm release owns privileged Pods, `/dev/kvm` access, disk preparation, and application settings.
A worker Pod must occupy at most one slot per node and reserve resources for GKE system Pods.
The worker application must enforce guest isolation and authenticate its control API.

## IAM contract

Each pool receives a separate node service account.
Both pools and the isolated cluster use the shared deployment KMS key.
Worker nodes receive the standard GKE node roles.
They receive no project-wide storage or registry read grant from this module.
Services nodes receive only standard GKE node roles.
The node identities receive no controller, DNS administration, or service-account impersonation grant.
Optional discovery creates a separate external-dns Google service account.
Controller permissions require dedicated Kubernetes RBAC and workload identities in the application integration.
No worker workload identity, service-account key, HMAC key, or guest Google credential is created.

GKE and Compute Engine service agents remain shared at project scope.
The KMS module owns their grants on the deployment key.
Each grant has one Terraform owner.
Project and organization IAM grants remain applicable, including grants that this module does not manage.

Primary application grants use Kubernetes namespace and service account names.
Both the API and Brainstore retain access to the Brainstore Google identity.
GKE clusters in one project share an identity pool, so matching names in another cluster receive the same grants.
Cluster separation and distinct node identities do not restrict these grants to the primary cluster.
The worker Helm release must restrict Kubernetes permissions and credential access.

[Google Workload Identity identifiers](https://docs.cloud.google.com/kubernetes-engine/docs/concepts/workload-identity#kubernetes-resources-iam-policies)

## Address allocation

`network_cidr` reserves one IPv4 /16 block for isolation.
Terraform derives a /18 Pod range, a /24 node range, a /22 Service range, and a /28 control-plane range.
The ranges are known before cluster creation, so the firewall rules require no later discovery step.
For `10.64.0.0/16`, the effective ranges are:

| Purpose | Range |
| --- | --- |
| Pods | `10.64.0.0/18` |
| Nodes | `10.64.64.0/24` |
| Services | `10.64.68.0/22` |
| Control plane | `10.64.72.0/28` |

Explicit `node_cidr`, `pod_cidr`, `service_cidr`, and `control_plane_cidr` values override these allocations.
An existing isolation subnet supplies its node range automatically.
That subnet can sit outside the allocation block, but its range must not overlap the derived ranges.
Existing deployments can retain their explicit ranges to avoid network replacement.

Discovery derives `runtime_source_ranges` from the primary node subnet and effective primary Pod range by default.
An explicit set replaces those defaults for custom routing or external runtimes.
If `deploy_gke_cluster` is false, discovery requires explicit runtime source ranges.
Terraform uses GCP APIs and cluster outputs. It requires no Kubernetes provider.

## Configuration example

This example uses illustrative network ranges.
The block must not overlap existing subnets, Pod ranges, service ranges, peered networks, or private service access ranges.
Terraform verifies worker ranges against each other and known primary configuration ranges.
GCP also verifies address allocation during deployment.

```hcl
gke_isolated_workers = {
  network_cidr = "10.64.0.0/16"

  machine_type         = "c4-standard-16-lssd"
  total_min_node_count = 2
  total_max_node_count = 10
  # node_locations = ["us-central1-a", "us-central1-b"]


}
```

The node minimum is a total across zones.
Initial capacity rounds up per zone, so two requested nodes across three zones create three initial nodes.
A positive minimum preserves capacity for system Pods.
Both pools use non-Spot nodes, automatic repair, and automatic upgrades.
Worker nodes have the `braintrust/isolated-worker=true:NoSchedule` taint.
Services nodes have no workload taint.

The control plane requires a dedicated `/28` range.
The default service range is explicit because this module requires predictable firewall destinations.
With `create_vpc = false`, customers must supply `gke_isolated_workers.existing_subnet_self_link`.
The supplied subnet must use the specified node range and Private Google Access.
With a module-created VPC, Terraform creates the isolated worker subnet.
GKE allocates the configured secondary ranges on that subnet.
With `create_vpc = false`, Terraform skips the entire VPC module.
The customer retains ownership of the VPC and both supplied subnets.
The isolation network module reads the worker subnet and verifies its VPC, region, node range, and Private Google Access.
The module creates isolation firewall rules and optional DNS for either VPC path.
Customers with existing private DNS can disable zone creation and retain their records.
Existing secondary ranges need separate allocation planning.

## Pool placement contract

System components use `braintrust/node-pool: services`.
Worker Pods use `braintrust/node-pool: isolated-workers` and the following toleration:

```yaml
nodeSelector:
  braintrust/node-pool: isolated-workers
tolerations:
  - key: braintrust/isolated-worker
    operator: Equal
    value: "true"
    effect: NoSchedule
```

The worker Helm release must require hostname anti-affinity for one worker Pod per node.
The controller and external-dns must select the services pool without the worker toleration.
The separate pools keep controller credentials off worker hosts during normal placement.
Both pools share the isolated cluster control plane and network rules.

The optional `services_pool` object controls services capacity and image repository access:

```hcl
# Inside gke_isolated_workers.
services_pool = {
  machine_type         = "e2-standard-2"
  disk_type            = "pd-balanced"
  total_min_node_count = 2
  total_max_node_count = 4
  node_locations       = ["us-central1-a", "us-central1-b"]
}
```

Public AWS ECR images require no Artifact Registry grants.
The services output fields expose its selector, pool name, and node identity.
The `worker_tolerations` output provides the worker toleration.
The in-flight worker chart requires these selectors and toleration before deployment on GKE.

## Network contract

Worker nodes are private. The Kubernetes API uses a public IP endpoint for external Helm and `kubectl` access.
The DNS endpoint does not permit client access.
Authentication and authorization still apply. The module creates no administrator IAM grants.
The Google Terraform provider uses Google APIs for infrastructure operations.
The optional `authorized_cidrs` list restricts control-plane access to specified sources plus the isolated node and Pod ranges.
The default is null, which applies no authorized-network restriction, consistent with the primary cluster defaults.
The `master_global_access` input controls cross-region access to the private endpoint.

Worker firewall rules deny ingress and egress by default at priority 1000.
Priority 950 permits outbound TCP 443 to all IPv4 destinations through the assumed NAT path.
Priority 925 denies private and reserved ranges, known primary ranges, and configured runtime source ranges.
Priority 900 permits required intra-cluster and control-plane traffic before that deny.
Explicit TCP exceptions use priority 800.
Worker nodes use a stable network tag independent of the cluster name.
The name combines the normalized deployment prefix, its hash, and `isolated-workers`, as defined in `main.tf`.
The Terraform plan exposes the tag before deployment.
Higher-priority customer policies still affect the effective policy.
The operator must verify the effective policy before guest workloads start.

The `ingress_rules` and `egress_rules` maps contain named, explicit TCP exceptions.
They contain no worker application ports by default.
Optional discovery adds runtime ingress on TCP 9400.
Proxy access and destination-side policies remain part of application integration.
Rules cannot use `0.0.0.0/0` or empty port sets.
Broad ranges still require review.

```hcl
# Inside gke_isolated_workers. Use the actual application port and source range.
ingress_rules = {
  runtime = {
    source_ranges = ["10.20.0.0/20"]
    ports         = ["8080"]
  }
}
```

The module preserves existing Google API DNS resolution across the VPC.
Private worker discovery requires the Cloud DNS API.
Public AWS ECR supplies Braintrust images.
Outbound HTTPS permits ECR authentication and image downloads without an endpoint IP allowlist.
The same rule permits other public HTTPS destinations, including Google APIs and public registries.
No Artifact Registry mirror is required.

For module-created VPCs, the VPC module provides NAT for all subnets.
The module creates no NAT gateway or internet route in customer-supplied VPCs.
NAT is a deployment prerequisite. The isolation network module creates no NAT resources.
The default deny still blocks public HTTP and direct public DNS on port 53.
Custom networks still require a valid route for Private Google Access.

Host firewall rules do not provide guest isolation by themselves.
Intra-cluster traffic remains available for Kubernetes.
The worker must separately block guest access to metadata, unrestricted DNS, host credentials, and other guests.
The HTTPS allowance applies to both node pools and does not distinguish host traffic from forwarded guest traffic.
The worker application owns guest internet policy and guest DNS restrictions.
VPC firewall rules cannot enforce isolation from the host or its metadata service.
Publicly addressed private destinations outside the supplied primary and runtime ranges require separate network policy.
The private Google API VIP remains available through HTTPS.
IAM limits access through module-created identities, but it does not prevent use of external credentials inside a compromised host.

[Private Google Access](https://docs.cloud.google.com/vpc/docs/configure-private-google-access)

## Worker connectivity and discovery

The optional `discovery` object enables private worker DNS and runtime ingress:

```hcl
# Inside gke_isolated_workers.
discovery = {
  dns_name = "jeff-testing.isolated.internal"
  # Optional override for custom routing:
  # runtime_source_ranges = ["10.212.0.0/14", "10.0.0.0/24"]
}
```

The isolation network module creates the private zone in the shared VPC.
Both clusters can resolve this zone through VPC DNS.
The runtime ingress rule permits TCP 9400 from the derived or explicit source ranges to the worker-only network tag.
The services nodes do not receive that tag.
No reverse worker access to primary services is added.
Automatic runtime ranges include primary Pod addresses and the node subnet for SNAT.
Custom runtime overrides must include every permitted source range.
Customer egress policies and Kubernetes NetworkPolicies must also permit this connection.

The worker hostname is `workers.<dns_name>` and its endpoint uses HTTPS on port 9400.
Terraform creates no worker A or TXT records.
External-dns creates those records from the worker headless Service after the Helm release starts.
The hostname does not resolve to workers before that publication.

External-dns receives a dedicated Google service account through Workload Identity.
Its custom project role permits only `dns.managedZones.list` for zone discovery.
A separate custom role grants record reads and writes only on the worker discovery zone.
Neither role permits changes to the Google API zones or unrelated zone records.
The identity cannot create zones or modify zone IAM policies.
The deployer requires permissions to create custom IAM roles and set the discovery zone policy.

The default Kubernetes namespace uses the stable isolation resource name.
The default Kubernetes service account is `external-dns`.
The `external_dns_namespace` and `external_dns_service_account` fields permit overrides.
Name-based Workload Identity grants also apply to matching names in other clusters in the same project.
This namespace and service-account pair must remain exclusive to this deployment.

The `gke_isolated_workers.discovery` output supplies the hostname, endpoint, zone, service-account annotation, and external-dns arguments.
The application integration requires these steps:

1. Deploy the worker release in the namespace from `external_dns_namespace`.
2. Use the external-dns service account and annotation from the output.
3. Select the services pool for external-dns.
4. Use `external_dns_args` with the Google provider.
5. Annotate the worker headless Service with the discovery hostname.
6. Supply server certificates to workers and client certificates to Loop and the worker controller.
7. Configure Loop and the worker controller with the HTTPS endpoint.

Worker server certificates must cover the discovery hostname.
The worker configuration must require mutual TLS.
Terraform does not create private keys, TLS secrets, or certificate authorities.
The network rule identifies source ranges, so application authentication remains required.
The worker controller and external-dns need their own Kubernetes RBAC in the Helm release.
The external-dns image can use the same public HTTPS path.

[Cloud DNS zone IAM](https://docs.cloud.google.com/dns/docs/zones/iam-per-resource-zones) and [external-dns Google provider](https://github.com/kubernetes-sigs/external-dns/blob/v0.21.0/provider/google/google.go) describe the permission boundaries.

## Local storage and lifecycle

The provider sends an empty raw local SSD configuration when the configured count is zero.
GKE selects the bundled disk count from the machine shape.
Terraform ignores only the returned raw disk count because it is a property of that shape.
Machine changes and node capability changes replace the pool.
The existing primary Brainstore ephemeral storage configuration remains independent.

The worker release must prepare XFS on the raw devices before it advertises capacity.
Disk preparation must preserve existing worker data across Pod restarts.
Node replacement deletes local caches and VM state.
Durable object-storage backups are outside this implementation.

Cluster deletion protection defaults to true.
Normal worker shutdown precedes infrastructure removal.
A worker release must stop new allocations and handle active sandboxes before node retirement.
Terraform pool creation and PodDisruptionBudgets do not prove that guest state is safe.

[Raw local SSD](https://docs.cloud.google.com/kubernetes-engine/docs/how-to/persistent-volumes/local-ssd-raw)
