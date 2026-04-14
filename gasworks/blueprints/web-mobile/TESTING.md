# web-mobile Blueprint — Manual Test Plan

Test the bootstrap scripts from the CLI before running through the full agent workflow.
Work through tests in order — each builds on the previous.

---

## Test 1 — JWT Generator (unit test, zero side effects)

```bash
SCRIPTS=~/emerald-city/packs/gasworks/blueprints/web-mobile/scripts
SECRET=$(openssl rand -hex 32)

# Generate both tokens
ANON=$(node $SCRIPTS/generate-jwt.mjs "$SECRET" anon)
SVC=$(node $SCRIPTS/generate-jwt.mjs "$SECRET" service_role)

echo "anon:         $ANON"
echo "service_role: $SVC"

# Decode the payload (middle segment) to verify claims
# Note: JWT uses base64url (no padding) — use Node to decode cleanly
node -e "console.log(JSON.stringify(JSON.parse(Buffer.from('$(echo $ANON | cut -d. -f2)', 'base64url').toString()), null, 2))"
node -e "console.log(JSON.stringify(JSON.parse(Buffer.from('$(echo $SVC  | cut -d. -f2)', 'base64url').toString()), null, 2))"
```

**Pass criteria:** Both JWTs decode cleanly. `role` is `anon`/`service_role`, `iss` is `supabase`, `exp` is ~10 years out.

---

## Test 2 — Prerequisites Check (read-only, no side effects)

```bash
bash ~/emerald-city/packs/gasworks/blueprints/web-mobile/scripts/00-check-prereqs.sh
```

**Pass criteria:** All required tools found, all three auth checks green (1Password, GitHub, Azure).

---

## Test 3 — Phase 1 Init, Path B (creates 1Password vault — reversible)

Run from a scratch directory so `.bootstrap-config` doesn't pollute anything:

```bash
mkdir -p /tmp/bootstrap-test && cd /tmp/bootstrap-test

bash ~/emerald-city/packs/gasworks/blueprints/web-mobile/scripts/01-init.sh
```

**Answers to use:**

| Prompt | Value |
|--------|-------|
| Project name | `test-bootstrap` |
| GitHub org/repo | `stevebargelt/test-bootstrap` |
| Domain | `harebrained-apps.com` |
| Supabase strategy | `2` (existing VM) |
| VM IP | `20.118.130.228` |
| Key Vault | `kv-constellation` (the shared vault on this VM — just press Enter to accept default) |
| SSH key | `~/.ssh/id_rsa_azure` |
| OAuth providers | `github` |
| Observability | `shared` |

**Pass criteria:** `.bootstrap-config` written, 1Password vault `test-bootstrap` created with a `Bootstrap Config` item.

Verify:
```bash
cat /tmp/bootstrap-test/.bootstrap-config
op item get "Bootstrap Config" --vault test-bootstrap --format json \
  | jq '.fields[] | {label, value}'
```

**Cleanup:**
```bash
op vault delete test-bootstrap
rm -rf /tmp/bootstrap-test
```

---

## Test 4 — Phase 2 Secret Generation (creates 1Password items — reversible)

```bash
mkdir -p /tmp/bootstrap-test && cd /tmp/bootstrap-test

cat > .bootstrap-config <<'EOF'
PROJECT=test-bootstrap
REPO=stevebargelt/test-bootstrap
DOMAIN=harebrained-apps.com
SUPABASE_STRATEGY=2
OAUTH_PROVIDERS="github"
OBSERVABILITY=shared
VM_IP=20.118.130.228
KV_NAME=kv-constellation
SSH_KEY_PATH=~/.ssh/id_rsa_azure
PORT_INDEX=1
EOF

op vault create test-bootstrap 2>/dev/null || true

bash ~/emerald-city/packs/gasworks/blueprints/web-mobile/scripts/02-generate-secrets.sh
```

**Pass criteria:** `Supabase` item created in 1Password with 5 fields. No SSH key (Path B skips it).

Verify:
```bash
op item get "Supabase" --vault test-bootstrap --format json \
  | jq '.fields[] | select(.value != null) | .label'
```

Expected fields: `jwt_secret`, `postgres_password`, `dashboard_password`, `anon_key`, `service_role_key`.

**Cleanup:**
```bash
op vault delete test-bootstrap
rm -rf /tmp/bootstrap-test
```

---

## Test 5 — Phase 3 SaaS Key Collection (shared observability path)

