#!/bin/bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Braintrust BYOC Setup Script for GCP
#
# Creates the customer-project access envelope used by Braintrust managed BYOC:
# one deployment service account for automation and one support service account
# for approved human support.
#
# Roles are loaded from deployment-roles.json and support-roles.json. Services
# are loaded from services.json in the same directory as this script.
#
# Usage:
#   ./setup.sh --project <gcp-project-id>
#
# Requirements:
#   - gcloud CLI installed and authenticated
#   - jq installed
#   - Caller must have permission to create SAs and set IAM policies in the project
# -----------------------------------------------------------------------------

SUPPORT_GROUP="byoc-admins@braintrustdata.com"
AUTOMATION_SA="serviceAccount:braintrust-byoc-deploy-bridge@braintrust-byoc-management.iam.gserviceaccount.com"
DEPLOY_SA_NAME="braintrust-deploy"
SUPPORT_SA_NAME="braintrust-support"
PROJECT_ID=""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
  echo "Usage: $0 --project <gcp-project-id> [options]"
  echo ""
  echo "  --project          (required) GCP project ID to set up"
  echo "  --deploy-sa-name   (optional) Deployment service account name (default: braintrust-deploy)"
  echo "  --support-sa-name  (optional) Support service account name (default: braintrust-support)"
  echo "  --automation-sa    (optional) IAM member for Braintrust automation"
  echo "  --support-group    (optional) Braintrust support Google group"
  exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)
      PROJECT_ID="$2"
      shift 2
      ;;
    --deploy-sa-name)
      DEPLOY_SA_NAME="$2"
      shift 2
      ;;
    --support-sa-name)
      SUPPORT_SA_NAME="$2"
      shift 2
      ;;
    --automation-sa)
      AUTOMATION_SA="$2"
      shift 2
      ;;
    --support-group)
      SUPPORT_GROUP="$2"
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

DEPLOY_SA_EMAIL="${DEPLOY_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
SUPPORT_SA_EMAIL="${SUPPORT_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

# Load services and roles from JSON files
mapfile -t SERVICES         < <(jq -r '.[]' "$SCRIPT_DIR/services.json")
mapfile -t DEPLOYMENT_ROLES < <(jq -r '.[]' "$SCRIPT_DIR/deployment-roles.json")
mapfile -t SUPPORT_ROLES    < <(jq -r '.[]' "$SCRIPT_DIR/support-roles.json")

echo "=========================================="
echo " Braintrust BYOC GCP Setup"
echo "=========================================="
echo " Project:              $PROJECT_ID"
echo " Deployment SA:        $DEPLOY_SA_EMAIL"
echo " Support SA:           $SUPPORT_SA_EMAIL"
echo " Support Group:        $SUPPORT_GROUP"
echo " Automation Principal: $AUTOMATION_SA"
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
  (( count += 1 ))
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

create_service_account() {
  local account_name="$1"
  local account_email="$2"
  local display_name="$3"

  echo ">>> Creating service account: $account_email"

  if gcloud iam service-accounts describe "$account_email" --project="$PROJECT_ID" &>/dev/null; then
    echo "    Service account already exists, skipping creation."
    return
  fi

  gcloud iam service-accounts create "$account_name" \
    --project="$PROJECT_ID" \
    --display-name="$display_name"
  echo "    Created. Waiting for propagation..."
  # GCP IAM has eventual consistency; wait briefly before binding roles to the new SA.
  sleep 10
}

grant_project_roles() {
  local member="$1"
  local label="$2"
  shift 2
  local roles=("$@")

  echo ">>> Granting project IAM roles to $label..."
  for role in "${roles[@]}"; do
    echo "    $role"
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
      --member="$member" \
      --role="$role" \
      --quiet >/dev/null
  done
}

grant_service_account_impersonation() {
  local service_account_email="$1"
  local member="$2"
  local label="$3"

  echo ">>> Granting impersonation on $service_account_email to $label..."
  gcloud iam service-accounts add-iam-policy-binding "$service_account_email" \
    --project="$PROJECT_ID" \
    --member="$member" \
    --role="roles/iam.serviceAccountTokenCreator" \
    --quiet >/dev/null
  echo "    Done."
}

# -----------------------------------------------------------------------------
# Step 2: Create service accounts
# -----------------------------------------------------------------------------
create_service_account "$DEPLOY_SA_NAME" "$DEPLOY_SA_EMAIL" "Braintrust Deployment"
create_service_account "$SUPPORT_SA_NAME" "$SUPPORT_SA_EMAIL" "Braintrust Support"
echo ""

# -----------------------------------------------------------------------------
# Step 3: Grant project-level IAM roles
# -----------------------------------------------------------------------------
grant_project_roles "serviceAccount:$DEPLOY_SA_EMAIL" "$DEPLOY_SA_EMAIL" "${DEPLOYMENT_ROLES[@]}"
grant_project_roles "serviceAccount:$SUPPORT_SA_EMAIL" "$SUPPORT_SA_EMAIL" "${SUPPORT_ROLES[@]}"
echo ""

# -----------------------------------------------------------------------------
# Step 4: Grant impersonation to Braintrust support
# -----------------------------------------------------------------------------
grant_service_account_impersonation "$SUPPORT_SA_EMAIL" "group:$SUPPORT_GROUP" "$SUPPORT_GROUP"
echo ""

# -----------------------------------------------------------------------------
# Step 5: Grant impersonation to Braintrust automation
# This allows the Braintrust automation identity to impersonate the customer
# deployment service account. The AWS-to-GCP WIF bridge itself is maintained in
# the Braintrust-owned braintrust-byoc-management project, not this project.
# -----------------------------------------------------------------------------
grant_service_account_impersonation "$DEPLOY_SA_EMAIL" "$AUTOMATION_SA" "$AUTOMATION_SA"
echo ""

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo "=========================================="
echo " Setup complete!"
echo "=========================================="
echo ""
echo " Deployment service account: $DEPLOY_SA_EMAIL"
echo " Support service account:    $SUPPORT_SA_EMAIL"
echo " Automation principal:       $AUTOMATION_SA"
echo " Support group:              $SUPPORT_GROUP"
echo ""
