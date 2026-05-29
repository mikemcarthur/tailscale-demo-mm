terraform {
  required_version = ">= 1.6.0"

  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.21"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}
