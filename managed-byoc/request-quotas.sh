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
#   - curl installed
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
COMPUTE_SERVICE="compute.googleapis.com"
QUOTAS_API_BASE="https://cloudquotas.googleapis.com/v1"

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

slugify() {
  echo "$1" \
    | tr '[:upper:]_' '[:lower:]-' \
    | sed -E 's/[^a-z0-9-]+/-/g; s/-+/-/g; s/^-//; s/-$//'
}

quota_api_get() {
  local path="$1"

  curl -fsS \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Accept: application/json" \
    "${QUOTAS_API_BASE}/${path}"
}

lookup_cloud_quota_value() {
  local quota_id="$1"
  local dimensions_json="$2"
  local quota_info_json

  if ! quota_info_json=$(quota_api_get "projects/${PROJECT_NUMBER}/locations/global/services/${COMPUTE_SERVICE}/quotaInfos/${quota_id}" 2>/dev/null); then
    return 1
  fi

  jq -er \
    --arg region "$REGION" \
    --argjson wanted_dims "$dimensions_json" '
      def quota_value:
        .details.quotaValue
        // .details.value
        // .details.effectiveValue
        // .details.resetValue
        // empty;

      def region_matches:
        (((.dimensions.region? // "") | ascii_downcase) == ($region | ascii_downcase))
        or (
          (.dimensions.region? // "") == ""
          and ((.applicableLocations // []) | index($region))
        );

      def wanted_dimensions_match:
        . as $info
        | all(
            $wanted_dims | to_entries[];
            (($info.dimensions[.key]? // "") | ascii_downcase) == (.value | ascii_downcase)
          );

      (.dimensionsInfos // .dimensionsInfo // [])
      | map(select(region_matches and wanted_dimensions_match))
      | .[0]
      | quota_value
    ' <<<"$quota_info_json"
}

lookup_compute_region_quota_value() {
  local compute_metric="$1"

  if [[ -z "$compute_metric" ]]; then
    return 1
  fi

  jq -er \
    --arg metric "$compute_metric" \
    '.[] | select(.metric == $metric) | .limit' \
    <<<"$REGION_QUOTAS_JSON"
}

lookup_current_quota_value() {
  local quota_id="$1"
  local dimensions_json="$2"
  local compute_metric="$3"
  local value

  if value=$(lookup_cloud_quota_value "$quota_id" "$dimensions_json" 2>/dev/null); then
    echo "$value"
    return 0
  fi

  if value=$(lookup_compute_region_quota_value "$compute_metric" 2>/dev/null); then
    echo "$value"
    return 0
  fi

  return 1
}

preference_id_for_quota() {
  local quota_id="$1"
  local dimensions_json="$2"
  local dim_suffix

  dim_suffix=$(jq -r \
    --arg region "$REGION" \
    '(. + {region: $region}) | to_entries | sort_by(.key) | map("\(.key)-\(.value)") | join("-")' \
    <<<"$dimensions_json")

  slugify "braintrust-${quota_id}-${dim_suffix}"
}

request_quota_preference() {
  local quota_id="$1"
  local dimensions_json="$2"
  local desired_value="$3"
  local preference_id="$4"
  local request_body

  request_body=$(jq -n \
    --arg name "projects/${PROJECT_NUMBER}/locations/global/quotaPreferences/${preference_id}" \
    --arg service "$COMPUTE_SERVICE" \
    --arg quota_id "$quota_id" \
    --arg email "$CONTACT_EMAIL" \
    --arg justification "Braintrust managed BYOC data plane deployment requires GKE node pools with headroom for autoscaling." \
    --argjson desired_value "$desired_value" \
    --argjson dimensions "$(
      jq -c --arg region "$REGION" '
        . + {region: $region}
        | if has("vm_family") then .vm_family = (.vm_family | ascii_upcase) else . end
      ' <<<"$dimensions_json"
    )" \
    '{
      name: $name,
      service: $service,
      quotaId: $quota_id,
      quotaConfig: { preferredValue: $desired_value },
      dimensions: $dimensions,
      justification: $justification,
      contactEmail: $email
    }')

  curl -fsS \
    -X PATCH \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$request_body" \
    "${QUOTAS_API_BASE}/projects/${PROJECT_NUMBER}/locations/global/quotaPreferences/${preference_id}?allowMissing=true" \
    >/dev/null
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
require_cmd curl

if ! ACCESS_TOKEN=$(gcloud auth print-access-token 2>/dev/null); then
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
  echo "Error: invalid quota config: each entry must have non-empty name, quota_id, and numeric desired_value." >&2
  exit 1
fi

# The Cloud Quotas API requires project number.
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')

# Keep this older lookup as a fallback for legacy quota metrics.
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
  name=$(echo "$entry" | jq -r '.name')
  quota_id=$(echo "$entry" | jq -r '.quota_id')
  compute_metric=$(echo "$entry" | jq -r '.compute_metric // ""')
  dimensions_json=$(echo "$entry" | jq -r '.dimensions // {} | tojson')
  desired_value=$(echo "$entry" | jq -r '.desired_value')

  current_value="n/a"
  current_readable="0"
  if fetched=$(lookup_current_quota_value "$quota_id" "$dimensions_json" "$compute_metric" 2>/dev/null); then
    current_value="$fetched"
    current_readable="1"
  fi

  if [[ "$MODE" == "request" ]]; then
    # Request if current is below desired, or if current is unreadable.
    should_request="1"
    if [[ "$current_readable" == "1" ]]; then
      should_request=$(compare_lt "$current_value" "$desired_value")
    fi

    if [[ "$should_request" == "1" ]]; then
      preference_id=$(preference_id_for_quota "$quota_id" "$dimensions_json")
      err_file=$(mktemp)
      if request_quota_preference "$quota_id" "$dimensions_json" "$desired_value" "$preference_id" 2>"$err_file"; then
        action="requested/updated"
      else
        action="request-failed: $(tr '\n' ' ' < "$err_file")"
      fi
      rm -f "$err_file"
    else
      action="already-ok"
    fi
  else
    if [[ "$current_readable" == "1" ]]; then
      if [[ "$(compare_lt "$current_value" "$desired_value")" == "1" ]]; then
        action="needs-raise"
      else
        action="ok"
      fi
    else
      action="unreadable"
    fi
  fi

  printf "%-36s %-12s %-12s %-20s\n" "$name" "$current_value" "$desired_value" "$action"
done < <(jq -c '.[]' "$CONFIG_PATH")

echo
if [[ "$MODE" == "request" ]]; then
  echo "Quota requests submitted. Approval by Google typically takes minutes to a few business days."
  echo "Monitor status in the Google Cloud console or with the Cloud Quotas API."
fi
