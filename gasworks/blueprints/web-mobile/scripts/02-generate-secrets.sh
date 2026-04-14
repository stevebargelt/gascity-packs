#!/bin/bash
set -euo pipefail

# Phase 2: Generate secrets and store in 1Password.
# Skipped for Path C (Supabase Cloud).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE=".bootstrap-config"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "ERROR: $CONFIG_FILE not found. Run 01-init.sh first."
  exit 1
fi
source "$CONFIG_FILE"

echo "=== Phase 2: Secret Generation ==="
echo ""

if [[ "$SUPABASE_STRATEGY" == "3" ]]; then
  echo "Supabase Cloud selected — skipping secret generation."
  echo "You'll provide your cloud URL and keys in the next phase."
  echo ""
  echo "Phase 2 skipped."
  exit 0
fi

# --- Generate Supabase secrets ---

echo "Generating Supabase secrets..."

JWT_SECRET=$(openssl rand -hex 32)
POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d '\n')
DASHBOARD_PASSWORD=$(openssl rand -base64 32 | tr -d '\n')

echo "Generating Supabase JWTs..."
ANON_KEY=$(node "$SCRIPT_DIR/generate-jwt.mjs" "$JWT_SECRET" anon)
SERVICE_ROLE_KEY=$(node "$SCRIPT_DIR/generate-jwt.mjs" "$JWT_SECRET" service_role)

# Store in 1Password
if op item get "Supabase" --vault "$PROJECT" &>/dev/null 2>&1; then
  op item edit "Supabase" --vault "$PROJECT" \
    "jwt_secret=$JWT_SECRET" \
    "postgres_password=$POSTGRES_PASSWORD" \
    "dashboard_password=$DASHBOARD_PASSWORD" \
    "anon_key=$ANON_KEY" \
    "service_role_key=$SERVICE_ROLE_KEY" \
    >/dev/null
else
  op item create --vault "$PROJECT" --category "Login" \
    --title "Supabase" \
    "jwt_secret=$JWT_SECRET" \
    "postgres_password=$POSTGRES_PASSWORD" \
    "dashboard_password=$DASHBOARD_PASSWORD" \
    "anon_key=$ANON_KEY" \
    "service_role_key=$SERVICE_ROLE_KEY" \
    >/dev/null
fi
echo "  Supabase secrets stored in 1Password."

# --- Generate SSH key (Path A only) ---

if [[ "$SUPABASE_STRATEGY" == "1" ]]; then
  echo "Generating SSH key pair..."
  TMPKEY=$(mktemp -d)/ssh-key
  ssh-keygen -t ed25519 -f "$TMPKEY" -N "" -C "${PROJECT}-vm" >/dev/null 2>&1

  if op item get "VM SSH Key" --vault "$PROJECT" &>/dev/null 2>&1; then
    op item edit "VM SSH Key" --vault "$PROJECT" \
      "private_key=$(cat "$TMPKEY")" \
      "public_key=$(cat "${TMPKEY}.pub")" \
      >/dev/null
  else
    op item create --vault "$PROJECT" --category "Secure Note" \
      --title "VM SSH Key" \
      "private_key=$(cat "$TMPKEY")" \
      "public_key=$(cat "${TMPKEY}.pub")" \
      >/dev/null
  fi

  rm -rf "$(dirname "$TMPKEY")"
  echo "  SSH key generated and stored in 1Password."
  echo "  (Retrieve later: op read 'op://$PROJECT/VM SSH Key/public_key')"
else
  echo "  Reusing existing VM SSH key (Path B)."
fi

echo ""
echo "Phase 2 complete. Secrets stored in 1Password vault '$PROJECT'."
