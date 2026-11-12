# Outpost bootstrap example

This root calls only `modules/byoc-bootstrap`.
It creates no workload infrastructure.
The candidate remains non-issuable.

The [module guide](../../modules/byoc-bootstrap/README.md) defines the inputs, backend choices, quota behavior, and example procedure.
The customer owns the bootstrap backend and supplies an existing bucket for remote state.
Without backend configuration, this root uses local state.
