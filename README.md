# Braintrust Terraform Google Module

This module is currently beta status. There may be breaking changes that require a complete deletion and re-deployment

This module is used to create the VPC, Databases, Redis, Storage, IAM, and associated resources for the self-hosted Braintrust data plane on Google using Google Kubernetes Engine.

## Module Configuration

Module input variables are defined in [`variables.tf`](variables.tf) and
outputs are defined in [`outputs.tf`](outputs.tf).

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

- Logging is configured to use the default project log sink, need to determine if a custom log sink will be needed.
- This module will fail the first time it is deployed due to timing issue with the private connection for the VPC. Exploring ways to fix this still without adding a module depends on which causes issues.
- Explore customer support module like AWS module
- Explore optional cloud-run module as front end for braintrust api frontend
- Explore using Terraform to enable google services instead of CLI/GUI
- Test support for GKE auto pilot nodes
