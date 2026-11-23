import base64
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest
from unittest.mock import Mock, patch

spec = importlib.util.spec_from_file_location("loop_bootstrap", Path(__file__).with_name("bootstrap.py"))
bootstrap = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bootstrap)


class FakeApi:
    def __init__(self):
        self.secrets = {}
        self.requests = []

    def read_secret(self, name, version="latest"):
        values = self.secrets.get(name, [])
        if not values:
            return None
        return values[-1] if version == "latest" else values[int(version) - 1]

    def write_secret(self, name, value):
        self.secrets.setdefault(name, []).append(value)
        return {"name": name + "/versions/" + str(len(self.secrets[name]))}

    def access_token(self):
        return "test-token"

    def request(self, url, method="GET", body=None, missing=False):
        self.requests.append((url, method, body))
        return None if method == "GET" else {}


def config():
    return {
        "project": "test-project", "endpoint": "https://workers.example.gke.goog", "namespace": "braintrust-sandbox",
        "hostname": "workers.sandbox.example.internal", "checkpoint_store": "gs://test-checkpoints/filesystems",
        "secrets": {key: "projects/test-project/secrets/" + key for key in ("seed", "server", "client")},
        "replicas": 1, "services_version": "v2.24.0", "dns_args": ["--google-project=test-project"],
        "overrides": {"env": [{"name": "CUSTOM_SETTING", "value": "custom"}]},
        "license_secret": "license", "telemetry": "status,logs", "helm_url": "https://get.helm.sh/test.tgz",
        "helm_sha256": "", "chart_url": "https://charts.example/worker.tgz",
    }


