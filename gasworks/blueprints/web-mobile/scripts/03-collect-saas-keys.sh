#!/bin/bash
set -euo pipefail

# Phase 3: Guided wizard to collect SaaS API keys from the human.
# Opens browser to the correct URL, prompts for the value, stores in 1Password.

CONFIG_FILE=".bootstrap-config"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "ERROR: $CONFIG_FILE not found. Run 01-init.sh first."
  exit 1
fi
source "$CONFIG_FILE"

echo "=== Phase 3: SaaS Key Collection ==="
echo ""
echo "This phase will open browser tabs and prompt you to paste API keys."
echo "Values are stored directly in 1Password — never in shell history."
echo ""

# --- Helper: collect a key and store in 1Password ---

collect_key() {
  local title="$1" url="$2" field="$3" instructions="$4"
  echo "--- $title ---"
  echo "$instructions"
  echo ""
  read -p "Open $url in browser? [Y/n] " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    open "$url" 2>/dev/null || xdg-open "$url" 2>/dev/null || echo "  (open manually: $url)"
  fi
  echo ""
  read -sp "Paste the value here (hidden): " VALUE
  echo ""

  if [[ -z "$VALUE" ]]; then
    echo "  WARNING: Empty value. Skipping."
    return
  fi

  if op item get "$title" --vault "$PROJECT" &>/dev/null 2>&1; then
    op item edit "$title" --vault "$PROJECT" "$field=$VALUE" >/dev/null
  else
    op item create --vault "$PROJECT" --category "API Credential" \
      --title "$title" "$field=$VALUE" >/dev/null
  fi
  echo "  Stored in 1Password."
  echo ""
}

# --- Always collected (all paths) ---

collect_key "Vercel" \
  "https://vercel.com/account/tokens" \
  "token" \
  "Create a new token named '${PROJECT}-github-actions' with full access scope."

collect_key "Expo" \
  "https://expo.dev/settings/access-tokens" \
  "token" \
  "Create a Robot User named '${PROJECT}-ci' (role: Developer), then create an access token for it."

# --- OAuth providers (conditional) ---

if [[ "$OAUTH_PROVIDERS" == *"google"* ]]; then
  echo "--- Google OAuth ---"
  echo "Create or select an OAuth 2.0 client in Google Cloud Console."
  echo "Add authorized redirect URI: https://${PROJECT}.db.${DOMAIN}/auth/v1/callback"
  echo ""
  collect_key "Google OAuth" \
    "https://console.cloud.google.com/apis/credentials" \
    "client_id" \
    "Copy the Client ID."

  read -sp "Now paste the Google OAuth Client Secret (hidden): " GSECRET
  echo ""
  op item edit "Google OAuth" --vault "$PROJECT" "client_secret=$GSECRET" >/dev/null
  echo "  Client Secret stored."
  echo ""
fi

if [[ "$OAUTH_PROVIDERS" == *"github"* ]]; then
  echo "--- GitHub OAuth ---"
  echo ""
  read -p "Create GitHub OAuth App automatically via CLI? [Y/n] " -n 1 -r
  echo ""

  if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    CALLBACK_URL="https://${PROJECT}.db.${DOMAIN}/auth/v1/callback"
    echo "Creating GitHub OAuth App '${PROJECT}'..."
    echo "  Callback URL: $CALLBACK_URL"

    # gh api for OAuth app creation
    RESPONSE=$(gh api -X POST user/applications \
      -f "name=${PROJECT}" \
      -f "url=https://${PROJECT}.${DOMAIN}" \
      -f "callback_url=${CALLBACK_URL}" \
      2>/dev/null || true)

    if [[ -n "$RESPONSE" ]]; then
      GH_CLIENT_ID=$(echo "$RESPONSE" | jq -r '.client_id // empty')
      GH_CLIENT_SECRET=$(echo "$RESPONSE" | jq -r '.client_secret // empty')

      if [[ -n "$GH_CLIENT_ID" && -n "$GH_CLIENT_SECRET" ]]; then
        op item create --vault "$PROJECT" --category "API Credential" \
          --title "GitHub OAuth" \
          "client_id=$GH_CLIENT_ID" \
          "client_secret=$GH_CLIENT_SECRET" >/dev/null
        echo "  GitHub OAuth App created and stored in 1Password."
      else
        echo "  WARNING: Could not parse response. Falling back to manual."
        collect_key "GitHub OAuth" \
          "https://github.com/settings/developers" \
          "client_id" \
          "Create a new OAuth App. Callback URL: $CALLBACK_URL"
        read -sp "GitHub OAuth Client Secret (hidden): " GH_SECRET
        echo ""
        op item edit "GitHub OAuth" --vault "$PROJECT" "client_secret=$GH_SECRET" >/dev/null
        echo "  Stored."
      fi
    else
      echo "  API call failed. Falling back to manual."
      collect_key "GitHub OAuth" \
        "https://github.com/settings/developers" \
        "client_id" \
        "Create a new OAuth App. Callback URL: https://${PROJECT}.db.${DOMAIN}/auth/v1/callback"
      read -sp "GitHub OAuth Client Secret (hidden): " GH_SECRET
      echo ""
      op item edit "GitHub OAuth" --vault "$PROJECT" "client_secret=$GH_SECRET" >/dev/null
      echo "  Stored."
    fi
    echo ""
  else
    collect_key "GitHub OAuth" \
      "https://github.com/settings/developers" \
      "client_id" \
      "Create a new OAuth App. Callback URL: https://${PROJECT}.db.${DOMAIN}/auth/v1/callback"
    read -sp "GitHub OAuth Client Secret (hidden): " GH_SECRET
    echo ""
    op item edit "GitHub OAuth" --vault "$PROJECT" "client_secret=$GH_SECRET" >/dev/null
    echo "  Stored."
    echo ""
  fi
