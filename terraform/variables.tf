variable "tailnet_name" {
  description = "The tailnet name, e.g. tail957262.ts.net"
  type        = string
}

variable "tailscale_oauth_client_id" {
  description = "OAuth client ID from the Tailscale admin console"
  type        = string
  sensitive   = true
}

variable "tailscale_oauth_client_secret" {
  description = "OAuth client secret from the Tailscale admin console"
  type        = string
  sensitive   = true
}

variable "admin_emails" {
  description = "List of Google account emails for the admin group"
  type        = list(string)
}

variable "contractor_emails" {
  description = "List of Google account emails for the contractor group"
  type        = list(string)
}
