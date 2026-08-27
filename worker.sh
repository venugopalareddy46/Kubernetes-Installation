#!/bin/bash

# =========================================================
# Kubernetes v1.36 - Worker Node Setup
# Multiple Worker Support
# Containerd + kubeadm
# =========================================================

set -e

K8S_VERSION="v1.36"

# =========================================================
# ASK WORKER HOSTNAME
# =========================================================

echo ""
echo "========================================================="
echo " Kubernetes Worker Node Setup"
echo "========================================================="
echo ""

read -p "Enter Worker Node Name (e.g. worker-1): " WORKER_HOSTNAME

# Check empty input
if [ -z "$WORKER_HOSTNAME" ]; then
    echo ""
    echo "ERROR: Worker node name cannot be empty."
    exit 1
fi

echo ""
echo "Worker Node Name : ${WORKER_HOSTNAME}"
echo "Kubernetes       : ${K8S_VERSION}"
echo ""

read -p "Continue with this worker name? (y/n): " CONFIRM

if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "Setup cancelled."
    exit 0
fi

echo ""
echo "========================================================="
echo " Starting Worker Node Setup"
echo " Hostname   : ${WORKER_HOSTNAME}"
echo " Kubernetes : ${K8S_VERSION}"
echo "========================================================="


# =========================================================
# 1. UPDATE UBUNTU
# =========================================================

echo "[1/9] Updating Ubuntu..."

sudo apt update -y
sudo apt upgrade -y


# =========================================================
# 2. SET HOSTNAME
# =========================================================

echo "[2/9] Setting hostname..."

sudo hostnamectl set-hostname "${WORKER_HOSTNAME}"

hostname


# =========================================================
# 3. DISABLE SWAP
# =========================================================

echo "[3/9] Disabling swap..."

sudo swapoff -a

sudo sed -i '/ swap / s/^/#/' /etc/fstab

free -h


# =========================================================
# 4. LOAD KUBERNETES KERNEL MODULES
# =========================================================

echo "[4/9] Loading kernel modules..."

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter


# =========================================================
# 5. CONFIGURE KUBERNETES NETWORKING
# =========================================================

echo "[5/9] Configuring Kubernetes networking..."

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system


# =========================================================
# 6. INSTALL CONTAINERD
# =========================================================

echo "[6/9] Installing containerd..."

sudo apt install -y containerd

sudo mkdir -p /etc/containerd

containerd config default | \
sudo tee /etc/containerd/config.toml > /dev/null

sudo sed -i \
's/SystemdCgroup = false/SystemdCgroup = true/' \
/etc/containerd/config.toml

sudo systemctl restart containerd
sudo systemctl enable containerd

sudo systemctl status containerd --no-pager


# =========================================================
# 7. CONFIGURE KUBERNETES REPOSITORY
# =========================================================

echo "[7/9] Configuring Kubernetes repository..."

sudo apt-get install -y \
apt-transport-https \
ca-certificates \
curl \
gpg

sudo mkdir -p -m 755 /etc/apt/keyrings

curl -fsSL \
https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/Release.key | \
sudo gpg --dearmor \
-o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/ /" | \
sudo tee /etc/apt/sources.list.d/kubernetes.list


# =========================================================
# 8. INSTALL KUBERNETES
# =========================================================

echo "[8/9] Installing Kubernetes packages..."

sudo apt-get update -y

sudo apt-get install -y \
kubelet \
kubeadm \
kubectl

sudo apt-mark hold kubelet kubeadm kubectl

sudo systemctl enable --now kubelet


# =========================================================
# 9. WORKER READY
# =========================================================

echo ""
echo "========================================================="
echo " ${WORKER_HOSTNAME} IS READY"
echo "========================================================="

echo ""
echo "Next step:"
echo ""
echo "1. Go to the control-plane."
echo ""
echo "2. Generate the join command:"
echo ""
echo "   kubeadm token create --print-join-command"
echo ""
echo "3. Copy the EXACT command."
echo ""
echo "4. Run it on ${WORKER_HOSTNAME}."
echo ""
echo "========================================================="