#!/bin/bash

# =========================================================
# Kubernetes Complete Cleanup
# Works on Control Plane and Worker Nodes
# =========================================================

set -e

echo "========================================================="
echo " Kubernetes Complete Cleanup"
echo "========================================================="


# =========================================================
# 1. STOP SERVICES
# =========================================================

echo "[1/12] Stopping services..."

sudo systemctl stop kubelet 2>/dev/null || true
sudo systemctl stop containerd 2>/dev/null || true


# =========================================================
# 2. RESET KUBEADM
# =========================================================

echo "[2/12] Resetting kubeadm..."

sudo kubeadm reset -f 2>/dev/null || true


# =========================================================
# 3. REMOVE KUBERNETES PACKAGES
# =========================================================

echo "[3/12] Removing Kubernetes packages..."

sudo apt-mark unhold kubeadm kubelet kubectl \
2>/dev/null || true

sudo apt purge -y \
kubeadm \
kubelet \
kubectl \
kubernetes-cni \
2>/dev/null || true


# =========================================================
# 4. REMOVE KUBERNETES DATA
# =========================================================

echo "[4/12] Removing Kubernetes data..."

sudo rm -rf /etc/kubernetes
sudo rm -rf /var/lib/kubelet
sudo rm -rf /var/lib/etcd


# =========================================================
# 5. REMOVE CNI
# =========================================================

echo "[5/12] Removing CNI configuration..."

sudo rm -rf /etc/cni
sudo rm -rf /opt/cni


# =========================================================
# 6. REMOVE kubectl CONFIGURATION
# =========================================================

echo "[6/12] Removing kubectl configuration..."

rm -rf "$HOME/.kube"

sudo rm -rf /root/.kube


# =========================================================
# 7. REMOVE NETWORK INTERFACES
# =========================================================

echo "[7/12] Removing CNI network interfaces..."

sudo ip link delete cni0 2>/dev/null || true
sudo ip link delete flannel.1 2>/dev/null || true
sudo ip link delete tunl0 2>/dev/null || true
sudo ip link delete vxlan.calico 2>/dev/null || true
sudo ip link delete vxlan-v6.calico 2>/dev/null || true


# =========================================================
# 8. REMOVE KUBERNETES REPOSITORY
# =========================================================

echo "[8/12] Removing Kubernetes repository..."

sudo rm -f \
/etc/apt/sources.list.d/kubernetes.list

sudo rm -f \
/etc/apt/keyrings/kubernetes-apt-keyring.gpg


# =========================================================
# 9. REMOVE CONTAINERD
# =========================================================

echo "[9/12] Removing containerd..."

sudo apt purge -y containerd \
2>/dev/null || true

sudo rm -rf /etc/containerd
sudo rm -rf /var/lib/containerd


# =========================================================
# 10. CLEAN PACKAGES
# =========================================================

echo "[10/12] Cleaning packages..."

sudo apt autoremove -y
sudo apt autoclean


# =========================================================
# 11. RELOAD SYSTEMD
# =========================================================

echo "[11/12] Reloading systemd..."

sudo systemctl daemon-reload


# =========================================================
# 12. VERIFY
# =========================================================

echo ""
echo "========================================================="
echo " Cleanup Verification"
echo "========================================================="

echo ""
echo "Kubernetes binaries:"

command -v kubeadm || echo "kubeadm removed"
command -v kubelet || echo "kubelet removed"
command -v kubectl || echo "kubectl removed"
command -v containerd || echo "containerd removed"

echo ""
echo "Kubernetes directories:"

[ -d /etc/kubernetes ] \
&& echo "/etc/kubernetes STILL EXISTS" \
|| echo "/etc/kubernetes removed"

[ -d /var/lib/kubelet ] \
&& echo "/var/lib/kubelet STILL EXISTS" \
|| echo "/var/lib/kubelet removed"

[ -d /var/lib/etcd ] \
&& echo "/var/lib/etcd STILL EXISTS" \
|| echo "/var/lib/etcd removed"

echo ""
echo "========================================================="
echo " Kubernetes Cleanup Completed"
echo "========================================================="

echo ""
echo "Rebooting in 10 seconds..."

sleep 10

sudo reboot