#!/bin/bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Braintrust BYOC Setup Script for GCP
#
# Creates a service account in a customer GCP project,
# grants it the IAM roles needed to deploy the braintrust-data-plane module,
# and allows byoc-admins@braintrustdata.com to impersonate it.
#
# Roles are loaded from roles.json and services from services.json in the
# same directory as this script.
#
# Usage:
#   ./setup.sh --project <gcp-project-id> [--sa-name <service-account-name>]
#
# Requirements:
#   - gcloud CLI installed and authenticated
#   - jq installed
#   - Caller must have permission to create SAs and set IAM policies in the project
# -----------------------------------------------------------------------------

BYOC_ADMIN_GROUP="byoc-admins@braintrustdata.com"
SA_NAME="braintrust-mgmt"
PROJECT_ID=""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
  echo "Usage: $0 --project <gcp-project-id> [--sa-name <service-account-name>]"
  echo ""
  echo "  --project   (required) GCP project ID to set up"
  echo "  --sa-name   (optional) Service account name (default: braintrust-mgmt)"
  exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)
      PROJECT_ID="$2"
      shift 2
      ;;
    --sa-name)
      SA_NAME="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      ;;
  esac
done

# Validate
if [[ -z "$PROJECT_ID" ]]; then
  echo "Error: --project is required"
  usage
fi

if ! command -v gcloud &>/dev/null; then
  echo "Error: gcloud CLI is not installed. Install it from https://cloud.google.com/sdk/docs/install"
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "Error: jq is not installed. Install it from https://jqlang.github.io/jq/download/"
  exit 1
fi

if ! gcloud auth print-access-token &>/dev/null; then
  echo "Error: not authenticated with gcloud. Run: gcloud auth login"
  exit 1
fi

SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

# Load services and roles from JSON files
mapfile -t SERVICES < <(jq -r '.[]' "$SCRIPT_DIR/services.json")
mapfile -t ROLES    < <(jq -r '.[]' "$SCRIPT_DIR/roles.json")

echo "=========================================="
echo " Braintrust BYOC GCP Setup"
echo "=========================================="
echo " Project:         $PROJECT_ID"
echo " Service Account: $SA_EMAIL"
echo " Admin Group:     $BYOC_ADMIN_GROUP"
echo "=========================================="
echo ""

# -----------------------------------------------------------------------------
# Step 1: Enable required GCP APIs
# -----------------------------------------------------------------------------
echo ">>> Enabling required GCP APIs..."

# gcloud services enable has a max batch size of 20; enable in chunks
chunk=()
count=0
for svc in "${SERVICES[@]}"; do
  chunk+=("$svc")
  (( count++ ))
  if (( count == 20 )); then
    gcloud services enable "${chunk[@]}" --project="$PROJECT_ID"
    chunk=()
    count=0
  fi
done
if (( ${#chunk[@]} > 0 )); then
  gcloud services enable "${chunk[@]}" --project="$PROJECT_ID"
fi

echo "    Done."
echo ""

# -----------------------------------------------------------------------------
# Step 2: Create service account
# -----------------------------------------------------------------------------
echo ">>> Creating service account: $SA_EMAIL"

if gcloud iam service-accounts describe "$SA_EMAIL" --project="$PROJECT_ID" &>/dev/null; then
  echo "    Service account already exists, skipping creation."
else
  gcloud iam service-accounts create "$SA_NAME" \
    --project="$PROJECT_ID" \
    --display-name="Braintrust Management"
  echo "    Created. Waiting for propagation..."
  # GCP IAM has eventual consistency — wait briefly before binding roles to the new SA
  sleep 10
fi
echo ""

# -----------------------------------------------------------------------------
# Step 3: Grant project-level IAM roles
# -----------------------------------------------------------------------------
echo ">>> Granting project IAM roles to service account..."
for role in "${ROLES[@]}"; do
  echo "    $role"
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$SA_EMAIL" \
    --role="$role" \
    --quiet >/dev/null
done
echo ""

echo ">>> Granting project IAM roles to $BYOC_ADMIN_GROUP..."
for role in "${ROLES[@]}"; do
  echo "    $role"
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="group:$BYOC_ADMIN_GROUP" \
    --role="$role" \
    --quiet >/dev/null
done
echo ""

# -----------------------------------------------------------------------------
# Step 4: Grant impersonation to the admin group
# -----------------------------------------------------------------------------
echo ">>> Granting impersonation on $SA_EMAIL to $BYOC_ADMIN_GROUP..."
gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" \
  --project="$PROJECT_ID" \
  --member="group:$BYOC_ADMIN_GROUP" \
  --role="roles/iam.serviceAccountTokenCreator"
echo "    Done."
echo ""

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo "=========================================="
echo " Setup complete!"
echo "=========================================="
echo ""
echo " Service account: $SA_EMAIL"
echo ""
