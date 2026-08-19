#!/usr/bin/env bash
# JumpServer Automated Deployment Script for Debian 11 / 12
# Run as root or with sudo

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "[-] Error: This script must be run as root or with sudo."
  exit 1
fi

echo "[1/4] Installing system dependencies and official Docker Engine..."
apt-get update -qq
apt-get install -qq -y curl wget ca-certificates gnupg lsb-release iptables gettext

install -m 0755 -d /etc/apt/keyrings
if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
  curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
fi

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -qq
apt-get install -qq -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

systemctl enable --now docker

echo "[2/4] Fetching JumpServer deployment installer..."
cd /opt
curl -sSL https://github.com/jumpserver/jumpserver/releases/latest/download/quick_start.sh -o quick_start.sh
chmod +x quick_start.sh

echo "[3/4] Executing JumpServer setup..."
./quick_start.sh

echo "[4/4] Deployment sequence completed."
