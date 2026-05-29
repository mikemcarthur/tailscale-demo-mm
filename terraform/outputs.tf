output "tailnet_name" {
  description = "The tailnet name, for reference in the README and demo flow"
  value       = var.tailnet_name
}

output "operator_secret_manifest_path" {
  description = "Path to the generated Kubernetes Secret manifest for the operator"
  value       = local_sensitive_file.operator_secret.filename
}

output "policy_summary" {
  description = "Human-readable summary of who can reach what"
  value = <<-EOT
    Admin users (${join(", ", var.admin_emails)}):
      can reach tag:app-public (it-tools) on tcp:443
      can reach tag:app-admin (status-page) on tcp:443

    Contractor users (${join(", ", var.contractor_emails)}):
      can reach tag:app-public (it-tools) on tcp:443
      CANNOT reach tag:app-admin (denied at network layer)

    K8s Operator (tag:k8s-operator):
      can reach all tagged service nodes for management
  EOT
}
