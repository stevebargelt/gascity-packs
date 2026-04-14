#!/bin/bash
set -euo pipefail

# Phase 5: Read secrets from 1Password and push to all destinations.
# Pushes to: GitHub Actions secrets/variables, Vercel env vars, EAS secrets.

CONFIG_FILE=".bootstrap-config"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "ERROR: $CONFIG_FILE not found. Run 01-init.sh first."
  exit 1
fi
source "$CONFIG_FILE"

echo "=== Phase 5: Push Secrets to All Destinations ==="
echo ""

# --- Helper: read from 1Password, fail gracefully ---

op_read() {
  local ref="$1"
  local val
  val=$(op read "$ref" 2>/dev/null || true)
  if [[ -z "$val" ]]; then
    echo "  WARNING: Could not read $ref — skipping" >&2
    return 1
  fi
  echo "$val"
}

# --- Determine Supabase URL and key ---

if [[ "$SUPABASE_STRATEGY" == "3" ]]; then
  SUPABASE_URL=$(op_read "op://$PROJECT/Supabase Cloud/url") || true
  SUPABASE_KEY=$(op_read "op://$PROJECT/Supabase Cloud/publishable_key") || true
else
  SUPABASE_URL="https://${PROJECT}.db.${DOMAIN}"
  SUPABASE_KEY=$(op_read "op://$PROJECT/Supabase/anon_key") || true
fi

echo "Supabase URL: $SUPABASE_URL"
echo ""

# --- GitHub Actions secrets ---

echo "Pushing to GitHub Actions secrets..."

push_gh_secret() {
  local name="$1" value="$2"
  if [[ -n "$value" ]]; then
    gh secret set "$name" -R "$REPO" --body "$value"
    echo "  $name"
  fi
}

push_gh_var() {
  local name="$1" value="$2"
  if [[ -n "$value" ]]; then
    gh variable set "$name" -R "$REPO" --body "$value"
    echo "  $name (variable)"
  fi
}

# Always: deployment tokens
push_gh_secret "VERCEL_TOKEN" "$(op_read "op://$PROJECT/Vercel/token" || true)"
push_gh_secret "EXPO_TOKEN" "$(op_read "op://$PROJECT/Expo/token" || true)"

# Always: Supabase connection for CI builds
push_gh_secret "SUPABASE_URL" "${SUPABASE_URL:-}"
push_gh_secret "SUPABASE_PUBLISHABLE_KEY" "${SUPABASE_KEY:-}"

# Path A: full Azure + Supabase secrets for tofu apply
if [[ "$SUPABASE_STRATEGY" == "1" ]]; then
  PROJECT_UPPER=$(echo "$PROJECT" | tr '[:lower:]' '[:upper:]' | tr '-' '_')

  push_gh_secret "TF_VAR_${PROJECT_UPPER}_JWT_SECRET" \
    "$(op_read "op://$PROJECT/Supabase/jwt_secret" || true)"
  push_gh_secret "TF_VAR_${PROJECT_UPPER}_POSTGRES_PASSWORD" \
    "$(op_read "op://$PROJECT/Supabase/postgres_password" || true)"
  push_gh_secret "TF_VAR_${PROJECT_UPPER}_ANON_KEY" \
    "$(op_read "op://$PROJECT/Supabase/anon_key" || true)"
  push_gh_secret "TF_VAR_${PROJECT_UPPER}_SERVICE_ROLE_KEY" \
    "$(op_read "op://$PROJECT/Supabase/service_role_key" || true)"
  push_gh_secret "TF_VAR_RESEND_API_KEY" \
    "$(op_read "op://$PROJECT/Resend/api_key" || true)"
  push_gh_secret "TF_VAR_VM_SSH_PUBLIC_KEY" \
    "$(op_read "op://$PROJECT/VM SSH Key/public_key" || true)"

  # Azure IDs as variables (non-secret)
  push_gh_var "AZURE_CLIENT_ID" "$(op_read "op://$PROJECT/Azure/client_id" || true)"
  push_gh_var "AZURE_TENANT_ID" "$(op_read "op://$PROJECT/Azure/tenant_id" || true)"
  push_gh_var "AZURE_SUBSCRIPTION_ID" "$(op_read "op://$PROJECT/Azure/subscription_id" || true)"
fi

# Vercel IDs (all paths that use Vercel)
VERCEL_ORG=$(op_read "op://$PROJECT/Vercel/org_id" 2>/dev/null || true)
VERCEL_PROJ=$(op_read "op://$PROJECT/Vercel/project_id" 2>/dev/null || true)
[[ -n "$VERCEL_ORG" ]] && push_gh_var "VERCEL_ORG_ID" "$VERCEL_ORG"
[[ -n "$VERCEL_PROJ" ]] && push_gh_var "VERCEL_PROJECT_ID" "$VERCEL_PROJ"

