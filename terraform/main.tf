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

# Auth key the Kubernetes Operator will use to join the tailnet.
resource "tailscale_tailnet_key" "operator" {
  reusable      = true
  ephemeral     = false
  preauthorized = true
  description   = "tailscale-demo-mm: Kubernetes Operator auth key"
  tags          = ["tag:k8s-operator"]
  expiry        = 7776000
}

# Write the auth key to a Kubernetes Secret manifest the Helm install can consume.
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
      authkey = tailscale_tailnet_key.operator.key
    }
  })
}
