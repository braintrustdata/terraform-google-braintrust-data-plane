"""Install isolated Loop workers. Credentials stay in Secret Manager and the cluster."""
import base64
import hashlib
import io
import json
import os
from pathlib import Path
import re
import secrets
import subprocess
import tarfile
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request


class Api:
    def __init__(self):
        self.token = None
        self.expires = 0

    def access_token(self):
        if time.monotonic() >= self.expires:
            # GKE needs the email scope to identify the service account.
            query = urllib.parse.urlencode({"scopes": "https://www.googleapis.com/auth/cloud-platform,https://www.googleapis.com/auth/userinfo.email"})
            req = urllib.request.Request(
                "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token?" + query,
                headers={"Metadata-Flavor": "Google"},
            )
            opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
            with opener.open(req, timeout=10) as response:
                value = json.load(response)
            self.token = value["access_token"]
            self.expires = time.monotonic() + value["expires_in"] - 60
        return self.token

    def request(self, url, method="GET", body=None, missing=False):
        deadline = time.monotonic() + 120
        while True:
            request = urllib.request.Request(
                url,
                data=None if body is None else json.dumps(body).encode(),
                method=method,
                headers={"Authorization": "Bearer " + self.access_token(), "Content-Type": "application/json"},
            )
            try:
                with urllib.request.urlopen(request, timeout=30) as response:
                    return json.load(response)
            except urllib.error.HTTPError as error:
                if error.code == 404 and missing:
                    return None
                if error.code not in (403, 429, 500, 502, 503, 504) or time.monotonic() >= deadline:
                    raise RuntimeError(f"Bootstrap API request failed ({error.code})") from None
                time.sleep(5)

    def read_secret(self, name, version="latest"):
        value = self.request(f"https://secretmanager.googleapis.com/v1/{name}/versions/{version}:access", missing=True)
        return None if value is None else base64.b64decode(value["payload"]["data"])

    def write_secret(self, name, value):
        return self.request(
            f"https://secretmanager.googleapis.com/v1/{name}:addVersion", "POST",
            {"payload": {"data": base64.b64encode(value).decode()}},
        )


def private_file(path, value):
    path.write_text(value)
    path.chmod(0o600)
    return str(path)


def openssl(*args):
    result = subprocess.run(["openssl", *args], capture_output=True)
    if result.returncode:
        raise RuntimeError("Bootstrap certificate operation failed")


def create_ca(directory, name):
    key, cert = directory / (name + ".key"), directory / (name + ".pem")
    openssl("req", "-x509", "-newkey", "ec", "-pkeyopt", "ec_paramgen_curve:prime256v1", "-nodes",
            "-keyout", str(key), "-out", str(cert), "-days", "3650", "-sha256", "-subj", "/CN=" + name,
            "-addext", "basicConstraints=critical,CA:TRUE", "-addext", "keyUsage=critical,keyCertSign,cRLSign")
    return {"key": key.read_text(), "cert": cert.read_text()}


def create_identity(directory, ca, name, hostname=None):
    key, csr, cert = directory / (name + ".key"), directory / (name + ".csr"), directory / (name + ".pem")
    ca_key = private_file(directory / (name + "-ca.key"), ca["key"])
    ca_cert = private_file(directory / (name + "-ca.pem"), ca["cert"])
    openssl("req", "-new", "-newkey", "ec", "-pkeyopt", "ec_paramgen_curve:prime256v1", "-nodes",
            "-keyout", str(key), "-out", str(csr), "-subj", "/CN=" + name)
    extensions = "basicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature\nextendedKeyUsage="
    extensions += "serverAuth\nsubjectAltName=DNS:" + hostname + "\n" if hostname else "clientAuth\n"
    ext = private_file(directory / (name + ".ext"), extensions)
    openssl("x509", "-req", "-in", str(csr), "-CA", ca_cert, "-CAkey", ca_key, "-set_serial", str(secrets.randbits(128)),
            "-days", "3650", "-sha256", "-extfile", ext, "-out", str(cert))
    return {"cert": cert.read_text(), "key": key.read_text()}


