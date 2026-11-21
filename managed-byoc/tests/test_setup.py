import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


BOOTSTRAP = Path(__file__).resolve().parents[1]
GCLOUD = '''#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys

args = sys.argv[1:]
with Path(os.environ["GCLOUD_CALLS"]).open("a") as log:
    log.write(json.dumps(args) + "\\n")
if args[:3] == ["iam", "roles", "describe"]:
    state = os.environ.get("ROLE_STATE", "missing")
    if state == "missing":
        sys.exit(1)
    print("True" if state == "deleted" else "False")
if args[:3] == ["iam", "roles", "create"] and os.environ.get("FAIL_ROLE_CREATE"):
    sys.exit(1)
'''


class SetupTest(unittest.TestCase):
    def invoke(self, *flags, role_state="missing", fail_create=False):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            stub = root / "gcloud"
            stub.write_text(GCLOUD)
            stub.chmod(0o755)
            calls = root / "calls.jsonl"
            env = os.environ.copy()
            env.update(PATH=str(root) + os.pathsep + env["PATH"],
                       GCLOUD_CALLS=str(calls), ROLE_STATE=role_state)
            if fail_create:
                env["FAIL_ROLE_CREATE"] = "1"
            result = subprocess.run(
                ["bash", str(BOOTSTRAP / "setup.sh"), "--project", "braintrust-test", *flags],
                env=env, capture_output=True, text=True,
            )
            commands = [json.loads(line) for line in calls.read_text().splitlines()]
            return result, commands

    def test_permissions_only_provisions_roles_and_only_grants_firewalls(self):
        result, commands = self.invoke("--loop-permissions-only", "--deploy-sa-name", "custom-deploy")
        self.assertEqual(result.returncode, 0, result.stderr)
        creates = [c for c in commands if c[:3] == ["iam", "roles", "create"]]
        self.assertEqual(len(creates), 3)
        definitions = {
            c[3]: json.loads(Path(next(arg.split("=", 1)[1] for arg in c if arg.startswith("--file="))).read_text())
            for c in creates
        }
        self.assertEqual(set(definitions["braintrustIsolatedWorkerFirewall"]["includedPermissions"]), {
            "compute.firewalls.create", "compute.firewalls.get", "compute.firewalls.update",
            "compute.firewalls.delete", "compute.globalOperations.get", "compute.networks.updatePolicy",
        })
        self.assertEqual(definitions["braintrustIsolatedDnsList"]["includedPermissions"], ["dns.managedZones.list"])
        self.assertEqual(set(definitions["braintrustIsolatedDnsRecords"]["includedPermissions"]), {
            "dns.changes.create", "dns.resourceRecordSets.create", "dns.resourceRecordSets.delete",
            "dns.resourceRecordSets.list", "dns.resourceRecordSets.update",
        })
        grants = [c for c in commands if c[:2] == ["projects", "add-iam-policy-binding"]]
        self.assertEqual(len(grants), 1)
        self.assertIn("--role=projects/braintrust-test/roles/braintrustIsolatedWorkerFirewall", grants[0])
        self.assertIn("--member=serviceAccount:custom-deploy@braintrust-test.iam.gserviceaccount.com", grants[0])
        self.assertFalse(any(c[0] in {"services", "secrets", "storage"} for c in commands))
        self.assertFalse(any(c[:2] == ["iam", "service-accounts"] for c in commands))
        self.assertIn("discovers the DNS roles automatically", result.stdout)
        self.assertNotIn("isolated_worker_dns_roles =", result.stdout)

    def test_rerun_updates_existing_roles(self):
        result, commands = self.invoke("--loop-permissions-only", role_state="active")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(sum(c[:3] == ["iam", "roles", "update"] for c in commands), 3)
        self.assertFalse(any(c[:3] == ["iam", "roles", "create"] for c in commands))

    def test_rerun_restores_soft_deleted_roles(self):
        result, commands = self.invoke("--loop-permissions-only", role_state="deleted")
        self.assertEqual(result.returncode, 0, result.stderr)
        for role in ("braintrustIsolatedDnsList", "braintrustIsolatedDnsRecords", "braintrustIsolatedWorkerFirewall"):
            undelete = next(i for i, c in enumerate(commands) if c[:4] == ["iam", "roles", "undelete", role])
            update = next(i for i, c in enumerate(commands) if c[:4] == ["iam", "roles", "update", role])
            self.assertLess(undelete, update)

    def test_dry_run_executes_no_mutations(self):
        result, commands = self.invoke("--loop-permissions-only", "--dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("DRY-RUN:", result.stderr)
        self.assertTrue(all(c[:2] in (["auth", "print-access-token"], ["projects", "describe"])
                            or c[:3] == ["iam", "roles", "describe"] for c in commands))

    def test_role_failure_stops_before_grant(self):
        result, commands = self.invoke("--loop-permissions-only", fail_create=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any(c[:2] == ["projects", "add-iam-policy-binding"] for c in commands))

    def test_full_setup_uses_narrow_worker_grants(self):
        result, commands = self.invoke(role_state="active")
        self.assertEqual(result.returncode, 0, result.stderr)
        grants = [c for c in commands if c[:2] == ["projects", "add-iam-policy-binding"]]
        roles = {arg for c in grants for arg in c if arg.startswith("--role=")}
        self.assertIn("--role=projects/braintrust-test/roles/braintrustIsolatedWorkerFirewall", roles)
        self.assertNotIn("--role=roles/compute.securityAdmin", roles)
        self.assertNotIn("--role=roles/iam.roleAdmin", roles)
        self.assertTrue(any(c[:2] == ["services", "enable"] for c in commands))


if __name__ == "__main__":
    unittest.main()
