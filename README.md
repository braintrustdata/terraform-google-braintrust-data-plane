# Braintrust Terraform Google Module

This module is used to create the VPC, Databases, Redis, Storage, IAM, and associated resources for the self-hosted Braintrust data plane on Google using Google Kubernetes Engine.

## Architecture Diagram

![Architecture Diagram](assets/gke-arch-diagram-export-12-23-2025.png)

## Module Configuration

Module input variables are defined in [`variables.tf`](variables.tf) and
outputs are defined in [`outputs.tf`](outputs.tf).

## How to use this module

To use this module, **copy the [`examples/braintrust-data-plane`](examples/braintrust-data-plane) directory to a new Terraform directory in your own repository**. Follow the instructions in the [`README.md`](examples/braintrust-data-plane/README.md) file in that directory to configure the module for your environment.

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
