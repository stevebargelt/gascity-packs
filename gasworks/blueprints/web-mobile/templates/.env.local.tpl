# ============================================================
# Local Development — Supabase CLI (default)
# Get these values from `supabase status` after `supabase start`
# ============================================================
VITE_SUPABASE_URL=http://127.0.0.1:54321
VITE_SUPABASE_PUBLISHABLE_KEY=
EXPO_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321
EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY=

# Service role key — required for pnpm seed (sb_secret_xxx from `supabase status`)
SUPABASE_SERVICE_ROLE_KEY=

# ============================================================
# Remote Self-Hosted Supabase (SUPABASE_URL_PLACEHOLDER)
# Uncomment when pointing at the remote instance
# ============================================================
# VITE_SUPABASE_URL=SUPABASE_URL_PLACEHOLDER
# VITE_SUPABASE_PUBLISHABLE_KEY={{ op://VAULT_PLACEHOLDER/Supabase/anon_key }}
# EXPO_PUBLIC_SUPABASE_URL=SUPABASE_URL_PLACEHOLDER
# EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY={{ op://VAULT_PLACEHOLDER/Supabase/anon_key }}
# SUPABASE_SERVICE_ROLE_KEY={{ op://VAULT_PLACEHOLDER/Supabase/service_role_key }}

# ============================================================
# Observability — New Relic + PostHog
# ============================================================
VITE_NEW_RELIC_ACCOUNT_ID={{ op://VAULT_PLACEHOLDER/New Relic/account_id }}
VITE_NEW_RELIC_APP_ID={{ op://VAULT_PLACEHOLDER/New Relic/browser_app_id }}
VITE_NEW_RELIC_LICENSE_KEY={{ op://VAULT_PLACEHOLDER/New Relic/browser_license_key }}
VITE_POSTHOG_KEY={{ op://VAULT_PLACEHOLDER/PostHog/api_key }}
VITE_POSTHOG_HOST=https://app.posthog.com
EXPO_PUBLIC_NEW_RELIC_APP_TOKEN={{ op://VAULT_PLACEHOLDER/New Relic/mobile_app_token }}
EXPO_PUBLIC_POSTHOG_KEY={{ op://VAULT_PLACEHOLDER/PostHog/api_key }}
EXPO_PUBLIC_POSTHOG_HOST=https://app.posthog.com