fi

if [[ "$OAUTH_PROVIDERS" == *"apple"* ]]; then
  echo "--- Apple Sign-In ---"
  echo "Apple requires a Service ID, Team ID, Key ID, and private key (.p8 file)."
  echo "Add return URL: https://${PROJECT}.db.${DOMAIN}/auth/v1/callback"
  echo ""

  collect_key "Apple OAuth" \
    "https://developer.apple.com/account/resources/identifiers/list/serviceId" \
    "service_id" \
    "Create a Service ID. Enable 'Sign In with Apple'. Copy the identifier."

  read -sp "Team ID (10-char, top-right of developer portal): " APPLE_TEAM
  echo ""
  read -sp "Key ID (from the .p8 key you created): " APPLE_KEY_ID
  echo ""
  read -p "Path to .p8 private key file: " APPLE_KEY_FILE

  if [[ -f "$APPLE_KEY_FILE" ]]; then
    APPLE_PRIVATE_KEY=$(cat "$APPLE_KEY_FILE")
  else
    echo "  File not found. Paste the private key contents instead."
    read -sp "Private key (hidden): " APPLE_PRIVATE_KEY
    echo ""
  fi

  op item edit "Apple OAuth" --vault "$PROJECT" \
    "team_id=$APPLE_TEAM" \
    "key_id=$APPLE_KEY_ID" \
    "private_key=$APPLE_PRIVATE_KEY" >/dev/null
  echo "  All Apple Sign-In values stored."
  echo ""
fi

if [[ "$OAUTH_PROVIDERS" == "none" ]]; then
  echo "No OAuth providers selected — email/password auth only."
  echo ""
fi

# --- Observability keys (skip if shared) ---

if [[ "$OBSERVABILITY" == "shared" && "$SUPABASE_STRATEGY" == "2" ]]; then
  echo "--- Observability (shared) ---"
  echo "Copying observability keys from existing project's vault."
  read -p "Name of the existing project's 1Password vault: " EXISTING_VAULT

  for item in "Resend" "New Relic" "PostHog"; do
    if ! op item get "$item" --vault "$EXISTING_VAULT" &>/dev/null 2>&1; then
      echo "  WARNING: $item not found in $EXISTING_VAULT vault. Skipping."
      continue
    fi

    # Export from source vault
    ITEM_JSON=$(op item get "$item" --vault "$EXISTING_VAULT" --format json 2>&1)
    if [[ $? -ne 0 || -z "$ITEM_JSON" ]]; then
      echo "  WARNING: Failed to read $item from $EXISTING_VAULT. Add it manually later."
      continue
    fi

    # Strip vault/id metadata so it can be created fresh in the new vault
    CLEAN_JSON=$(echo "$ITEM_JSON" | jq 'del(.id, .vault, .created_at, .updated_at)' 2>&1)
    if [[ $? -ne 0 || -z "$CLEAN_JSON" ]]; then
      echo "  WARNING: Failed to process $item JSON (op CLI format may have changed). Add it manually:"
      echo "    op item get \"$item\" --vault \"$EXISTING_VAULT\" --format json | op item create --vault \"$PROJECT\" -"
      continue
    fi

    # Import into new vault
    if echo "$CLEAN_JSON" | op item create --vault "$PROJECT" - >/dev/null 2>&1; then
      echo "  Copied $item."
    else
      echo "  WARNING: Failed to create $item in $PROJECT vault. Add it manually:"
      echo "    op item get \"$item\" --vault \"$EXISTING_VAULT\" --format json | jq 'del(.id,.vault,.created_at,.updated_at)' | op item create --vault \"$PROJECT\" -"
    fi
  done
  echo ""
else
  # --- Resend ---

  collect_key "Resend" \
    "https://resend.com/api-keys" \
    "api_key" \
    "Create a new API key with 'Sending access' permission."

  # --- New Relic ---

  echo "--- New Relic ---"
  echo "You'll need 4 values from New Relic."
  echo ""
  collect_key "New Relic" \
    "https://one.newrelic.com/launcher/nr1-core.settings" \
    "account_id" \
    "Copy your Account ID from the account dropdown."

  read -sp "New Relic Browser License Key (NRJS-...): " NR_LICENSE
  echo ""
  op item edit "New Relic" --vault "$PROJECT" "browser_license_key=$NR_LICENSE" >/dev/null

  read -sp "New Relic Browser App ID: " NR_APP_ID
  echo ""
  op item edit "New Relic" --vault "$PROJECT" "browser_app_id=$NR_APP_ID" >/dev/null

  read -sp "New Relic iOS App Token (AA...-NRMA): " NR_MOBILE
  echo ""
  op item edit "New Relic" --vault "$PROJECT" "mobile_app_token=$NR_MOBILE" >/dev/null
  echo "  All New Relic values stored."
  echo ""

  # --- PostHog ---

  collect_key "PostHog" \
    "https://app.posthog.com/project/settings" \
    "api_key" \
    "Copy your Project API Key (phc_...)."
fi

# --- Supabase Cloud keys (Path C only) ---

if [[ "$SUPABASE_STRATEGY" == "3" ]]; then
  echo "--- Supabase Cloud ---"
  collect_key "Supabase Cloud" \
    "https://supabase.com/dashboard/project/_/settings/api" \
    "url" \
    "Copy your project URL (e.g. https://xyz.supabase.co)."

  read -sp "Supabase publishable key (eyJ...): " SB_KEY
  echo ""
  op item edit "Supabase Cloud" --vault "$PROJECT" "publishable_key=$SB_KEY" >/dev/null
  echo "  Stored."
  echo ""
fi

echo "Phase 3 complete. All SaaS keys stored in 1Password vault '$PROJECT'."
