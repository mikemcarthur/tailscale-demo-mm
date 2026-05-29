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

# Write the OAuth credentials to a Kubernetes Secret manifest the operator consumes.
# The operator uses these credentials to dynamically create the auth keys it needs
# for its managed proxy pods.
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
