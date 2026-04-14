# Template for OpenTofu secrets — never committed to git.
#
# This is a GENERIC template. The bootstrap wizard generates a project-specific
# version with the correct 1Password vault name. Do not use this file directly.
#
# Usage after bootstrap:  op inject -i secrets.tfvars.tpl -o secrets.tfvars

jwt_secret       = "{{ op://VAULT_PLACEHOLDER/Supabase/jwt_secret }}"
postgres_password = "{{ op://VAULT_PLACEHOLDER/Supabase/postgres_password }}"
anon_key         = "{{ op://VAULT_PLACEHOLDER/Supabase/anon_key }}"
service_role_key = "{{ op://VAULT_PLACEHOLDER/Supabase/service_role_key }}"
resend_api_key   = "{{ op://VAULT_PLACEHOLDER/Resend/api_key }}"
