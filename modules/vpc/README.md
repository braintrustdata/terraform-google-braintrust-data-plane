<!-- BEGIN_TF_DOCS -->

## Reference

### Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_google"></a> [google](#requirement\_google) | ~> 6.45 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | ~> 6.45 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.7.2 |

### Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | ~> 6.45 |

### Modules

No modules.

### Resources

| Name | Type |
|------|------|
| [google_compute_global_address.private_ip_address](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_address) | resource |
| [google_compute_network.vpc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_compute_router.router](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router) | resource |
| [google_compute_router_nat.nat](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat) | resource |
| [google_compute_subnetwork.subnets](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_service_networking_connection.private_vpc_connection](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_networking_connection) | resource |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_deployment_name"></a> [deployment\_name](#input\_deployment\_name) | Name of the deployment. Used to prefix resource names. | `string` | n/a | yes |
| <a name="input_subnet_cidr_range"></a> [subnet\_cidr\_range](#input\_subnet\_cidr\_range) | The IP address range of the subnet in CIDR notation | `string` | n/a | yes |
| <a name="input_vpc_name"></a> [vpc\_name](#input\_vpc\_name) | Name of the VPC | `string` | n/a | yes |

### Outputs

| Name | Description |
|------|-------------|
| <a name="output_network_name"></a> [network\_name](#output\_network\_name) | Name of the VPC Network |
| <a name="output_network_self_link"></a> [network\_self\_link](#output\_network\_self\_link) | Self link of the VPC Network |
| <a name="output_private_vpc_connection"></a> [private\_vpc\_connection](#output\_private\_vpc\_connection) | Private VPC connection for Google Cloud Services |
| <a name="output_subnet_name"></a> [subnet\_name](#output\_subnet\_name) | Name of the subnet |
| <a name="output_subnet_self_link"></a> [subnet\_self\_link](#output\_subnet\_self\_link) | Self link of the subnet |

<!-- END_TF_DOCS -->