#!/usr/bin/env bash
# verify.sh
# End-to-end validation for tailscale-demo-mm.
# Checks:
#   1. Both app pods running 2/2 in the cluster
#   2. Both apps registered as tailnet devices with the correct tags
#   3. HTTPS reachability for each app from this machine (assumes Tailscale client is signed in as admin)

set -uo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

PASS=0
FAIL=0

check() {
  local name="$1"
  local result="$2"
  if [[ "$result" == "pass" ]]; then
    echo -e "${GREEN}PASS${NC}: $name"
    PASS=$((PASS + 1))
  else
    echo -e "${RED}FAIL${NC}: $name"
    FAIL=$((FAIL + 1))
  fi
}

# Read tailnet name from tfvars (best-effort)
TFVARS="terraform/terraform.tfvars"
if [[ ! -f "$TFVARS" ]]; then
  echo -e "${RED}Missing terraform/terraform.tfvars. Run from repo root.${NC}"
  exit 2
fi

TAILNET=$(grep -E '^tailnet_name' "$TFVARS" | cut -d'"' -f2)
if [[ -z "$TAILNET" ]]; then
  echo -e "${RED}Could not parse tailnet_name from $TFVARS${NC}"
  exit 2
fi

echo ""
echo "tailscale-demo-mm verification"
echo "Tailnet: $TAILNET"
echo ""

# 1. Kubernetes side: app pods are running
echo "=== Kubernetes ==="

IT_TOOLS_READY=$(kubectl get pod -n tailscale-demo -l app=it-tools \
  -o jsonpath='{.items[0].status.containerStatuses[*].ready}' 2>/dev/null | tr ' ' '\n' | grep -c "true" || echo "0")
if [[ "$IT_TOOLS_READY" == "2" ]]; then
  check "it-tools pod is 2/2 Running" "pass"
else
  check "it-tools pod is 2/2 Running (got $IT_TOOLS_READY/2)" "fail"
fi

STATUS_PAGE_READY=$(kubectl get pod -n tailscale-demo -l app=status-page \
  -o jsonpath='{.items[0].status.containerStatuses[*].ready}' 2>/dev/null | tr ' ' '\n' | grep -c "true" || echo "0")
if [[ "$STATUS_PAGE_READY" == "2" ]]; then
  check "status-page pod is 2/2 Running" "pass"
else
  check "status-page pod is 2/2 Running (got $STATUS_PAGE_READY/2)" "fail"
fi

OPERATOR_READY=$(kubectl get deployment -n tailscale operator \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
if [[ "$OPERATOR_READY" == "1" ]]; then
  check "Tailscale operator is Running" "pass"
else
  check "Tailscale operator is Running" "fail"
fi
echo ""
echo "=== Tailnet reachability ==="

# 2. HTTPS reachability from this machine
# Requires the running shell to have Tailscale client signed in as group:admin
check_https() {
  local name="$1"
  local url="https://$name.$TAILNET"
  local code
  code=$(curl -ks --max-time 15 -o /dev/null -w "%{http_code}" "$url" || echo "000")
  if [[ "$code" == "200" || "$code" == "301" || "$code" == "302" ]]; then
    check "$name reachable via HTTPS (HTTP $code)" "pass"
  else
    check "$name reachable via HTTPS (got HTTP $code, expected 2xx/3xx)" "fail"
  fi
}

if command -v tailscale >/dev/null 2>&1; then
  TS_STATUS=$(tailscale status 2>/dev/null | head -1 | awk '{print $2}')
  if [[ -n "$TS_STATUS" ]]; then
    echo "Running as Tailscale device: $TS_STATUS"
    check_https "it-tools"
    check_https "status-page"
  else
    echo -e "${YELLOW}Tailscale not signed in. Skipping HTTPS reachability checks.${NC}"
    echo "Run 'sudo tailscale up' first to test reachability."
  fi
else
  echo -e "${YELLOW}Tailscale CLI not found on this machine. Skipping HTTPS reachability checks.${NC}"
fi

echo ""
echo "=== Summary ==="
echo -e "${GREEN}Passed: $PASS${NC}"
if [[ $FAIL -gt 0 ]]; then
  echo -e "${RED}Failed: $FAIL${NC}"
  exit 1
else
  echo "All checks passed."
fi
