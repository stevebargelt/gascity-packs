#!/bin/bash
set -euo pipefail

# Phase 4: Azure infrastructure bootstrap (Path A only).
# Creates resource group, tfstate storage, app registration, federated credentials, role assignments.

CONFIG_FILE=".bootstrap-config"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "ERROR: $CONFIG_FILE not found. Run 01-init.sh first."
  exit 1
fi
source "$CONFIG_FILE"

echo "=== Phase 4: Azure Infrastructure Bootstrap ==="
echo ""

if [[ "$SUPABASE_STRATEGY" != "1" ]]; then
  echo "Not creating new infrastructure (strategy is not 'new self-hosted')."
  echo "Phase 4 skipped."
  exit 0
fi

# --- Verify Azure auth ---

if ! az account show &>/dev/null 2>&1; then
  echo "Not signed in to Azure. Running 'az login'..."
  az login
fi

SUB_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
echo "  Subscription: $SUB_ID"
echo "  Tenant:       $TENANT_ID"
echo ""

# --- Resource group ---

LOCATION="${AZURE_LOCATION:-westus3}"
echo "Creating resource group '$PROJECT' in $LOCATION..."
az group create --name "$PROJECT" --location "$LOCATION" --output none
echo "  Done."

# --- Tfstate storage ---

# Storage account names: lowercase alphanumeric only, 3-24 chars
STORAGE_ACCT="${PROJECT//[^a-z0-9]/}tfstate"
STORAGE_ACCT="${STORAGE_ACCT:0:24}"

echo "Creating tfstate storage account '$STORAGE_ACCT'..."
az storage account create \
  --name "$STORAGE_ACCT" \
  --resource-group "$PROJECT" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --allow-blob-public-access false \
  --output none
echo "  Done."

echo "Creating tfstate container..."
az storage container create \
  --name tfstate \
  --account-name "$STORAGE_ACCT" \
  --output none
echo "  Done."

# --- App registration + service principal ---

APP_DISPLAY_NAME="${PROJECT}-github-actions"
echo "Creating app registration '$APP_DISPLAY_NAME'..."
APP_ID=$(az ad app create --display-name "$APP_DISPLAY_NAME" --query appId -o tsv)
echo "  App ID: $APP_ID"

echo "Creating service principal..."
SP_OBJECT_ID=$(az ad sp create --id "$APP_ID" --query id -o tsv 2>/dev/null || \
  az ad sp show --id "$APP_ID" --query id -o tsv)
echo "  SP Object ID: $SP_OBJECT_ID"

# --- Federated credentials for GitHub Actions OIDC ---

echo "Creating federated credentials..."
for CRED_NAME in main pull-request production; do
  case "$CRED_NAME" in
    main)          SUBJECT="repo:${REPO}:ref:refs/heads/main" ;;
    pull-request)  SUBJECT="repo:${REPO}:pull_request" ;;
    production)    SUBJECT="repo:${REPO}:environment:production" ;;
  esac

  az ad app federated-credential create --id "$APP_ID" --parameters "{
    \"name\": \"${PROJECT}-${CRED_NAME}\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"$SUBJECT\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }" --output none 2>/dev/null || echo "  (${CRED_NAME} may already exist)"

  echo "  ${CRED_NAME}: $SUBJECT"
done

# --- Role assignments (scoped to resource group, not subscription) ---

RG_SCOPE="/subscriptions/$SUB_ID/resourceGroups/$PROJECT"

echo "Assigning Contributor role (scoped to resource group)..."
az role assignment create \
  --assignee "$SP_OBJECT_ID" \
  --role Contributor \
  --scope "$RG_SCOPE" \
  --output none 2>/dev/null || echo "  (may already exist)"
echo "  Done."

echo "Assigning User Access Administrator role (scoped to resource group)..."
az role assignment create \
  --assignee "$SP_OBJECT_ID" \
  --role "User Access Administrator" \
  --scope "$RG_SCOPE" \
  --output none 2>/dev/null || echo "  (may already exist)"
echo "  Done."

# --- Create GitHub Actions production environment ---

echo "Creating GitHub Actions 'production' environment..."
gh api --method PUT "repos/${REPO}/environments/production" --silent 2>/dev/null || \
  echo "  (may already exist or insufficient permissions)"
echo "  Done."

# --- Store in 1Password ---

echo "Storing Azure IDs in 1Password..."
if op item get "Azure" --vault "$PROJECT" &>/dev/null 2>&1; then
  op item edit "Azure" --vault "$PROJECT" \
    "client_id=$APP_ID" \
    "tenant_id=$TENANT_ID" \
    "subscription_id=$SUB_ID" \
    "storage_account=$STORAGE_ACCT" \
    "sp_object_id=$SP_OBJECT_ID" \
    >/dev/null
else
  op item create --vault "$PROJECT" --category "Login" \
    --title "Azure" \
    "client_id=$APP_ID" \
    "tenant_id=$TENANT_ID" \
    "subscription_id=$SUB_ID" \
    "storage_account=$STORAGE_ACCT" \
    "sp_object_id=$SP_OBJECT_ID" \
    >/dev/null
fi
echo "  Done."

echo ""
echo "Phase 4 complete. Azure infrastructure bootstrapped."
echo "  Resource group: $PROJECT"
echo "  Tfstate:        $STORAGE_ACCT/tfstate"
echo "  App reg:        $APP_DISPLAY_NAME ($APP_ID)"
echo "  Federated creds: main, pull-request, production"
echo "  Roles:          Contributor + User Access Administrator"
