import hashlib
import json
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class BaselineTests(unittest.TestCase):
    def test_v1_quota_and_service_baselines_are_unchanged(self):
        directory = ROOT / "data"
        source = json.loads((directory / "source.json").read_text())
        self.assertRegex(source["commit"], "^[0-9a-f]{40}$")
        for name, entry in source["files"].items():
            self.assertEqual(hashlib.sha256((directory / name).read_bytes()).hexdigest(), entry["sha256"], name)
        self.assertIn("cloudquotas.googleapis.com", json.loads((directory / "services.json").read_text()))

    def test_no_temporary_grants_or_shell_execution(self):
        text = "\n".join(p.read_text() for p in ROOT.glob("*.tf"))
        for forbidden in ["local-exec", "remote-exec", "google_project_iam_policy", "google_project_iam_binding", "google_service_account_key", "google_project_iam_audit_config", "google_privileged_access_manager"]:
            self.assertNotIn(forbidden, text)
        self.assertNotIn('bootstrap["diagnostics"]', (ROOT / "main.tf").read_text())
        self.assertFalse((ROOT / "scripts/quotas/request-quotas.sh").exists())


if __name__ == "__main__":
    unittest.main()
