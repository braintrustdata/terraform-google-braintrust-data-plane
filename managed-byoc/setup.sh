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
#   ./setup.sh --project <gcp-project-id> --dry-run
#   ./setup.sh --project <gcp-project-id> --license-key <brainstore-license-key>
#
# Requirements:
#   - gcloud CLI installed and authenticated
#   - jq installed
#   - Caller must have permission to create SAs and set IAM policies in the project
# -----------------------------------------------------------------------------

SUPPORT_GROUP="byoc-support@braintrustdata.com"
AUTOMATION_SA="serviceAccount:braintrust-byoc-deploy-bridge@braintrust-byoc-management.iam.gserviceaccount.com"
DEPLOY_SA_NAME="braintrust-deploy"
SUPPORT_SA_NAME="braintrust-support"
PROJECT_ID=""
DRY_RUN=false
LICENSE_KEY=""
LICENSE_SECRET_NAME="brainstore-license-key"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
  local status="${1:-1}"
  echo "Usage: $0 --project <gcp-project-id> [options]"
  echo ""
  echo "  --project          (required) GCP project ID to set up"
  echo "  --deploy-sa-name   (optional) Deployment service account name (default: braintrust-deploy)"
  echo "  --support-sa-name  (optional) Support service account name (default: braintrust-support)"
  echo "  --automation-sa    (optional) IAM member for Braintrust automation"
  echo "  --support-group    (optional) Braintrust support Google group"
  echo "  --license-key      (optional) Brainstore license key to store in Secret Manager"
  echo "  --license-secret   (optional) Secret Manager secret name (default: brainstore-license-key)"
  echo "  --dry-run          (optional) Preview commands without changing the project"
  exit "$status"
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
    --license-key)
      LICENSE_KEY="$2"
      shift 2
      ;;
    --license-secret)
      LICENSE_SECRET_NAME="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      usage 0
      ;;
    *)
      echo "Unknown argument: $1"
      usage 1
      ;;
  esac
done

# Validate
if [[ -z "$PROJECT_ID" ]]; then
  echo "Error: --project is required"
  usage 1
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

if ! gcloud projects describe "$PROJECT_ID" --format="value(projectId)" >/dev/null; then
  echo "Error: project '$PROJECT_ID' was not found or is not accessible to the active gcloud identity."
  exit 1
fi

DEPLOY_SA_EMAIL="${DEPLOY_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
SUPPORT_SA_EMAIL="${SUPPORT_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

# Load services and roles from JSON files
SERVICES=()
DEPLOYMENT_ROLES=()
SUPPORT_ROLES=()

while IFS= read -r item; do
  SERVICES+=("$item")
done < <(jq -r '.[]' "$SCRIPT_DIR/services.json")

while IFS= read -r item; do
  DEPLOYMENT_ROLES+=("$item")
done < <(jq -r '.[]' "$SCRIPT_DIR/deployment-roles.json")

while IFS= read -r item; do
  SUPPORT_ROLES+=("$item")
done < <(jq -r '.[]' "$SCRIPT_DIR/support-roles.json")

run() {
  if [[ "$DRY_RUN" == "true" ]]; then
    printf >&2 'DRY-RUN:'
    printf >&2 ' %q' "$@"
    printf >&2 '\n'
    return 0
  fi

  "$@"
}

echo "=========================================="
echo " Braintrust BYOC GCP Setup"
echo "=========================================="
echo " Project:              $PROJECT_ID"
echo " Deployment SA:        $DEPLOY_SA_EMAIL"
echo " Support SA:           $SUPPORT_SA_EMAIL"
echo " Support Group:        $SUPPORT_GROUP"
echo " Automation Principal: $AUTOMATION_SA"
echo " License Secret:       $LICENSE_SECRET_NAME"
echo " License Key Provided: $([[ -n "$LICENSE_KEY" ]] && echo true || echo false)"
echo " Dry Run:              $DRY_RUN"
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
    run gcloud services enable "${chunk[@]}" --project="$PROJECT_ID"
    chunk=()
    count=0
  fi
done
if (( ${#chunk[@]} > 0 )); then
  run gcloud services enable "${chunk[@]}" --project="$PROJECT_ID"
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

  run gcloud iam service-accounts create "$account_name" \
    --project="$PROJECT_ID" \
    --display-name="$display_name"
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "    Dry run only; skipping propagation wait."
    return
  fi
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
    run gcloud projects add-iam-policy-binding "$PROJECT_ID" \
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
  run gcloud iam service-accounts add-iam-policy-binding "$service_account_email" \
    --project="$PROJECT_ID" \
    --member="$member" \
    --role="roles/iam.serviceAccountTokenCreator" \
    --quiet >/dev/null
  echo "    Done."
}

create_or_update_license_secret() {
  if [[ -z "$LICENSE_KEY" ]]; then
    echo ">>> Skipping Brainstore license secret; --license-key was not provided."
    return
  fi

  echo ">>> Creating or updating Brainstore license secret: $LICENSE_SECRET_NAME"

  if ! gcloud secrets describe "$LICENSE_SECRET_NAME" --project="$PROJECT_ID" &>/dev/null; then
    run gcloud secrets create "$LICENSE_SECRET_NAME" \
      --project="$PROJECT_ID" \
      --replication-policy="automatic" >/dev/null
  else
    echo "    Secret already exists."
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "    Dry run only; skipping secret value comparison and version creation."
    return
  fi

  local current_value=""
  if current_value="$(gcloud secrets versions access latest --secret="$LICENSE_SECRET_NAME" --project="$PROJECT_ID" 2>/dev/null)"; then
    if [[ "$current_value" == "$LICENSE_KEY" ]]; then
      echo "    Latest secret version already matches provided license key, skipping new version."
      return
    fi
  fi

  printf '%s' "$LICENSE_KEY" | gcloud secrets versions add "$LICENSE_SECRET_NAME" \
    --project="$PROJECT_ID" \
    --data-file=- >/dev/null
  echo "    Added new secret version."
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
# Step 4: Create or update Brainstore license secret
# -----------------------------------------------------------------------------
create_or_update_license_secret
echo ""

# -----------------------------------------------------------------------------
# Step 5: Grant impersonation to Braintrust support
# -----------------------------------------------------------------------------
grant_service_account_impersonation "$SUPPORT_SA_EMAIL" "group:$SUPPORT_GROUP" "$SUPPORT_GROUP"
echo ""

# -----------------------------------------------------------------------------
# Step 6: Grant impersonation to Braintrust automation
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
echo " License secret:             $LICENSE_SECRET_NAME"
echo ""