echo ""

# --- Vercel env vars ---

echo "Pushing to Vercel environment variables..."

push_vercel_env() {
  local name="$1" value="$2" env="${3:-production}"
  if [[ -n "$value" ]]; then
    # Remove existing to avoid duplicates, then add
    vercel env rm "$name" "$env" -y 2>/dev/null || true
    echo "$value" | vercel env add "$name" "$env" 2>/dev/null
    echo "  $name ($env)"
  fi
}

push_vercel_env "VITE_SUPABASE_URL" "${SUPABASE_URL:-}"
push_vercel_env "VITE_SUPABASE_PUBLISHABLE_KEY" "${SUPABASE_KEY:-}"

# Observability
NR_ACCOUNT=$(op_read "op://$PROJECT/New Relic/account_id" 2>/dev/null || true)
NR_APP=$(op_read "op://$PROJECT/New Relic/browser_app_id" 2>/dev/null || true)
NR_LICENSE=$(op_read "op://$PROJECT/New Relic/browser_license_key" 2>/dev/null || true)
PH_KEY=$(op_read "op://$PROJECT/PostHog/api_key" 2>/dev/null || true)

[[ -n "$NR_ACCOUNT" ]] && push_vercel_env "VITE_NEW_RELIC_ACCOUNT_ID" "$NR_ACCOUNT"
[[ -n "$NR_APP" ]] && push_vercel_env "VITE_NEW_RELIC_APP_ID" "$NR_APP"
[[ -n "$NR_LICENSE" ]] && push_vercel_env "VITE_NEW_RELIC_LICENSE_KEY" "$NR_LICENSE"
[[ -n "$PH_KEY" ]] && push_vercel_env "VITE_POSTHOG_KEY" "$PH_KEY"
push_vercel_env "VITE_POSTHOG_HOST" "https://app.posthog.com"

echo ""

# --- EAS secrets ---

echo "Pushing to EAS environment variables..."

push_eas_env() {
  local name="$1" value="$2" visibility="${3:-secret}"
  if [[ -n "$value" ]]; then
    # eas env:create fails if it already exists; delete first
    eas env:delete --name "$name" --environment production -y 2>/dev/null || true
    eas env:create --name "$name" --value "$value" \
      --visibility "$visibility" --environment production 2>/dev/null
    echo "  $name"
  fi
}

push_eas_env "EXPO_PUBLIC_SUPABASE_URL" "${SUPABASE_URL:-}" "plaintext"
push_eas_env "EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY" "${SUPABASE_KEY:-}" "secret"

NR_MOBILE=$(op_read "op://$PROJECT/New Relic/mobile_app_token" 2>/dev/null || true)
[[ -n "$NR_MOBILE" ]] && push_eas_env "EXPO_PUBLIC_NEW_RELIC_APP_TOKEN" "$NR_MOBILE" "secret"
[[ -n "$PH_KEY" ]] && push_eas_env "EXPO_PUBLIC_POSTHOG_KEY" "$PH_KEY" "secret"
push_eas_env "EXPO_PUBLIC_POSTHOG_HOST" "https://app.posthog.com" "plaintext"

echo ""

# --- Generate project-specific op inject templates ---

BLUEPRINT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATES_DIR="$BLUEPRINT_DIR/templates"

echo "Generating project-specific op inject templates..."

if [[ ! -f "$TEMPLATES_DIR/.env.local.tpl" ]]; then
  echo "ERROR: $TEMPLATES_DIR/.env.local.tpl not found — blueprint is incomplete." >&2
  exit 1
fi
sed "s/VAULT_PLACEHOLDER/$PROJECT/g; s|SUPABASE_URL_PLACEHOLDER|$SUPABASE_URL|g" \
  "$TEMPLATES_DIR/.env.local.tpl" > .env.local.tpl
echo "  .env.local.tpl (run: op inject -i .env.local.tpl -o .env.local)"

if [[ "$SUPABASE_STRATEGY" == "1" ]]; then
  if [[ ! -f "$TEMPLATES_DIR/secrets.tfvars.tpl" ]]; then
    echo "ERROR: $TEMPLATES_DIR/secrets.tfvars.tpl not found — blueprint is incomplete." >&2
    exit 1
  fi
  mkdir -p infra/tofu
  sed "s/VAULT_PLACEHOLDER/$PROJECT/g" "$TEMPLATES_DIR/secrets.tfvars.tpl" > infra/tofu/secrets.tfvars.tpl
  echo "  infra/tofu/secrets.tfvars.tpl (run: op inject -i infra/tofu/secrets.tfvars.tpl -o infra/tofu/secrets.tfvars)"
fi

echo ""
echo "Phase 5 complete. All secrets pushed to GitHub, Vercel, and EAS."
