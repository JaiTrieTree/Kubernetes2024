#!/bin/bash
# kubeadm installation script for Ubuntu 20.04 LTS and later
# Based on official instructions from:
#   https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
#
# Usage: sudo ./install-kubetools.sh
#
# This script:
#   - Checks if a prerequisite file (/tmp/container.txt) exists
#   - Installs Kubernetes tools: kubelet, kubeadm, kubectl
#   - Disables swap
#   - Configures sysctl for bridging
#
# Note: Ensure you have 'jq' installed if you want to auto-detect the K8s version:
#       sudo apt-get update && sudo apt-get install -y jq
#

# Optional: check if script is run with sudo (uncomment if desired)
# if [ "$EUID" -ne 0 ]; then
#   echo "Please run this script as root (e.g. sudo)."
#   exit 1
# fi

# Check prerequisite file (from your environment)
if ! [ -f /tmp/container.txt ]; then
  echo "Please run ./setup-container.sh before running this script."
  exit 4
fi

# Detect OS (expects Ubuntu)
MYOS=$(hostnamectl | awk '/Operating/ { print $3 }')
OSVERSION=$(hostnamectl | awk '/Operating/ { print $4 }')

# Detect the latest Kubernetes version from GitHub
# e.g. "v1.28.2"
KUBEVERSION=$(curl -s https://api.github.com/repos/kubernetes/kubernetes/releases/latest | jq -r '.tag_name')
# Remove leading 'v' => "1.28.2"
KUBEVERSION=$(echo "$KUBEVERSION" | sed 's/^v//')
# Strip patch => "1.28"
KUBEVERSION=${KUBEVERSION%.*}

if [ "$MYOS" = "Ubuntu" ]; then
  echo "RUNNING UBUNTU CONFIGURATION"

  # Enable br_netfilter module
  cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

  # Update system packages and install prerequisites
  sudo apt-get update
  sudo apt-get install -y apt-transport-https curl ca-certificates jq

  # Create keyring directory if not present
  sudo mkdir -p /etc/apt/keyrings

  # Import Kubernetes GPG key
  curl -fsSL "https://pkgs.k8s.io/core/stable/${KUBEVERSION}/deb/Release.key" \
    | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

  # Add Kubernetes apt repository (with correct format)
  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core/stable/${KUBEVERSION}/deb/ /" \
    | sudo tee /etc/apt/sources.list.d/kubernetes.list

  # Wait briefly
  sleep 2

  # Update apt and install Kubernetes packages
  sudo apt-get update
  sudo apt-get install -y kubelet kubeadm kubectl
  sudo apt-mark hold kubelet kubeadm kubectl

  # Disable swap
  sudo swapoff -a
  # Comment out swap line in /etc/fstab
  sudo sed -i 's/\/swap/#\/swap/' /etc/fstab
fi

# Configure sysctl for bridging
sudo bash -c 'cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF'
sudo sysctl --system

# Configure crictl to use containerd (optional if containerd is used)
sudo crictl config --set runtime-endpoint=unix:///run/containerd/containerd.sock

echo "=============================================================="
echo "Kubernetes tools have been installed successfully (if no errors)."
echo "1) After initializing the control plane (on master node):"
echo "     kubeadm init ..."
echo "2) Then install Calico (on master node) with:"
echo "     kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml"
echo "3) On worker nodes, join the cluster with the command provided by 'kubeadm init'."
echo "=============================================================="
