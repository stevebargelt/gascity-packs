#!/bin/bash
set -euo pipefail

# web-mobile bootstrap — single entry point for provisioning a new project.
#
# Usage:
#   ./bootstrap.sh                    # interactive, full wizard
#   ./bootstrap.sh --from-phase 3     # resume from phase 3
#   BEAD_ID=co-xyz ./bootstrap.sh     # reads architect spec from TDD
#
# This script runs phases in sequence, skipping phases that don't apply
# to the selected Supabase strategy (new / existing / cloud).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts"
CONFIG_FILE=".bootstrap-config"
START_PHASE=0

# --- Parse arguments ---

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from-phase)
      START_PHASE="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: bootstrap.sh [--from-phase N]"
      echo ""
      echo "Phases:"
      echo "  0  Check prerequisites (CLI tools + auth)"
      echo "  1  Project configuration (name, strategy, OAuth)"
      echo "  2  Generate secrets → 1Password"
      echo "  3  Collect SaaS API keys (guided wizard)"
      echo "  4  Azure infrastructure bootstrap (Path A only)"
      echo "  5  Push secrets → GitHub, Vercel, EAS"
      echo "  6  Add project to existing VM (Path B only)"
      echo ""
      echo "Environment variables:"
      echo "  BEAD_ID    Bead ID to look up architect bootstrap spec in TDD"
      echo ""
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
done

# --- Banner ---

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║   web-mobile bootstrap                      ║"
echo "║   Gasworks project provisioning wizard       ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# --- Run phases ---

run_phase() {
  local num="$1" script="$2" description="$3"
  if [[ "$num" -lt "$START_PHASE" ]]; then
    echo "--- Phase $num: $description (skipped, --from-phase $START_PHASE) ---"
    echo ""
    return
  fi
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  bash "$SCRIPT_DIR/$script"
  echo ""
}

# Phase 0: Prerequisites
run_phase 0 "00-check-prereqs.sh" "Prerequisites"

# Phase 1: Init / configuration
run_phase 1 "01-init.sh" "Project Configuration"

# Phases 2-6 need the config file
if [[ "$START_PHASE" -le 1 && ! -f "$CONFIG_FILE" ]]; then
  echo "ERROR: Phase 1 did not produce $CONFIG_FILE."
  exit 1
fi

if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
fi

# Phase 2: Generate secrets
run_phase 2 "02-generate-secrets.sh" "Secret Generation"

# Phase 3: Collect SaaS keys
run_phase 3 "03-collect-saas-keys.sh" "SaaS Key Collection"

# Phase 4: Azure bootstrap (Path A only)
run_phase 4 "04-azure-bootstrap.sh" "Azure Infrastructure"

# Phase 5: Push secrets everywhere
run_phase 5 "05-push-secrets.sh" "Push Secrets"

# Phase 6: Add to existing VM (Path B only)
run_phase 6 "06-add-to-existing-vm.sh" "VM Configuration"

# --- Summary ---

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Bootstrap complete!"
echo ""
echo "  Project:    $PROJECT"
echo "  Vault:      op://$PROJECT/"
echo "  Repo:       https://github.com/$REPO"

if [[ "$SUPABASE_STRATEGY" == "1" || "$SUPABASE_STRATEGY" == "2" ]]; then
  echo "  Supabase:   https://${PROJECT}.db.${DOMAIN}"
  echo "  Studio:     https://studio.${PROJECT}.db.${DOMAIN}"
elif [[ "$SUPABASE_STRATEGY" == "3" ]]; then
  echo "  Supabase:   $(op read "op://$PROJECT/Supabase Cloud/url" 2>/dev/null || echo '(check 1Password)')"
fi

echo ""
echo "Next steps:"
echo "  1. Local dev:    op inject -i .env.local.tpl -o .env.local && supabase start"
echo "  2. Migrations:   supabase db push"
echo "  3. Smoke test:   Sign up, sign in, verify OAuth + realtime"
echo ""

# Clean up local config (secrets are in 1Password now)
if [[ -f "$CONFIG_FILE" ]]; then
  read -p "Delete local $CONFIG_FILE? (secrets are safely in 1Password) [Y/n] " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    rm "$CONFIG_FILE"
    echo "  Cleaned up."
  fi
fi