def tls_bundles(api, config, directory):
    names = config["secrets"]
    seed_bytes = api.read_secret(names["seed"], "1")
    if seed_bytes is None:
        seed = {kind: create_ca(directory, "sandbox-" + kind + "-ca") for kind in ("server", "client")}
        api.write_secret(names["seed"], json.dumps(seed).encode())
        # Version one is canonical if two first-time installers race.
        seed_bytes = api.read_secret(names["seed"], "1")
    seed = json.loads(seed_bytes)
    bundles = {}
    for kind, peer in (("server", "client"), ("client", "server")):
        existing = api.read_secret(names[kind])
        if existing is not None:
            bundle = json.loads(existing)
            if not all(isinstance(bundle.get(field), str) and bundle[field] for field in ("cert", "key", "ca_cert")):
                raise RuntimeError("Stored TLS bundle is invalid; refusing to replace it")
            if bundle["ca_cert"] != seed[peer]["cert"]:
                raise RuntimeError("Stored TLS trust roots differ; refusing to rotate them")
            if kind == "client" or bundle.get("hostname") == config["hostname"]:
                bundles[kind] = bundle
                continue
        bundle = create_identity(directory, seed[kind], "sandbox-" + kind, config["hostname"] if kind == "server" else None)
        bundle["ca_cert"] = seed[peer]["cert"]
        if kind == "server":
            bundle["hostname"] = config["hostname"]
        api.write_secret(names[kind], json.dumps(bundle).encode())
        bundles[kind] = bundle
    return bundles


def kube_upsert(api, endpoint, namespace, name, data):
    url = f"{endpoint}/api/v1/namespaces/{namespace}/secrets/{name}"
    previous = api.request(url, missing=True)
    metadata = {"name": name, "namespace": namespace}
    if previous:
        for field in ("resourceVersion", "annotations", "labels", "ownerReferences"):
            if field in previous["metadata"]:
                metadata[field] = previous["metadata"][field]
    body = {"apiVersion": "v1", "kind": "Secret", "metadata": metadata, "type": "Opaque",
            "data": {key: base64.b64encode(value.encode()).decode() for key, value in data.items()}}
    if previous:
        api.request(url, "PUT", body)
    else:
        api.request(f"{endpoint}/api/v1/namespaces/{namespace}/secrets", "POST", body)


def worker_values(config, bundles, licensed):
    revision = hashlib.sha256((bundles["server"]["cert"] + bundles["client"]["cert"]).encode()).hexdigest()
    values = {
        "hostname": config["hostname"], "image": "public.ecr.aws/braintrust/sandbox-service:" + config["services_version"],
        "replicas": config["replicas"], "gitResources": True, "nodePrep": {"enabled": True}, "tlsRevision": revision,
        "externalDns": {"enabled": True, "provider": "google", "extraArgs": config["dns_args"]},
        "filesystemRetention": True, "checkpointStore": config["checkpoint_store"],
    }
    if licensed:
        managed = ("BRAINSTORE_LICENSE_KEY", "BRAINSTORE_CONTROL_PLANE_TELEMETRY", "BRAINTRUST_ENV")
        values["env"] = [item for item in config["overrides"].get("env") or [] if item["name"] not in managed] + [
            {"name": managed[0], "valueFrom": {"secretKeyRef": {"name": "sandbox-telemetry", "key": "license-key"}}},
            {"name": managed[1], "value": ",".join(filter(None, [config["telemetry"], "metrics", "traces"]))},
            {"name": managed[2], "value": "customer"},
        ]
    return values


def wait_for_workers(api, config, deadline):
    # Helm skips readiness for OnDelete StatefulSets; the worker controller owns replacement.
    url = f"{config['endpoint']}/apis/apps/v1/namespaces/{config['namespace']}/statefulsets/sandbox-service"
    while True:
        workload = api.request(url)
        status, replicas = workload.get("status", {}), config["replicas"]
        if (status.get("observedGeneration", 0) >= workload["metadata"]["generation"]
                and workload["spec"]["replicas"] == replicas
                and all(status.get(field, 0) == replicas for field in ("replicas", "updatedReplicas", "readyReplicas"))):
            return
        if time.monotonic() >= deadline:
            raise RuntimeError("Worker replicas did not become ready; inspect worker rollout events")
        time.sleep(5)


