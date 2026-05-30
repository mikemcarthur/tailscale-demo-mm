# Tailscale provider, authenticated via OAuth client credentials.
provider "tailscale" {
  oauth_client_id     = var.tailscale_oauth_client_id
  oauth_client_secret = var.tailscale_oauth_client_secret
  tailnet             = var.tailnet_name
}

# The Grants policy file. Source of truth for who can reach what.
resource "tailscale_acl" "demo" {
  acl = templatefile("${path.module}/policy.hujson", {
    admin_emails      = jsonencode(var.admin_emails)
    contractor_emails = jsonencode(var.contractor_emails)
  })

  overwrite_existing_content = true
}

# OAuth credentials Secret for the Tailscale Kubernetes Operator.
# The operator stays installed for tailnet credential management even though
# we use sidecars for the application proxies.
resource "local_sensitive_file" "operator_secret" {
  filename        = "${path.module}/../kubernetes/operator/operator-secret.yaml"
  file_permission = "0600"

  content = yamlencode({
    apiVersion = "v1"
    kind       = "Secret"
    metadata = {
      name      = "operator-oauth"
      namespace = "tailscale"
    }
    type = "Opaque"
    stringData = {
      client_id     = var.tailscale_oauth_client_id
      client_secret = var.tailscale_oauth_client_secret
    }
  })
}

# Auth key for the it-tools sidecar (tagged tag:app-public).
# Reusable so the Pod can be restarted; not ephemeral so the device persists
# in the tailnet across restarts (keeps the MagicDNS name stable).
resource "tailscale_tailnet_key" "it_tools" {
  reusable      = true
  ephemeral     = false
  preauthorized = true
  description   = "tailscale-demo-mm it-tools sidecar"
  tags          = ["tag:app-public"]
  expiry        = 7776000
}

# Auth key for the status-page sidecar (tagged tag:app-admin).
resource "tailscale_tailnet_key" "status_page" {
  reusable      = true
  ephemeral     = false
  preauthorized = true
  description   = "tailscale-demo-mm status-page sidecar"
  tags          = ["tag:app-admin"]
  expiry        = 7776000
}

# Kubernetes Secret holding the it-tools sidecar auth key.
resource "local_sensitive_file" "it_tools_secret" {
  filename        = "${path.module}/../kubernetes/apps/it-tools-secret.yaml"
  file_permission = "0600"

  content = yamlencode({
    apiVersion = "v1"
    kind       = "Secret"
    metadata = {
      name      = "it-tools-tailscale-authkey"
      namespace = "tailscale-demo"
    }
    type = "Opaque"
    stringData = {
      TS_AUTHKEY = tailscale_tailnet_key.it_tools.key
    }
  })
}

# Kubernetes Secret holding the status-page sidecar auth key.
resource "local_sensitive_file" "status_page_secret" {
  filename        = "${path.module}/../kubernetes/apps/status-page-secret.yaml"
  file_permission = "0600"

  content = yamlencode({
    apiVersion = "v1"
    kind       = "Secret"
    metadata = {
      name      = "status-page-tailscale-authkey"
      namespace = "tailscale-demo"
    }
    type = "Opaque"
    stringData = {
      TS_AUTHKEY = tailscale_tailnet_key.status_page.key
    }
  })
}