class BootstrapTests(unittest.TestCase):
    def test_metadata_credentials_include_gke_email_scope_and_are_cached(self):
        opener = Mock()
        opener.open.return_value = io.BytesIO(b'{"access_token":"test-token","expires_in":3600}')
        with patch.object(bootstrap.urllib.request, "build_opener", return_value=opener):
            api = bootstrap.Api()
            self.assertEqual(api.access_token(), "test-token")
            self.assertEqual(api.access_token(), "test-token")
        opener.open.assert_called_once()
        request = opener.open.call_args.args[0]
        scopes = bootstrap.urllib.parse.parse_qs(bootstrap.urllib.parse.urlsplit(request.full_url).query)["scopes"][0]
        self.assertEqual(set(scopes.split(",")), {
            "https://www.googleapis.com/auth/cloud-platform",
            "https://www.googleapis.com/auth/userinfo.email",
        })
        self.assertEqual(request.get_header("Metadata-flavor"), "Google")

    def test_first_install_generates_persists_and_reuses_tls(self):
        api, cfg = FakeApi(), config()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            first = bootstrap.tls_bundles(api, cfg, root)
            second = bootstrap.tls_bundles(api, cfg, root)
            self.assertEqual(first, second)
            self.assertTrue(all(len(versions) == 1 for versions in api.secrets.values()))
            for kind, peer in (("client", "server"), ("server", "client")):
                cert = root / (kind + "-verify.pem")
                ca = root / (kind + "-verify-ca.pem")
                cert.write_text(first[kind]["cert"])
                ca.write_text(first[peer]["ca_cert"])
                subprocess.run(["openssl", "verify", "-CAfile", str(ca), str(cert)], check=True, capture_output=True)
            self.assertNotEqual(first["client"]["ca_cert"], first["server"]["ca_cert"])

    def test_hostname_change_preserves_client_identity_and_ca(self):
        api, cfg = FakeApi(), config()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            first = bootstrap.tls_bundles(api, cfg, root)
            cfg["hostname"] = "workers." + "x" * 50 + ".example.internal"
            second = bootstrap.tls_bundles(api, cfg, root)
            self.assertEqual(first["client"], second["client"])
            self.assertEqual(first["server"]["ca_cert"], second["server"]["ca_cert"])
            cert = root / "server-verify.pem"
            ca = root / "server-verify-ca.pem"
            cert.write_text(second["server"]["cert"])
            ca.write_text(second["client"]["ca_cert"])
            subprocess.run(["openssl", "verify", "-verify_hostname", cfg["hostname"], "-CAfile", str(ca), str(cert)], check=True, capture_output=True)
            self.assertEqual(len(api.secrets[cfg["secrets"]["seed"]]), 1)
            self.assertEqual(len(api.secrets[cfg["secrets"]["server"]]), 2)

    def test_invalid_persisted_bundle_is_not_replaced(self):
        api, cfg = FakeApi(), config()
        with tempfile.TemporaryDirectory() as directory:
            bootstrap.tls_bundles(api, cfg, Path(directory))
            name = cfg["secrets"]["client"]
            api.secrets[name] = [b'{"cert":"incomplete"}']
            with self.assertRaisesRegex(RuntimeError, "refusing to replace"):
                bootstrap.tls_bundles(api, cfg, Path(directory))
            self.assertEqual(api.secrets[name], [b'{"cert":"incomplete"}'])

    def test_install_scopes_secrets_to_workers_and_keeps_keys_out_of_helm(self):
        api, cfg = FakeApi(), config()
        api.secrets["projects/test-project/secrets/license"] = [b"test-license"]
        bundles = {kind: {"cert": kind + "-cert", "key": kind + "-private-key", "ca_cert": kind + "-peer-ca"} for kind in ("server", "client")}
        buffer = io.BytesIO()
        with tarfile.open(fileobj=buffer, mode="w:gz") as tar:
            content = b"test-helm"
            info = tarfile.TarInfo("linux-amd64/helm")
            info.size = len(content)
            tar.addfile(info, io.BytesIO(content))
        archive = buffer.getvalue()
        cfg["helm_sha256"] = hashlib.sha256(archive).hexdigest()
        with tempfile.TemporaryDirectory() as directory, patch.object(bootstrap, "tls_bundles", return_value=bundles), patch.object(bootstrap.urllib.request, "urlopen", return_value=io.BytesIO(archive)), patch.object(bootstrap.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)) as run:
            root = Path(directory)
            bootstrap.install(api, cfg, root)
            values = json.loads((root / "managed.json").read_text())
            self.assertNotIn("private-key", json.dumps(values))
            self.assertEqual(values["env"][0], {"name": "CUSTOM_SETTING", "value": "custom"})
            self.assertIn("secretKeyRef", values["env"][1]["valueFrom"])
            self.assertEqual(values["env"][2]["value"], "status,logs,metrics,traces")
            self.assertEqual((root / "kubeconfig.json").stat().st_mode & 0o777, 0o600)
            args = run.call_args.args[0]
            self.assertIn("--atomic", args)
            self.assertIn("--wait", args)
            self.assertNotIn("test-token", args)
        writes = [(url, body) for url, method, body in api.requests if method in ("POST", "PUT") and body.get("kind") == "Secret"]
        self.assertEqual(len(writes), 3)
        self.assertTrue(all("/namespaces/braintrust-sandbox/" in url for url, _ in writes))
        client = next(body for _, body in writes if body["metadata"]["name"] == "sandbox-client-tls")
        self.assertEqual(base64.b64decode(client["data"]["client.key"]), b"client-private-key")

    def test_caller_overrides_cannot_change_managed_capacity_or_image(self):
        cfg = config()
        cfg["replicas"] = 0
        cfg["overrides"].update(image="stale", replicas=10)
        bundles = {key: {"cert": key} for key in ("server", "client")}
        values = bootstrap.worker_values(cfg, bundles, False)
        self.assertEqual(values["replicas"], 0)
        self.assertEqual(values["image"], "public.ecr.aws/braintrust/sandbox-service:v2.24.0")
        self.assertEqual(values["checkpointStore"], cfg["checkpoint_store"])
        self.assertNotIn("env", values)


if __name__ == "__main__":
    unittest.main()
