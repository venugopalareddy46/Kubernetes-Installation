#!/bin/bash

# =========================================================
# Kubernetes v1.36 - Control Plane Setup
# Containerd + Calico
# =========================================================

set -e

CONTROL_PLANE_IP="172.31.35.143"
POD_NETWORK_CIDR="192.168.0.0/16"
K8S_VERSION="v1.36"
CALICO_VERSION="v3.32.1"

echo "========================================================="
echo " Kubernetes Control Plane Setup"
echo " Kubernetes : ${K8S_VERSION}"
echo " Calico     : ${CALICO_VERSION}"
echo "========================================================="


# =========================================================
# 1. UPDATE UBUNTU
# =========================================================

echo "[1/12] Updating Ubuntu..."

sudo apt update -y
sudo apt upgrade -y


# =========================================================
# 2. SET HOSTNAME
# =========================================================

echo "[2/12] Setting hostname..."

sudo hostnamectl set-hostname control-plane

hostname


# =========================================================
# 3. DISABLE SWAP
# =========================================================

echo "[3/12] Disabling swap..."

sudo swapoff -a

sudo sed -i '/ swap / s/^/#/' /etc/fstab

free -h


# =========================================================
# 4. LOAD KUBERNETES KERNEL MODULES
# =========================================================

echo "[4/12] Loading kernel modules..."

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter


# =========================================================
# 5. CONFIGURE KUBERNETES NETWORKING
# =========================================================

echo "[5/12] Configuring Kubernetes networking..."

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system


# =========================================================
# 6. INSTALL CONTAINERD
# =========================================================

echo "[6/12] Installing containerd..."

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

echo "[7/12] Configuring Kubernetes repository..."

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

echo "[8/12] Installing Kubernetes packages..."

sudo apt-get update -y

sudo apt-get install -y \
kubelet \
kubeadm \
kubectl

sudo apt-mark hold kubelet kubeadm kubectl

sudo systemctl enable --now kubelet


# =========================================================
# 9. INITIALIZE CONTROL PLANE
# =========================================================

echo "[9/12] Initializing Kubernetes control plane..."

sudo kubeadm init \
--apiserver-advertise-address="${CONTROL_PLANE_IP}" \
--pod-network-cidr="${POD_NETWORK_CIDR}" \
--v=5


# =========================================================
# 10. CONFIGURE kubectl
# =========================================================

echo "[10/12] Configuring kubectl..."

mkdir -p "$HOME/.kube"

sudo cp -i /etc/kubernetes/admin.conf \
"$HOME/.kube/config"

sudo chown "$(id -u):$(id -g)" \
"$HOME/.kube/config"


# =========================================================
# 11. INSTALL CALICO
# =========================================================

echo "[11/12] Installing Calico..."

kubectl create -f \
"https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/v1_crd_projectcalico_org.yaml"

kubectl create -f \
"https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml"

kubectl create -f \
"https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/custom-resources.yaml"


# =========================================================
# 12. VERIFY CONTROL PLANE
# =========================================================

echo "[12/12] Verifying cluster..."

echo ""
echo "Nodes:"
kubectl get nodes -o wide

echo ""
echo "Pods:"
kubectl get pods -A

echo ""
echo "Calico:"
kubectl get tigerastatus 2>/dev/null || true


# =========================================================
# GENERATE WORKER JOIN COMMAND
# =========================================================

echo ""
echo "========================================================="
echo " WORKER JOIN COMMAND"
echo "========================================================="

kubeadm token create --print-join-command

echo ""
echo "Copy the above command."
echo "Run it on every worker node."
echo ""
echo "========================================================="