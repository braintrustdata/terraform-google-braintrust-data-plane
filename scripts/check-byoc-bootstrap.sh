#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

terraform -chdir=modules/byoc-bootstrap fmt -check -recursive
terraform -chdir=examples/byoc-bootstrap fmt -check
python3 -B -m unittest discover -s modules/byoc-bootstrap/tests -p 'test_*.py' -v
terraform -chdir=modules/byoc-bootstrap init -backend=false -input=false -lockfile=readonly
terraform -chdir=modules/byoc-bootstrap validate
terraform -chdir=modules/byoc-bootstrap test
terraform -chdir=examples/byoc-bootstrap init -backend=false -input=false -lockfile=readonly
terraform -chdir=examples/byoc-bootstrap validate
