---
name: manage-secrets
description: Manage 1Password + fnox secrets for the Alloy collector in taiidani's monitoring repo. Use when asked to add a secret, troubleshoot missing/empty secrets, or understand how secrets get injected during deploys.
---

# Managing Secrets with 1Password + fnox

Secrets are stored in 1Password and fetched by [fnox](https://fnox.jdx.dev). **Uncloud runs fnox for you at deploy time** — you don't wrap commands in `fnox exec` yourself. Declare a secret in `alloy/compose.yml` using the `x-command` extension on a top-level `secrets:` entry, and Uncloud executes that command when deploying:

```yaml
secrets:
  GRAFANA_CLOUD_TOKEN:
    x-command: fnox get GRAFANA_CLOUD_TOKEN
```

fnox is installed locally via the root `mise.toml` (`mise install` if it's missing). For the full deploy flow this is part of, see the `deploy-alloy` skill.

## Configuration

- 1Password Vault: `Development`
- Authentication: `OP_SERVICE_ACCOUNT_TOKEN` in `mise.local.toml` (gitignored)
- `alloy/fnox.toml` holds the Grafana Cloud secrets (1Password item `Grafana Cloud`)
- Terraform secrets (Discord webhook, OIDC client secret, Grafana token) are TFC workspace variables, not fnox

## Adding a secret to Alloy

1. Store the secret in the 1Password "Development" vault (the Grafana Cloud values live in the `Grafana Cloud` item)
2. Create or edit `alloy/fnox.toml`:
   ```toml
   default_provider = "onepass"

   [providers.onepass]
   type = "1password"
   vault = "Development"

   [secrets]
   "SECRET_NAME" = { provider = "onepass", value = "Item Name/field" }
   ```
3. Declare it in `alloy/compose.yml` so Uncloud resolves it via fnox:
   ```yaml
   secrets:
     SECRET_NAME:
       x-command: fnox get SECRET_NAME
   ```
   and reference it in Alloy's `environment` / secret mounts as appropriate.
4. The secret is resolved the next time `uc deploy` runs in `alloy/`.

fnox resolves configuration relative to the directory it runs in, so run `uc deploy` (and any manual `fnox` commands) from inside `alloy/` so its `fnox.toml` takes effect.

## Testing secrets manually

```bash
cd alloy
fnox get SECRET_NAME            # resolve a single secret, exactly as Uncloud will
fnox exec --if-missing=error -- env | grep SECRET_NAME
```

## Troubleshooting

- **Secrets not found:** Check the 1Password vault has the item/field, verify `mise.local.toml` has `OP_SERVICE_ACCOUNT_TOKEN`
- **`fnox` not found:** Run `mise install` — fnox comes from the root `mise.toml`
- **Variables empty:** Test with `fnox get SECRET_NAME` from `alloy/`; clear the fnox cache if values look stale
- **Wrong secrets used:** fnox resolves relative to the directory it's invoked from — make sure you ran `uc deploy` from `alloy/`
- **Ensure item/field names in `fnox.toml` match 1Password exactly** — mismatches fail silently as missing secrets