def install(api, config, directory):
    if not re.fullmatch(r"[a-zA-Z0-9.-]+", config["hostname"]):
        raise RuntimeError("Invalid worker hostname")
    if not re.fullmatch(r"https://[a-zA-Z0-9.-]+\.gke\.goog", config["endpoint"]):
        raise RuntimeError("Worker bootstrap requires the IAM-authenticated GKE DNS endpoint")
    print("Preparing persistent worker TLS", flush=True)
    bundles = tls_bundles(api, config, directory)
    print("Configuring worker namespace and credentials", flush=True)
    endpoint, namespace = config["endpoint"], config["namespace"]
    # This also waits for the new installer's IAM grant to propagate.
    if api.request(f"{endpoint}/api/v1/namespaces/{namespace}", missing=True) is None:
        api.request(endpoint + "/api/v1/namespaces", "POST", {"apiVersion": "v1", "kind": "Namespace", "metadata": {"name": namespace}})
    client, server = bundles["client"], bundles["server"]
    kube_upsert(api, endpoint, namespace, "sandbox-client-tls", {"client.pem": client["cert"], "client.key": client["key"], "server-ca.pem": client["ca_cert"]})
    kube_upsert(api, endpoint, namespace, "sandbox-tls", {"cert.pem": server["cert"], "key.pem": server["key"], "ca_cert.pem": server["ca_cert"]})
    license_key = None
    if config["license_secret"]:
        license_key = api.read_secret(f"projects/{config['project']}/secrets/{config['license_secret']}")
        if license_key is not None:
            kube_upsert(api, endpoint, namespace, "sandbox-telemetry", {"license-key": license_key.decode()})
    with urllib.request.urlopen(config["helm_url"], timeout=60) as response:
        archive = response.read()
    if hashlib.sha256(archive).hexdigest() != config["helm_sha256"]:
        raise RuntimeError("Helm binary checksum mismatch")
    with tarfile.open(fileobj=io.BytesIO(archive), mode="r:gz") as tar:
        helm = directory / "helm"
        helm.write_bytes(tar.extractfile("linux-amd64/helm").read())
        helm.chmod(0o700)
    kubeconfig = private_file(directory / "kubeconfig.json", json.dumps({
        "apiVersion": "v1", "kind": "Config", "current-context": "workers",
        "clusters": [{"name": "workers", "cluster": {"server": endpoint}}],
        "users": [{"name": "installer", "user": {"token": api.access_token()}}],
        "contexts": [{"name": "workers", "context": {"cluster": "workers", "user": "installer", "namespace": namespace}}],
    }))
    overrides = private_file(directory / "overrides.json", json.dumps(config["overrides"]))
    managed = private_file(directory / "managed.json", json.dumps(worker_values(config, bundles, license_key is not None)))
    print("Installing worker chart and waiting for readiness", flush=True)
    deadline = time.monotonic() + 1200
    result = subprocess.run([str(helm), "upgrade", "--install", "sandbox-service", config["chart_url"], "--namespace", namespace,
                             "--values", overrides, "--values", managed, "--wait", "--atomic", "--timeout", "1200s", "--history-max", "5"],
                            env={**os.environ, "KUBECONFIG": kubeconfig}, capture_output=True)
    if result.returncode:
        raise RuntimeError(f"Worker chart installation failed (exit {result.returncode}); inspect worker rollout events")
    wait_for_workers(api, config, deadline)
    print("Loop workers installed; TLS retained in Secret Manager")


def main():
    os.umask(0o077)
    config = json.loads(os.environ["LOOP_BOOTSTRAP_CONFIG"])
    with tempfile.TemporaryDirectory() as path:
        install(Api(), config, Path(path))


if __name__ == "__main__":
    main()
