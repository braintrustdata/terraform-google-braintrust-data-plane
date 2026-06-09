#!/bin/bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Braintrust BYOC Quota Management Script for GCP
#
# Lists current quota values and/or submits increase requests for GKE compute
# machine families and their local SSD limits.
#
# Usage:
#   ./request-quotas.sh --project <id> --region <region> [list|request]
#
# Config precedence:
#   1) QUOTA_CONFIG_PATH env var (if set)
#   2) quota-config.override.json (if present alongside this script)
#   3) quota-config.json (default)
#
# Requirements:
#   - gcloud CLI installed and authenticated
#   - jq installed
# -----------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_CONFIG_PATH="$SCRIPT_DIR/quota-config.json"
OVERRIDE_CONFIG_PATH="$SCRIPT_DIR/quota-config.override.json"
CONFIG_PATH="${QUOTA_CONFIG_PATH:-}"
if [[ -z "$CONFIG_PATH" ]]; then
  CONFIG_PATH="$DEFAULT_CONFIG_PATH"
  if [[ -f "$OVERRIDE_CONFIG_PATH" ]]; then
    CONFIG_PATH="$OVERRIDE_CONFIG_PATH"
  fi
fi

MODE="list"
PROJECT_ID=""
REGION=""
CONTACT_EMAIL="byoc-admins@braintrustdata.com"

usage() {
  cat <<'EOF'
Usage:
  ./request-quotas.sh --project <id> --region <region> [list|request]

Behavior:
  list     Show current quota limits and desired values from config (default).
  request  Submit increase requests for any quota below its desired value.

Options:
  --project   (required) GCP project ID
  --region    (required) GCP region (e.g. us-central1)

Environment overrides:
  QUOTA_CONFIG_PATH=/path/to/quota-config.json   explicit config path wins over defaults
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: missing required command: $1" >&2
    exit 1
  fi
}

compare_lt() {
  awk -v a="$1" -v b="$2" 'BEGIN { print (a < b) ? "1" : "0" }'
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)   PROJECT_ID="$2"; shift 2 ;;
    --region)    REGION="$2";     shift 2 ;;
    list|request) MODE="$1";      shift ;;
    -h|--help)   usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$PROJECT_ID" || -z "$REGION" ]]; then
  echo "Error: --project and --region are required" >&2
  usage
  exit 1
fi

require_cmd gcloud
require_cmd jq

if ! gcloud auth print-access-token &>/dev/null; then
  echo "Error: not authenticated with gcloud. Run: gcloud auth login" >&2
  exit 1
fi

if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "Error: config file not found: $CONFIG_PATH" >&2
  exit 1
fi

# Validate config JSON
jq empty "$CONFIG_PATH" >/dev/null
if ! jq -e 'all(.[]; (.name | type == "string" and length > 0) and (.quota_id | type == "string" and length > 0) and (.desired_value | type == "number"))' "$CONFIG_PATH" >/dev/null; then
  echo "Error: invalid quota config — each entry must have non-empty name, quota_id, and numeric desired_value." >&2
  exit 1
fi

# The Cloud Quotas API requires project number
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')

# Fetch all regional quotas once for current-value lookups
REGION_QUOTAS_JSON=$(gcloud compute regions describe "$REGION" \
  --project="$PROJECT_ID" \
  --format=json 2>/dev/null | jq '.quotas')

echo "Project: $PROJECT_ID"
echo "Region:  $REGION"
echo "Config:  $CONFIG_PATH"

if [[ "$MODE" == "request" ]]; then
  echo
  echo "Confirm to submit quota increase requests:"
  read -r -p "Continue? Type 'yes' to proceed: " APPROVAL
  if [[ "$APPROVAL" != "yes" ]]; then
    echo "Aborted."
    exit 0
  fi
fi

echo
printf "%-36s %-12s %-12s %-20s\n" "Quota" "Current" "Desired" "Action"
printf "%-36s %-12s %-12s %-20s\n" "------------------------------------" "------------" "------------" "--------------------"

while IFS= read -r entry; do
  name=$(echo "$entry"           | jq -r '.name')
  quota_id=$(echo "$entry"       | jq -r '.quota_id')
  compute_metric=$(echo "$entry" | jq -r '.compute_metric // ""')
  dimensions_json=$(echo "$entry"| jq -r '.dimensions // {} | tojson')
  desired_value=$(echo "$entry"  | jq -r '.desired_value')

  # Look up current quota limit from compute regions describe if metric is available
  current_value="n/a"
  if [[ -n "$compute_metric" ]]; then
    fetched=$(echo "$REGION_QUOTAS_JSON" | \
      jq -r --arg m "$compute_metric" '.[] | select(.metric == $m) | .limit' 2>/dev/null || true)
    [[ -n "$fetched" ]] && current_value="$fetched"
  fi

  if [[ "$MODE" == "request" ]]; then
    # Build dimensions string: region + any extra dims from config
    dim_str="region=$REGION"
    extra_dims=$(echo "$dimensions_json" | jq -r 'to_entries[] | "\(.key)=\(.value)"' 2>/dev/null || true)
    if [[ -n "$extra_dims" ]]; then
      dim_str="${dim_str},${extra_dims//$'\n'/,}"
    fi

    # Request if current is below desired, or if current is unknown
    should_request="1"
    if [[ "$current_value" != "n/a" ]]; then
      should_request=$(compare_lt "$current_value" "$desired_value")
    fi

    if [[ "$should_request" == "1" ]]; then
      err_file=$(mktemp)
      if gcloud beta quotas preferences create \
          --project="$PROJECT_NUMBER" \
          --service=compute.googleapis.com \
          --quota-id="$quota_id" \
          --preferred-value="$desired_value" \
          --dimensions="$dim_str" \
          --email="$CONTACT_EMAIL" \
          --justification="Braintrust managed BYOC data plane deployment requires GKE node pools with headroom for autoscaling." \
          --quiet >/dev/null 2>"$err_file"; then
        action="requested"
      else
        # Preference may already exist — try update
        dim_suffix=$(echo "$dimensions_json" | jq -r 'to_entries | map("\(.key)-\(.value)") | join("-")' 2>/dev/null || true)
        pref_id="${quota_id}${dim_suffix:+-$dim_suffix}"
        if gcloud beta quotas preferences update "$pref_id" \
            --service=compute.googleapis.com \
            --quota-id="$quota_id" \
            --preferred-value="$desired_value" \
            --project="$PROJECT_NUMBER" \
            --quiet >/dev/null 2>>"$err_file"; then
          action="updated"
        else
          action="request-failed: $(tr '\n' ' ' < "$err_file")"
        fi
      fi
      rm -f "$err_file"
    else
      action="already-ok"
    fi
  else
    # list mode
    if [[ "$current_value" != "n/a" ]]; then
      if [[ "$(compare_lt "$current_value" "$desired_value")" == "1" ]]; then
        action="needs-raise"
      else
        action="ok"
      fi
    else
      action="unknown"
    fi
  fi

  printf "%-36s %-12s %-12s %-20s\n" "$name" "$current_value" "$desired_value" "$action"

done < <(jq -c '.[]' "$CONFIG_PATH")

echo
if [[ "$MODE" == "request" ]]; then
  echo "Quota requests submitted. Approval by Google typically takes minutes to a few business days."
  echo "Monitor status with: gcloud beta quotas preferences list --project=$PROJECT_ID"
fi
