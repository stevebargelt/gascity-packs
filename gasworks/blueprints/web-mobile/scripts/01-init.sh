#!/bin/bash
set -euo pipefail

# Phase 1: Project naming, Supabase strategy, OAuth selection, create 1Password vault.
# Outputs a config file at .bootstrap-config that subsequent phases read.

CONFIG_FILE=".bootstrap-config"

echo "=== Phase 1: Project Configuration ==="
echo ""

# --- Check for architect bootstrap spec ---

SPEC_FILE=""
if [[ -n "${BEAD_ID:-}" ]]; then
  for candidate in "docs/architecture/${BEAD_ID}.md" "docs/architecture/${BEAD_ID}-tdd.md"; do
    if [[ -f "$candidate" ]] && grep -q "^## Bootstrap" "$candidate"; then
      SPEC_FILE="$candidate"
      break
    fi
  done
fi

if [[ -n "$SPEC_FILE" ]]; then
  echo "Found bootstrap spec from architect in $SPEC_FILE"
  echo ""

  # Extract values (simple grep-based parsing for YAML-like blocks)
  parse_spec() { grep "^${1}:" "$SPEC_FILE" | head -1 | sed "s/^${1}: *//; s/ *#.*//"; }

  SPEC_STRATEGY=$(parse_spec "supabase_strategy" || true)
  SPEC_OAUTH=$(parse_spec "oauth_providers" || true)
  SPEC_OBSERVABILITY=$(parse_spec "observability" || true)
  SPEC_VM_IP=$(parse_spec "existing_vm" || true)
  SPEC_KV_NAME=$(parse_spec "existing_keyvault" || true)

  echo "Architect specified:"
  [[ -n "$SPEC_STRATEGY" ]] && echo "  Supabase strategy: $SPEC_STRATEGY"
  [[ -n "$SPEC_OAUTH" ]] && echo "  OAuth providers:   $SPEC_OAUTH"
  [[ -n "$SPEC_OBSERVABILITY" ]] && echo "  Observability:     $SPEC_OBSERVABILITY"
  [[ -n "$SPEC_VM_IP" ]] && echo "  Existing VM:       $SPEC_VM_IP"
  echo ""
  read -p "Accept these settings? [Y/n] " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "Entering manual wizard mode..."
    SPEC_FILE=""
  fi
fi

# --- Project name ---

read -p "Project name (lowercase, no spaces, e.g. 'constellation'): " PROJECT
if [[ ! "$PROJECT" =~ ^[a-z][a-z0-9-]*$ ]]; then
  echo "ERROR: Project name must be lowercase alphanumeric with hyphens only."
  exit 1
fi

read -p "GitHub org/repo (e.g. 'stevebargelt/constellation'): " REPO

# Check if repo exists; offer to create it if not
if gh repo view "$REPO" &>/dev/null 2>&1; then
  echo "  GitHub repo $REPO found."
else
  echo "  GitHub repo $REPO does not exist."
  read -p "  Create it now as a private repo? [Y/n] " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    gh repo create "$REPO" --private
    echo "  Repo created."
  else
    echo "  WARNING: Phase 5 will fail if the repo doesn't exist when secrets are pushed."
  fi
fi

read -p "Domain base (e.g. 'harebrained-apps.com'): " DOMAIN

# --- Supabase strategy ---

if [[ -n "$SPEC_FILE" && -n "${SPEC_STRATEGY:-}" ]]; then
  case "$SPEC_STRATEGY" in
    new)      SUPABASE_STRATEGY=1 ;;
    existing) SUPABASE_STRATEGY=2 ;;
    cloud)    SUPABASE_STRATEGY=3 ;;
    *)
      echo "Unknown strategy in spec: $SPEC_STRATEGY"
      SPEC_FILE=""
      ;;
  esac
fi

if [[ -z "${SUPABASE_STRATEGY:-}" ]]; then
  echo ""
  echo "How will this project connect to Supabase?"
  echo ""
  echo "  1) New self-hosted instance"
  echo "     Full Azure VM + Docker stack. Best for: production apps that"
  echo "     need full control. Adds ~\$40-80/mo Azure cost."
  echo ""
  echo "  2) Existing self-hosted instance"
  echo "     Add a new Supabase stack to a running VM. Shared Postgres server,"
  echo "     new subdomain, isolated containers."
  echo ""
  echo "  3) Supabase Cloud"
  echo "     Hosted at supabase.com. No infrastructure to manage."
  echo "     Best for: quick prototypes (2 free project limit)."
  echo ""
  read -p "Choice [1/2/3]: " SUPABASE_STRATEGY
fi

# --- Path B details ---

VM_IP=""
KV_NAME=""
SSH_KEY_PATH=""
PORT_INDEX=""

