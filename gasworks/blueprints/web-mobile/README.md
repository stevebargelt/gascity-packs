# web-mobile Blueprint

Automated provisioning for web + mobile app prototypes using the gasworks target stack (Expo, React Native, Supabase, Vercel, EAS).

## Quick Start

```bash
./bootstrap.sh
```

The wizard walks you through:
1. **Prerequisites** — checks/installs CLI tools, verifies auth
2. **Configuration** — project name, Supabase strategy, OAuth providers
3. **Secret generation** — JWT, Postgres, SSH keys stored in 1Password
4. **SaaS key collection** — opens browser, prompts for API keys
5. **Azure bootstrap** — resource group, OIDC, roles (new VM only)
6. **Push secrets** — 1Password to GitHub, Vercel, EAS in one shot
7. **VM setup** — Docker Compose, Caddy, DNS (existing VM only)

## Supabase Strategies

| Strategy | When to Use | Infra Cost |
|----------|------------|------------|
| **New self-hosted** | Production app, dedicated resources | ~$40-80/mo |
| **Existing VM** | Prototype sharing infrastructure | ~$0 marginal |
| **Supabase Cloud** | Quick experiment (2 free project limit) | $0 |

## Resume from a Phase

If the wizard fails mid-run, resume without re-doing earlier steps:

```bash
./bootstrap.sh --from-phase 3
```

## Architect Integration

If an architect TDD includes a `## Bootstrap` section, the wizard reads it:

```bash
BEAD_ID=co-xyz ./bootstrap.sh
```

## Prerequisites

Install everything at once:

```bash
brew install 1password-cli gh azure-cli supabase/tap/supabase jq node openssl vercel-cli
npm install -g eas-cli
```

## Templates

After bootstrap, generate local env files:

```bash
# Local development
op inject -i templates/.env.local.tpl -o .env.local

# OpenTofu secrets (if using Path A)
op inject -i templates/secrets.tfvars.tpl -o infra/tofu/secrets.tfvars
```
