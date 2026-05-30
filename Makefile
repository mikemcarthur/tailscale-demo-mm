# tailscale-demo-mm Makefile
#
# Wraps the demo lifecycle into a handful of commands.
# Assumes:
#   - kubectl is configured for the target cluster
#   - helm is installed
#   - terraform is installed and terraform/terraform.tfvars is populated

SHELL := /bin/bash

# Read tailnet name from tfvars for use in verification
TAILNET ?= $(shell grep -E '^tailnet_name' terraform/terraform.tfvars 2>/dev/null | cut -d'"' -f2)

# Color output
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m

.PHONY: help up tailnet operator apps verify revoke restore down clean status

help:
	@echo "tailscale-demo-mm: Identity-based access to private Kubernetes services."
	@echo ""
	@echo "Lifecycle commands:"
	@echo "  make up         Apply Terraform + install operator + deploy apps"
	@echo "  make down       Tear down apps, operator, and Tailscale configuration"
	@echo ""
	@echo "Demo commands:"
	@echo "  make verify     Run end-to-end validation checks"
	@echo "  make revoke     Remove contractor from access group (live revoke demo)"
	@echo "  make restore    Restore contractor's access"
	@echo ""
	@echo "Inspection:"
	@echo "  make status     Show current cluster + tailnet state"
	@echo ""
	@echo "Granular (rarely needed individually):"
	@echo "  make tailnet    Apply Terraform only"
	@echo "  make operator   Install the Tailscale Kubernetes Operator"
	@echo "  make apps       Deploy the demo apps"

up: tailnet operator apps
	@echo ""
	@echo -e "$(GREEN)Deployment complete.$(NC)"
	@echo "Run 'make verify' to validate, or visit the apps:"
	@echo "  https://it-tools.$(TAILNET)"
	@echo "  https://status-page.$(TAILNET)"

tailnet:
	@echo -e "$(YELLOW)Applying Terraform: tailnet policy and auth keys$(NC)"
	cd terraform && terraform init -upgrade && terraform apply -auto-approve

operator:
	@echo -e "$(YELLOW)Installing Tailscale Kubernetes Operator$(NC)"
	kubectl create namespace tailscale --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -f kubernetes/operator/operator-secret.yaml
	helm repo add tailscale https://pkgs.tailscale.com/helmcharts 2>/dev/null || true
	helm repo update
	helm upgrade --install tailscale-operator tailscale/tailscale-operator \
		--namespace tailscale \
		--values kubernetes/operator/values.yaml \
		--wait
	@echo -e "$(GREEN)Operator running.$(NC)"

apps:
	@echo -e "$(YELLOW)Deploying demo apps$(NC)"
	kubectl apply -f kubernetes/apps/namespace.yaml
	kubectl apply -f kubernetes/apps/it-tools-secret.yaml
	kubectl apply -f kubernetes/apps/status-page-secret.yaml
	kubectl apply -f kubernetes/apps/it-tools.yaml
	kubectl apply -f kubernetes/apps/status-page.yaml
	@echo -e "$(YELLOW)Waiting for pods to be Ready$(NC)"
	kubectl wait --for=condition=Available --timeout=120s \
		deployment/it-tools deployment/status-page -n tailscale-demo
	@echo -e "$(GREEN)Apps ready.$(NC)"

verify:
	@bash tests/verify.sh

revoke:
	@echo -e "$(YELLOW)Removing contractor from group:contractor$(NC)"
	@cp terraform/terraform.tfvars terraform/terraform.tfvars.bak
	@sed -i 's/^contractor_emails = \[.*$$/contractor_emails = []/' terraform/terraform.tfvars
	@# Handle the multiline form too
	@awk '/^contractor_emails = \[/{flag=1; print "contractor_emails = []"; next} /^\]/ && flag {flag=0; next} !flag' terraform/terraform.tfvars > terraform/terraform.tfvars.tmp && mv terraform/terraform.tfvars.tmp terraform/terraform.tfvars
	cd terraform && terraform apply -auto-approve
	@echo ""
	@echo -e "$(GREEN)Contractor revoked.$(NC) Allow ~10s for propagation."
	@echo "On contractor-laptop: 'tailscale status' should no longer show it-tools."

restore:
	@echo -e "$(YELLOW)Restoring contractor access$(NC)"
	@if [ -f terraform/terraform.tfvars.bak ]; then \
		mv terraform/terraform.tfvars.bak terraform/terraform.tfvars; \
		cd terraform && terraform apply -auto-approve; \
		echo -e "$(GREEN)Contractor restored.$(NC) Allow ~10s for propagation."; \
	else \
		echo -e "$(RED)No backup file found. Edit terraform.tfvars manually and run 'make tailnet'.$(NC)"; \
		exit 1; \
	fi

status:
	@echo "=== Pods ==="
	@kubectl get pods -n tailscale-demo 2>/dev/null || echo "  (tailscale-demo namespace not found)"
	@kubectl get pods -n tailscale 2>/dev/null || echo "  (tailscale namespace not found)"
	@echo ""
	@echo "=== Services exposed to tailnet ==="
	@echo "Check https://login.tailscale.com/admin for the live device list."

down:
	@echo -e "$(YELLOW)Tearing down apps$(NC)"
	-kubectl delete -f kubernetes/apps/status-page.yaml --ignore-not-found
	-kubectl delete -f kubernetes/apps/it-tools.yaml --ignore-not-found
	-kubectl delete -f kubernetes/apps/status-page-secret.yaml --ignore-not-found
	-kubectl delete -f kubernetes/apps/it-tools-secret.yaml --ignore-not-found
	-kubectl delete -f kubernetes/apps/namespace.yaml --ignore-not-found
	@echo -e "$(YELLOW)Uninstalling operator$(NC)"
	-helm uninstall tailscale-operator -n tailscale
	-kubectl delete namespace tailscale --ignore-not-found
	@echo -e "$(YELLOW)Destroying Tailscale configuration$(NC)"
	cd terraform && terraform destroy -auto-approve
	@echo -e "$(GREEN)Teardown complete.$(NC)"

clean:
	@rm -f terraform/terraform.tfvars.bak
	@echo "Cleaned local backup files."