if [[ "$SUPABASE_STRATEGY" == "2" ]]; then
  VM_IP="${SPEC_VM_IP:-}"
  KV_NAME="${SPEC_KV_NAME:-}"

  [[ -z "$VM_IP" ]] && read -p "VM IP address of existing instance: " VM_IP
  # Default to the existing shared vault on this VM, not a new project-named one
  DEFAULT_KV="kv-constellation"
  [[ -z "$KV_NAME" ]] && read -p "Key Vault name [$DEFAULT_KV]: " KV_NAME
  KV_NAME="${KV_NAME:-$DEFAULT_KV}"
  read -p "SSH key path [~/.ssh/id_rsa_azure]: " SSH_KEY_PATH
  SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/id_rsa_azure}"

  echo ""
  echo "Verifying VM connectivity..."
  if ssh -i "$SSH_KEY_PATH" -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new \
    "azureuser@$VM_IP" echo "connected" 2>/dev/null; then
    echo "  VM reachable."
  else
    echo "  WARNING: Cannot reach VM at $VM_IP. Continuing anyway (may be a firewall rule)."
  fi

  # Auto-detect port index
  PORT_INDEX=$(ssh -i "$SSH_KEY_PATH" "azureuser@$VM_IP" \
    "ls -d /opt/supabase-*/ 2>/dev/null | wc -l" 2>/dev/null || echo "0")
  PORT_INDEX=$(echo "$PORT_INDEX" | tr -d '[:space:]')
  echo "  Detected $PORT_INDEX existing project(s). New project gets:"
  echo "    Kong port:   $((8000 + PORT_INDEX * 100))"
  echo "    Studio port: $((3000 + PORT_INDEX * 100))"
fi

# --- OAuth provider selection ---

if [[ -n "$SPEC_FILE" && -n "${SPEC_OAUTH:-}" ]]; then
  # Normalize from YAML array format: [github, google] → "github google"
  OAUTH_PROVIDERS=$(echo "$SPEC_OAUTH" | tr -d '[],' | xargs)
else
  echo ""
  echo "Which OAuth provider(s) do you want to enable?"
  echo "(space-separated, or 'none')"
  echo ""
  echo "  google   — Google Sign-In (requires Google Cloud project)"
  echo "  github   — GitHub Sign-In (requires GitHub OAuth App)"
  echo "  apple    — Apple Sign-In (requires Apple Developer account)"
  echo "  none     — Email/password only"
  echo ""
  read -p "Providers [none]: " OAUTH_PROVIDERS
  OAUTH_PROVIDERS="${OAUTH_PROVIDERS:-none}"
fi

# --- Observability ---

if [[ -n "$SPEC_FILE" && -n "${SPEC_OBSERVABILITY:-}" ]]; then
  OBSERVABILITY="$SPEC_OBSERVABILITY"
else
  if [[ "$SUPABASE_STRATEGY" == "2" ]]; then
    echo ""
    echo "Observability setup:"
    echo "  1) shared    — Reuse New Relic + PostHog from the existing project"
    echo "  2) dedicated — Set up new New Relic + PostHog for this project"
    echo ""
    read -p "Choice [shared]: " OBSERVABILITY
    OBSERVABILITY="${OBSERVABILITY:-shared}"
  else
    OBSERVABILITY="dedicated"
  fi
fi

# --- Create 1Password vault ---

echo ""
echo "Creating 1Password vault '$PROJECT'..."
if op vault get "$PROJECT" &>/dev/null 2>&1; then
  echo "  Vault already exists. Using existing vault."
else
  op vault create "$PROJECT" --description "Bootstrap secrets for $PROJECT"
  echo "  Vault created."
fi

# --- Store config in 1Password ---

op item create --vault "$PROJECT" --category "Secure Note" \
  --title "Bootstrap Config" \
  "project_name=$PROJECT" \
  "github_repo=$REPO" \
  "domain=$DOMAIN" \
  "supabase_strategy=$SUPABASE_STRATEGY" \
  "oauth_providers=$OAUTH_PROVIDERS" \
  "observability=$OBSERVABILITY" \
  ${VM_IP:+"vm_ip=$VM_IP"} \
  ${KV_NAME:+"keyvault_name=$KV_NAME"} \
  ${SSH_KEY_PATH:+"ssh_key_path=$SSH_KEY_PATH"} \
  ${PORT_INDEX:+"port_index=$PORT_INDEX"} \
  >/dev/null

# --- Also write a local config file for subsequent phases ---
# (Avoids repeated op reads during the same bootstrap session)

cat > "$CONFIG_FILE" <<EOF
PROJECT=$PROJECT
REPO=$REPO
DOMAIN=$DOMAIN
SUPABASE_STRATEGY=$SUPABASE_STRATEGY
OAUTH_PROVIDERS="$OAUTH_PROVIDERS"
OBSERVABILITY=$OBSERVABILITY
VM_IP=$VM_IP
KV_NAME=$KV_NAME
SSH_KEY_PATH=$SSH_KEY_PATH
PORT_INDEX=$PORT_INDEX
EOF

echo ""
echo "Configuration saved. Summary:"
echo "  Project:          $PROJECT"
echo "  Repo:             $REPO"
echo "  Domain:           $DOMAIN"
case "$SUPABASE_STRATEGY" in
  1) STRATEGY_LABEL="new self-hosted" ;;
  2) STRATEGY_LABEL="existing VM" ;;
  3) STRATEGY_LABEL="cloud" ;;
  *) STRATEGY_LABEL="unknown" ;;
esac
echo "  Supabase:         $STRATEGY_LABEL"
echo "  OAuth:            $OAUTH_PROVIDERS"
echo "  Observability:    $OBSERVABILITY"
[[ -n "$VM_IP" ]] && echo "  VM:               $VM_IP (port index $PORT_INDEX)"
echo ""
echo "Phase 1 complete."