Tests the shared observability copy path. Uses the real `constellation` 1Password vault as the source.

```bash
mkdir -p /tmp/bootstrap-test && cd /tmp/bootstrap-test

cat > .bootstrap-config <<'EOF'
PROJECT=test-bootstrap
REPO=stevebargelt/test-bootstrap
DOMAIN=harebrained-apps.com
SUPABASE_STRATEGY=2
OAUTH_PROVIDERS="github"
OBSERVABILITY=shared
VM_IP=20.118.130.228
KV_NAME=kv-constellation
SSH_KEY_PATH=~/.ssh/id_rsa_azure
PORT_INDEX=1
EOF

op vault create test-bootstrap 2>/dev/null || true

bash ~/emerald-city/packs/gasworks/blueprints/web-mobile/scripts/03-collect-saas-keys.sh
```

**When prompted:**

| Prompt | Value |
|--------|-------|
| Open browser? | `n` (skip) |
| Vercel token | `fake-vercel-token-123` |
| Expo token | `fake-expo-token-456` |
| Create GitHub OAuth App via CLI? | `n` |
| GitHub Client ID | `fake-gh-client-id` |
| GitHub Client Secret | `fake-gh-secret` |
| Existing project vault name | `constellation` |

The script will automatically copy `Resend`, `New Relic`, and `PostHog` from the `constellation` vault.

**Pass criteria:** `Vercel`, `Expo`, `GitHub OAuth`, `Resend`, `New Relic`, `PostHog` items all in `test-bootstrap` vault.

Verify:
```bash
op item list --vault test-bootstrap --format json | jq '.[].title'
```

**Cleanup:**
```bash
op vault delete test-bootstrap
rm -rf /tmp/bootstrap-test
```

---

## Test 6 — Phase 5 Push Secrets (needs a throwaway GitHub repo)

```bash
# Create a throwaway repo first
gh repo create stevebargelt/bootstrap-test-throwaway --private

mkdir -p /tmp/bootstrap-test && cd /tmp/bootstrap-test

# Rebuild vault and config (or reuse from Test 5 if not cleaned up)
cat > .bootstrap-config <<'EOF'
PROJECT=test-bootstrap
REPO=stevebargelt/bootstrap-test-throwaway
DOMAIN=harebrained-apps.com
SUPABASE_STRATEGY=2
OAUTH_PROVIDERS="github"
OBSERVABILITY=shared
VM_IP=20.118.130.228
KV_NAME=kv-constellation
SSH_KEY_PATH=~/.ssh/id_rsa_azure
PORT_INDEX=1
EOF

# Run phases 2+3 first if vault doesn't exist, then:
bash ~/emerald-city/packs/gasworks/blueprints/web-mobile/scripts/05-push-secrets.sh
```

**Pass criteria:**

```bash
# GitHub secrets were set
gh secret list -R stevebargelt/bootstrap-test-throwaway

# .env.local.tpl generated with correct vault name and Supabase URL substituted
grep "test-bootstrap" /tmp/bootstrap-test/.env.local.tpl
grep "test-bootstrap.db.harebrained-apps.com" /tmp/bootstrap-test/.env.local.tpl
```

**Cleanup:**
```bash
gh repo delete stevebargelt/bootstrap-test-throwaway --yes
op vault delete test-bootstrap
rm -rf /tmp/bootstrap-test
```

---

## Test 7 — Full Orchestrator Run, Path B End-to-End

Once Tests 1–5 pass individually, run the full wizard:

```bash
mkdir -p /tmp/bootstrap-test-full && cd /tmp/bootstrap-test-full

~/emerald-city/packs/gasworks/blueprints/web-mobile/bootstrap.sh
```

Use the same Path B answers as Test 3.

**Resume test** — if it fails at phase 3, verify `--from-phase` works:

```bash
~/emerald-city/packs/gasworks/blueprints/web-mobile/bootstrap.sh --from-phase 3
```

**Pass criteria:** All phases complete, summary printed with correct Supabase URL and vault name.

**Cleanup:**
```bash
gh repo delete stevebargelt/test-bootstrap --yes
op vault delete test-bootstrap
rm -rf /tmp/bootstrap-test-full
```

---

## Test 8 — Phase 6 VM Configuration (modifies live VM — reversible)

Tests adding a new Supabase stack to the existing shared VM. Uses a throwaway project name.
**This runs against the real VM** — read the cleanup steps before starting.

