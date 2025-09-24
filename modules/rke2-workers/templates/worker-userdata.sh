#!/bin/bash
set -euo pipefail

# Ensure kernel modules are set
modprobe br_netfilter || true
modprobe overlay || true
tee /etc/sysctl.d/99-kubernetes.conf >/dev/null <<'EOF'
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system || true
# Relax firewalld
systemctl disable --now firewalld 2>/dev/null || true

if [ -n "${rke2_version}" ]; then
  INSTALL_RKE2_VERSION='${rke2_version}'
else
  INSTALL_RKE2_VERSION=""
fi

# Join via NLB supervisor endpoint (controllers behind NLB)
curl -sfL https://get.rke2.io | \
  INSTALL_RKE2_VERSION="$${INSTALL_RKE2_VERSION}" \
  RKE2_URL="https://${controller_nlb_dns}:9345" \
  RKE2_TOKEN='${cluster_token}' \
  sh -s - agent

systemctl enable rke2-agent
systemctl start rke2-agent

