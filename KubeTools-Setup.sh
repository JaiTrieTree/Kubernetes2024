#!/bin/bash
# kubeadm installation script for Ubuntu 20.04+ using pkgs.k8s.io
# Pins Kubernetes to a stable version (v1.28).
#
# Usage: sudo ./KubeTools-Setup.sh

# Optional check to ensure script is run with sudo:
# if [ "$EUID" -ne 0 ]; then
#   echo "Please run this script as root (e.g. sudo)."
#   exit 1
# fi

# 1) Check if /tmp/container.txt exists (from your environment)
if ! [ -f /tmp/container.txt ]; then
  echo "Please run ./setup-container.sh before running this script."
  exit 4
fi

# 2) Pin the Kubernetes version here (MAJOR.MINOR or MAJOR.MINOR.PATCH)
#    e.g. "v1.28" or "v1.28.2"
KUBEVERSION="v1.28"

# 3) If OS is Ubuntu, proceed
MYOS=$(hostnamectl | awk '/Operating/ { print $3 }')
if [ "$MYOS" = "Ubuntu" ]; then
  echo "RUNNING UBUNTU CONFIGURATION"

  # Ensure modules br_netfilter is loaded
  cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

  # Install prerequisites
  sudo apt-get update
  sudo apt-get install -y apt-transport-https curl ca-certificates jq

  # Create the keyring directory if it doesn’t exist
  sudo mkdir -p /etc/apt/keyrings

  # Remove any old/broken Kubernetes repo file
  sudo rm -f /etc/apt/sources.list.d/kubernetes.list

  # 4) Download and store the official Kubernetes GPG key
  #    IMPORTANT: This uses colons, matching the official docs.
  curl -fsSL "https://pkgs.k8s.io/core:/stable:/${KUBEVERSION}/deb/Release.key" \
    | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

  # 5) Add the Kubernetes repository to sources.list
  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/${KUBEVERSION}/deb/ /" \
    | sudo tee /etc/apt/sources.list.d/kubernetes.list

  # Update apt and install kubelet, kubeadm, kubectl
  sudo apt-get update
  sudo apt-get install -y kubelet kubeadm kubectl
  # Prevent accidental upgrades
  sudo apt-mark hold kubelet kubeadm kubectl

  # Disable swap (required by kubeadm)
  sudo swapoff -a
  sudo sed -i 's/\/swap/#\/swap/' /etc/fstab
fi

# 6) Configure sysctl for bridged IPv4/IPv6 traffic
sudo tee /etc/sysctl.d/k8s.conf >/dev/null <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system

# 7) Optional: Configure crictl to use containerd’s socket (if containerd is used)
if command -v crictl >/dev/null 2>&1; then
  sudo crictl config --set runtime-endpoint=unix:///run/containerd/containerd.sock
fi

# 8) Final message
cat <<EOF
==============================================================
Kubernetes tools have been installed (if no errors appeared).
1) On the control plane node, run:
     sudo kubeadm init ...
   Then set up your .kube/config as instructed.

2) Install a CNI plugin, e.g. Calico:
     kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

3) On worker nodes, join with the command provided by 'kubeadm init'.
==============================================================
EOF
