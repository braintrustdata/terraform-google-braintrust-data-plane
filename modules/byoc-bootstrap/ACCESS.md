# Customer access control

The customer can disable Deployment or Observer directly through Google IAM.
Terraform ignores later changes to account `disabled` values, so reapply leaves disabled accounts disabled.
Reapply can restore removed IAM grants. Grant removal alone does not preserve revocation.
Existing tokens and sessions follow Google expiration and propagation limits.

## Revoke access

1. Identify the affected accounts from the `bootstrap` output.
2. Disable those accounts through customer-controlled Google IAM access.
3. To stop both access paths, disable Deployment and Observer.
4. Notify Braintrust through the established support channel.
5. Keep the accounts disabled until the customer authorizes restoration.

Do not use Terraform destroy for routine revocation. Retained storage and keys require a separate handoff.

## Restore access

1. Obtain project-owner approval for the affected accounts.
2. Review the customer Terraform plan.
3. If grants require restoration, apply the reviewed configuration.
4. Enable the approved accounts through customer-controlled Google IAM access.
5. Provide the bootstrap output and approval reference to Braintrust.
6. Request registration and readiness validation before future operations.

Diagnostics has no access or activation mechanism in this module.
Permanent Braintrust bridge revocation requires a new bootstrap for future access.
Customer Terraform cannot restore a bridge that Braintrust revoked in its own project.
Live revocation and token propagation tests remain incomplete.
