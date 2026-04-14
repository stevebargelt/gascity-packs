#!/bin/bash
set -euo pipefail

# Phase 0: Verify all required CLI tools are installed and authenticated.

REQUIRED_TOOLS=(op gh az supabase node jq openssl vercel eas)
OPTIONAL_TOOLS=(gcloud)
MISSING=()
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Phase 0: Prerequisites ==="
echo ""

# --- Check required tools ---

for tool in "${REQUIRED_TOOLS[@]}"; do
  if command -v "$tool" &>/dev/null; then
    VERSION=$("$tool" --version 2>/dev/null | head -1 || echo "installed")
    echo "  $tool: $VERSION"
  else
    MISSING+=("$tool")
    echo "  $tool: MISSING"
  fi
done

echo ""

if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "Missing required tools: ${MISSING[*]}"
  echo ""
  echo "Install commands:"
  echo ""
  for tool in "${MISSING[@]}"; do
    case "$tool" in
      op)       echo "  brew install 1password-cli" ;;
      gh)       echo "  brew install gh" ;;
      az)       echo "  brew install azure-cli" ;;
      supabase) echo "  brew install supabase/tap/supabase" ;;
      node)     echo "  brew install node  # or use nvm" ;;
      jq)       echo "  brew install jq" ;;
      openssl)  echo "  brew install openssl" ;;
      vercel)   echo "  brew install vercel-cli" ;;
      eas)      echo "  npm install -g eas-cli" ;;
    esac
  done
  echo ""
  read -p "Install all missing tools now? [y/N] " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    for tool in "${MISSING[@]}"; do
      echo "Installing $tool..."
      case "$tool" in
        op)       brew install 1password-cli ;;
        gh)       brew install gh ;;
        az)       brew install azure-cli ;;
        supabase) brew install supabase/tap/supabase ;;
        node)     brew install node ;;
        jq)       brew install jq ;;
        openssl)  brew install openssl ;;
        vercel)   brew install vercel-cli ;;
        eas)      npm install -g eas-cli ;;
      esac
    done
    echo ""
    echo "All tools installed."
  else
    echo "Cannot continue without required tools."
    exit 1
  fi
fi

# --- Check optional tools ---

echo "Optional tools:"
for tool in "${OPTIONAL_TOOLS[@]}"; do
  if command -v "$tool" &>/dev/null; then
    echo "  $tool: installed"
  else
    case "$tool" in
      gcloud) echo "  $tool: not installed (needed only for Google OAuth)" ;;
    esac
  fi
done

# --- Check authentication ---

echo ""
echo "Authentication status:"

AUTHED=true

if op account list &>/dev/null 2>&1; then
  echo "  1Password: signed in"
else
  echo "  1Password: NOT signed in — run 'eval \$(op signin)'"
  AUTHED=false
fi

if gh auth status &>/dev/null 2>&1; then
  echo "  GitHub: authenticated"
else
  echo "  GitHub: NOT authenticated — run 'gh auth login'"
  AUTHED=false
fi

if az account show &>/dev/null 2>&1; then
  echo "  Azure: authenticated"
else
  echo "  Azure: NOT authenticated — run 'az login'"
  AUTHED=false
fi

echo ""

if [[ "$AUTHED" == "false" ]]; then
  echo "Some tools need authentication. Fix the above and re-run."
  exit 1
fi

# --- Verify generate-jwt.mjs works ---

TEST_JWT=$(node "$SCRIPT_DIR/generate-jwt.mjs" "test-secret-not-real" anon 2>/dev/null || true)
if [[ -z "$TEST_JWT" || "$TEST_JWT" != *"."*"."* ]]; then
  echo "ERROR: generate-jwt.mjs failed. Check Node.js installation."
  exit 1
fi

echo "All prerequisites met. Ready to bootstrap."
