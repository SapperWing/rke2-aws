#!/bin/bash
set -euo pipefail

# AWS now uses Instance Metadata Service Version 2 (IMDSv2) that requires a token to access the metadata
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
PUBIP="$(curl -H "X-aws-ec2-metadata-token: $${TOKEN}" -s http://169.254.169.254/latest/meta-data/public-ipv4 || true)"
PRIVIP="$(curl -H "X-aws-ec2-metadata-token: $${TOKEN}" -s http://169.254.169.254/latest/meta-data/local-ipv4 || true)"
HOSTSHORT="$(hostname -s || true)"
# PUBIP="$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || true)"
# PRIVIP="$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4 || true)"

mkdir -p /etc/rancher/rke2

# Build RKE2 config with safe SANs (include NLB DNS so clients can hit the LB)
{
  echo 'write-kubeconfig-mode: "0644"'
  echo 'profile: "cis-1.23"'
  echo 'disable:'
  if [ "${disable_ingress_nginx}" = "true" ]; then
    echo ' - rke2-ingress-nginx'
  fi
  echo ' - rke2-metrics-server'
  echo "bind-address: 0.0.0.0"
  [ -n "$${PRIVIP}" ] && echo "advertise-address: $${PRIVIP}"
  [ -n "$${PRIVIP}" ] && echo "node-ip: $${PRIVIP}"
  [ -n "$${PUBIP}" ] && echo "node-external-ip: $${PUBIP}"
  echo 'tls-san:'
  [ -n "$${PRIVIP}" ] && echo " - $${PRIVIP}"
  [ -n "$${PUBIP}" ] && echo " - $${PUBIP}"
  [ -n "$${HOSTSHORT}" ]&& echo " - $${HOSTSHORT}"
  [ -n "${lb_dns_name}" ] && echo " - ${lb_dns_name}"
} > /etc/rancher/rke2/config.yaml

# Make sure the kernel modules are set
modprobe br_netfilter || true
modprobe overlay || true
tee /etc/sysctl.d/99-kubernetes.conf >/dev/null <<'EOF'
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system || true
# Optional - Relax firewalld
systemctl disable --now firewalld 2>/dev/null || true

# Install RKE2 server
if [ -n "${rke2_version}" ]; then
  INSTALL_RKE2_VERSION='${rke2_version}'
else
  INSTALL_RKE2_VERSION=""
fi

curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION="$${INSTALL_RKE2_VERSION}" RKE2_TOKEN='${cluster_token}' sh -s - server
systemctl enable rke2-server
systemctl start rke2-server

# Wait for kubeconfig; point to NLB DNS if present, else public IP.
for i in $(seq 1 60); do [ -f /etc/rancher/rke2/rke2.yaml ] && break; sleep 5; done

if [ -f /etc/rancher/rke2/rke2.yaml ]; then
  if [ -n "${lb_dns_name}" ]; then
    sed -i "s#server: https://127.0.0.1:6443#server: https://${lb_dns_name}:6443#g" /etc/rancher/rke2/rke2.yaml || true
    sed -i "s#server: https://$${PRIVIP}:6443#server: https://${lb_dns_name}:6443#g" /etc/rancher/rke2/rke2.yaml || true
  elif [ -n "$${PUBIP}" ]; then
    sed -i "s#server: https://127.0.0.1:6443#server: https://$${PUBIP}:6443#g" /etc/rancher/rke2/rke2.yaml || true
    sed -i "s#server: https://$${PRIVIP}:6443#server: https://$${PUBIP}:6443#g" /etc/rancher/rke2/rke2.yaml || true
  fi
fi

