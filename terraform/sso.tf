# Sign in via the Authelia OIDC provider. The grafana.com login stays available
# as a backup, so auto_login is intentionally left off.
resource "grafana_sso_settings" "authelia" {
  provider_name = "generic_oauth"

  oauth2_settings {
    name          = "Authelia"
    client_id     = "grafana"
    client_secret = var.oidc_client_secret
    scopes        = "openid profile email groups"
    auth_url      = "https://auth.taiidani.com/api/oidc/authorization"
    token_url     = "https://auth.taiidani.com/api/oidc/token"
    api_url       = "https://auth.taiidani.com/api/oidc/userinfo"
    use_pkce      = true
    auth_style    = "InHeader"
    allow_sign_up = true

    login_attribute_path  = "preferred_username"
    groups_attribute_path = "groups"
    name_attribute_path   = "name"

    # Authelia's ID token doesn't carry 'groups' (only UserInfo does), so this
    # must evaluate to a non-role value rather than a hardcoded 'Viewer'
    # fallback, or Grafana never falls through to the UserInfo groups.
    # Cloud has no GrafanaAdmin role; 'Admin' is the top role.
    role_attribute_path = "contains(groups || `[]`, 'admins') && 'Admin'"
  }
}