```bash
mkdir -p /tmp/bootstrap-test && cd /tmp/bootstrap-test

cat > .bootstrap-config <<'EOF'
PROJECT=test-bootstrap
REPO=stevebargelt/test-bootstrap
DOMAIN=harebrained-apps.com
SUPABASE_STRATEGY=2
OAUTH_PROVIDERS="github"
OBSERVABILITY=shared
VM_IP=20.118.130.228
KV_NAME=kv-constellation
SSH_KEY_PATH=~/.ssh/id_rsa_azure
PORT_INDEX=1
EOF

op vault create test-bootstrap 2>/dev/null || true
bash ~/emerald-city/packs/gasworks/blueprints/web-mobile/scripts/02-generate-secrets.sh

bash ~/emerald-city/packs/gasworks/blueprints/web-mobile/scripts/06-add-to-existing-vm.sh
```

**Pass criteria:**

```bash
# Supabase secrets written to Key Vault
ssh -i ~/.ssh/id_rsa_azure azureuser@20.118.130.228 \
  "az keyvault secret list --vault-name kv-constellation --query '[].name' -o tsv | grep TEST"

# Docker Compose directory created on VM
ssh -i ~/.ssh/id_rsa_azure azureuser@20.118.130.228 "ls /opt/supabase-test-bootstrap/"

# Containers running
ssh -i ~/.ssh/id_rsa_azure azureuser@20.118.130.228 \
  "sudo docker compose -p test-bootstrap ps"

# Caddy rules added
ssh -i ~/.ssh/id_rsa_azure azureuser@20.118.130.228 \
  "grep 'test-bootstrap' /etc/caddy/Caddyfile"

# DNS records exist
az network dns record-set a show \
  --zone-name db.harebrained-apps.com \
  --resource-group constellation \
  --name test-bootstrap
```

**Cleanup:**
```bash
# Stop and remove containers on VM
ssh -i ~/.ssh/id_rsa_azure azureuser@20.118.130.228 \
  "cd /opt/supabase-test-bootstrap && sudo docker compose --env-file .env.ports down -v"

# Remove project directory from VM
ssh -i ~/.ssh/id_rsa_azure azureuser@20.118.130.228 \
  "sudo rm -rf /opt/supabase-test-bootstrap"

# Remove from secret loader config
ssh -i ~/.ssh/id_rsa_azure azureuser@20.118.130.228 \
  "sudo sed -i '/^test-bootstrap$/d' /etc/supabase-loader.conf"

# Remove Caddy rules and reload
ssh -i ~/.ssh/id_rsa_azure azureuser@20.118.130.228 "$(cat <<'SSHEOF'
  sudo sed -i '/test-bootstrap\.db\./,/^}$/d' /etc/caddy/Caddyfile
  sudo caddy reload --config /etc/caddy/Caddyfile 2>/dev/null || sudo systemctl reload caddy
SSHEOF
)"

# Remove Key Vault secrets
for secret in JWT-SECRET POSTGRES-PASSWORD ANON-KEY SERVICE-ROLE-KEY DASHBOARD-PASSWORD; do
  az keyvault secret delete --vault-name kv-constellation \
    --name "TEST-BOOTSTRAP-${secret}" 2>/dev/null || true
done

# Remove DNS records
az network dns record-set a delete \
  --zone-name db.harebrained-apps.com \
  --resource-group constellation \
  --name test-bootstrap --yes 2>/dev/null || true
az network dns record-set a delete \
  --zone-name db.harebrained-apps.com \
  --resource-group constellation \
  --name studio.test-bootstrap --yes 2>/dev/null || true

# Remove 1Password vault and local files
op vault delete test-bootstrap
rm -rf /tmp/bootstrap-test
```

---

## Quick Reference

| Test | Risk | Time | Run When |
|------|------|------|----------|
| 1 — JWT generator | None | 30s | First |
| 2 — Prereqs | None | 30s | First |
| 3 — Phase 1 init | Reversible (vault) | 2 min | After 1-2 pass |
| 4 — Phase 2 secrets | Reversible (vault) | 1 min | After 3 passes |
| 5 — Phase 3 SaaS keys | Reversible (vault) | 3 min | After 4 passes |
| 6 — Phase 5 push | Real GitHub repo | 5 min | After 1-5 pass |
| 7 — Full run | All of above | 15 min | Last |
| 8 — Phase 6 VM config | Live VM (reversible) | 10 min | After 7 passes |
