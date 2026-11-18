# Upstream source

The quota baseline comes from `braintrustdata/terraform-google-braintrust-data-plane`.
`source.json` records the exact upstream commit, source paths, and file digests.
`services.json` contains the reviewed API catalog for this module.
Terraform consumes the quota baseline directly. The module includes no quota shell helper.
The accompanying `LICENSE` contains the upstream Apache License 2.0 terms.

## Storage location catalog

`storage-locations.json` records the location and placement rules from the [Cloud Storage location catalog](https://docs.cloud.google.com/storage/docs/locations).
The review date is November 13, 2026.
The [Cloud KMS location catalog](https://docs.cloud.google.com/kms/docs/locations) supplies the `eu` to `europe` mapping.
This catalog is separate from the quota baseline in `source.json`.
