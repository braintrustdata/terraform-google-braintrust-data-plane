# Isolated worker infrastructure

`gke_isolated_workers` creates a separate GKE Standard cluster in the primary
project and VPC, leaving the primary cluster's Autopilot or Standard mode unchanged.
It defaults to null, which creates no worker infrastructure.

Terraform owns networking, IAM, KMS, and node pools. The worker Helm release owns
privileged Pods, `/dev/kvm`, disk preparation, control API authentication, and guest
isolation. For installation and mTLS setup, use `braintrust/examples/gke-loop-runtime`
in the [Helm repository](https://github.com/braintrustdata/helm).

## Configuration

```hcl
gke_isolated_workers = {
  network_cidr     = "10.64.0.0/16" # Must not overlap existing or peered ranges.
  authorized_cidrs = ["192.0.2.10/32"] # Replace with operator and CI egress ranges.
  discovery    = { dns_name = "sandbox.example.internal" }
}
```

The defaults create two pools:

| Pool | Default capacity | Node configuration |
| --- | --- | --- |
| `services` | 2 nodes across 2 available zones | `e2-standard-2`, COS, standard boot disks |
| `isolated-workers` | 1 node, autoscaling to 10 | `c4-standard-8-lssd`, Ubuntu, nested virtualization, raw local SSD |

Intel C3 and C4 machines with bundled local SSD are supported; availability depends
on the region, quota, and GKE version. Both pools use non-Spot nodes, automatic
repair, and automatic upgrades. The services pool needs no nested virtualization
or local SSD. `services_pool` overrides its machine, disk, capacity, and zones;
worker capacity and `node_locations` are configured directly in `gke_isolated_workers`.
Minimums are totals across zones and must be positive for system Pods. Initial
capacity rounds up per zone: two nodes across three zones initially creates three.

The published Sandbox Service chart uses these placement settings:

| Workload | Node selector | Toleration |
| --- | --- | --- |
| Controller, external-dns | `braintrust.io/workload: sandbox-system` | None |
| Workers | `braintrust.io/workload: sandbox-service` | `braintrust.io/sandbox=true:NoSchedule` |

Require hostname anti-affinity for at most one worker Pod per node and reserve
resources for GKE system Pods. Keep controller credentials on services nodes;
both pools still share the isolated control plane and network rules.
The outputs expose pool names, node identities, selectors, and `worker_tolerations`.

## Address allocation

`network_cidr` reserves one IPv4 /16 block. For `10.64.0.0/16`, Terraform derives:

| Purpose | Range |
| --- | --- |
| Pods | `10.64.0.0/18` |
| Nodes | `10.64.64.0/24` |
| Services | `10.64.68.0/22` |
| Control plane | `10.64.72.0/28` |

`node_cidr`, `pod_cidr`, `service_cidr`, and `control_plane_cidr` override these
allocations. Retain explicit ranges on existing deployments to avoid replacement.
The control plane requires a /28; predictable Pod and Service ranges let Terraform
configure firewalls before cluster creation. Terraform rejects overlap among worker
ranges and known primary ranges; also check peered networks and private service access.
GCP performs its own allocation checks.

With `create_vpc = false`, supply a separate `existing_subnet_self_link` inside
`gke_isolated_workers`. Its node range is read automatically and may sit outside
`network_cidr` if it does not overlap the other ranges. The module validates its
VPC, region, node range, and Private Google Access. The customer owns both supplied
subnets and must plan secondary ranges. With a module-created VPC, Terraform creates
the worker subnet and GKE allocates its configured secondary ranges. Isolation
firewalls and optional DNS apply to either path; omit `discovery` to retain existing DNS.

## IAM

Loop IAM is created only when isolated workers are enabled; its output is otherwise null.
The runtime retains object-write and bucket-read access to both deployment buckets.
Each pool has a separate node service account with standard GKE node roles and no
module-created storage, registry, controller, DNS administration, or service-account
impersonation grants. Controller permissions require workload identities and
Kubernetes RBAC in the Helm release. Terraform creates no worker workload identity,
service-account key, HMAC key, or guest Google credential. Public ECR images require
no Artifact Registry grants.

Both pools and the isolated cluster use the shared deployment KMS key. The KMS
module owns one grant per project-wide GKE and Compute Engine service agent.
Project and organization grants outside this module still apply.

API and Brainstore retain their name-based Workload Identity grants, including API
access to the Brainstore identity. Clusters in a project share an identity pool:
matching namespace and service account names in another cluster receive the same
grants. Separate clusters and node identities do not constrain those grants.
Restrict Kubernetes permissions and credential access in the worker release.
See [Google Workload Identity identifiers](https://docs.cloud.google.com/kubernetes-engine/docs/concepts/workload-identity#kubernetes-resources-iam-policies).

## Networking and guest isolation

Nodes are private; the Kubernetes API has a public IP endpoint for Helm and
`kubectl`, with client access through the DNS endpoint disabled. Authentication
and authorization still apply; Terraform grants no administrator IAM permissions.
`authorized_cidrs` is required and restricts access to explicit operator/CI egress
ranges plus isolated node and Pod ranges. Null, empty, malformed, noncanonical,
and default-route ranges are rejected.
`master_global_access` controls cross-region access to the private endpoint.
Infrastructure operations use Google APIs and require no Kubernetes provider.

| Priority | Rule |
| --- | --- |
| 800 | Explicit TCP exceptions, runtime discovery, and the Loop Git proxy |
| 900 | Required intra-cluster and control-plane traffic |
| 925 | Deny private/reserved destinations, known primary ranges, and runtime ranges |
| 950 | Outbound TCP 443 to public IPv4 destinations |
| 1000 | Deny remaining ingress and egress |

Rules target stable deployment-specific network tags. Higher-priority customer
policies still apply; verify the effective policy before starting guest workloads.
`ingress_rules` and `egress_rules` accept named TCP exceptions with explicit
source/destination ranges and ports. They have no application exceptions by
default and reject `0.0.0.0/0` or empty port sets; review broad ranges separately.

Public HTTPS supports ECR authentication and image downloads, other registries,
and Google APIs without an IP allowlist or Artifact Registry mirror. It is not
restricted to those services. Public HTTP and direct public DNS on port 53 remain
blocked. Existing Google API DNS resolution is preserved, and the private Google
API VIP remains reachable over HTTPS. Module-created VPCs provide NAT for all
subnets; customer-supplied VPCs must already have NAT and suitable routes, including
[Private Google Access](https://docs.cloud.google.com/vpc/docs/configure-private-google-access).

VPC firewalls alone do not isolate guests: Kubernetes intra-cluster traffic stays
available, and the HTTPS rule cannot distinguish host traffic from forwarded
guest traffic. The worker must block guest access to metadata, unrestricted DNS,
host credentials, and other guests, and enforce guest internet policy. Publicly
addressed private destinations outside supplied primary/runtime ranges need
separate policy. IAM restricts module-created identities but cannot prevent an
attacker from using external credentials on a compromised host.

## Discovery and runtime connectivity

`discovery` creates a private Cloud DNS zone resolvable by both clusters. It derives
`runtime_source_ranges` from the primary node subnet and effective Pod range,
covering SNAT and direct Pod traffic. An explicit set replaces these defaults and
must include every permitted source. With `deploy_gke_cluster = false`, supply
explicit runtime ranges. Customer egress policies and NetworkPolicies must also
allow the connection.

Only worker nodes receive runtime ingress on TCP 9400. The endpoint is
`https://workers.<dns_name>:9400`; external-dns creates its A/TXT records from the
worker headless Service after Helm starts. Terraform creates no worker records.
Discovery also reserves an internal IP in the primary subnet, publishes
`loop-egress.<dns_name>`, and permits worker egress to that IP on TCP 4002 for Loop's
Git proxy. The Loop Helm release binds its internal load balancer to
`gke_isolated_workers.loop_egress.address` and restricts ingress to its `source_ranges`.

External-dns uses the Kubernetes principal directly through Workload Identity
Federation, without a Google service account or service account annotation. Its
project role permits only `dns.managedZones.list`; a separate role permits record
reads/writes only on the discovery zone. It cannot create zones, change zone IAM,
or modify Google API or unrelated zones. Deployment requires the Cloud DNS API,
custom-role creation permissions, and permission to set the zone policy.

The defaults are namespace `braintrust-sandbox` and service account `external-dns`;
override `external_dns_namespace` and `external_dns_service_account` as needed.
Keep that name pair exclusive to this deployment because matching identities in
other project clusters receive the same grants. The `discovery` output supplies
the hostname, endpoint, zone, and `external_dns_extra_args` for the worker chart's
Google provider. Annotate the headless Service with the hostname and install the
controller/external-dns RBAC through Helm.

Workers must require mTLS with server certificates covering the discovery hostname.
Supply client certificates and the HTTPS endpoint to Loop and the controller.
Terraform creates no keys, TLS Secrets, or CAs; source-range rules do not replace
authentication. See [Cloud DNS zone IAM](https://docs.cloud.google.com/dns/docs/zones/iam-per-resource-zones)
and the [external-dns Google provider](https://github.com/kubernetes-sigs/external-dns/blob/v0.21.0/provider/google/google.go).

## Storage and lifecycle

GKE selects the bundled raw SSD count from the machine shape when the provider
sends an empty raw SSD configuration (count zero). Terraform ignores only the
returned count; machine and capability changes replace the pool. Primary Brainstore
ephemeral storage is independent. See [raw local SSD](https://docs.cloud.google.com/kubernetes-engine/docs/how-to/persistent-volumes/local-ssd-raw).

The worker release must prepare XFS before advertising capacity and preserve data
across Pod restarts. Node replacement destroys local caches and VM state; durable
object-storage backups are outside this module. Stop new allocations and drain
active sandboxes before retiring nodes or removing infrastructure. Pool creation
and PodDisruptionBudgets do not establish that guest state is safe.

Deletion protection defaults to true. The cluster name is
`<deployment_name>-gke-isolated-workers`, with a truncated prefix and six-character
hash when needed for the 40-character limit. Changing it replaces the cluster and
requires redeploying the worker Helm release.
