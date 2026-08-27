#!/bin/bash

# =========================================================
# Kubernetes v1.36 - Control Plane Setup
# Containerd + Calico
# =========================================================

set -e

POD_NETWORK_CIDR="192.168.0.0/16"
K8S_VERSION="v1.36"
CALICO_VERSION="v3.32.1"


# =========================================================
# ASK FOR CONTROL PLANE PRIVATE IP
# =========================================================

echo ""
echo "========================================================="
echo " Kubernetes Control Plane Setup"
echo "========================================================="
echo ""

read -p "Enter Control Plane Private IP: " CONTROL_PLANE_IP

# Check empty IP
if [ -z "$CONTROL_PLANE_IP" ]; then
    echo ""
    echo "ERROR: Control Plane Private IP cannot be empty."
    exit 1
fi

echo ""
echo "========================================================="
echo " Configuration"
echo "========================================================="
echo " Control Plane IP : ${CONTROL_PLANE_IP}"
echo " Pod Network CIDR : ${POD_NETWORK_CIDR}"
echo " Kubernetes       : ${K8S_VERSION}"
echo " Calico           : ${CALICO_VERSION}"
echo "========================================================="
echo ""

read -p "Continue with this configuration? (y/n): " CONFIRM

if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo ""
    echo "Setup cancelled."
    exit 0
fi

echo ""
echo "========================================================="
echo " Starting Kubernetes Control Plane Setup"
echo "========================================================="
echo " Control Plane IP : ${CONTROL_PLANE_IP}"
echo " Kubernetes       : ${K8S_VERSION}"
echo " Calico           : ${CALICO_VERSION}"
echo "========================================================="


# =========================================================
# 1. UPDATE UBUNTU
# =========================================================

echo ""
echo "[1/12] Updating Ubuntu..."

sudo apt update -y
sudo apt upgrade -y


# =========================================================
# 2. SET HOSTNAME
# =========================================================

echo ""
echo "[2/12] Setting hostname..."

sudo hostnamectl set-hostname control-plane

echo "Hostname:"
hostname


# =========================================================
# 3. DISABLE SWAP
# =========================================================

echo ""
echo "[3/12] Disabling swap..."

sudo swapoff -a

sudo sed -i '/ swap / s/^/#/' /etc/fstab

echo ""
echo "Swap status:"
free -h


# =========================================================
# 4. LOAD KUBERNETES KERNEL MODULES
# =========================================================

echo ""
echo "[4/12] Loading Kubernetes kernel modules..."

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

echo ""
echo "Loaded modules:"
lsmod | grep -E 'overlay|br_netfilter' || true


# =========================================================
# 5. CONFIGURE KUBERNETES NETWORKING
# =========================================================

echo ""
echo "[5/12] Configuring Kubernetes networking..."

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

echo ""
echo "IP forwarding:"
sysctl net.ipv4.ip_forward


# =========================================================
# 6. INSTALL CONTAINERD
# =========================================================

echo ""
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

echo ""
echo "Containerd status:"
sudo systemctl status containerd --no-pager


# =========================================================
# 7. CONFIGURE KUBERNETES REPOSITORY
# =========================================================

echo ""
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

echo ""
echo "[8/12] Installing Kubernetes packages..."

sudo apt-get update -y

sudo apt-get install -y \
kubelet \
kubeadm \
kubectl

sudo apt-mark hold kubelet kubeadm kubectl

sudo systemctl enable --now kubelet

echo ""
echo "Kubernetes versions:"
kubeadm version
kubectl version --client
kubelet --version


# =========================================================
# 9. INITIALIZE CONTROL PLANE
# =========================================================

echo ""
echo "[9/12] Initializing Kubernetes control plane..."

echo ""
echo "Using Control Plane IP:"
echo "${CONTROL_PLANE_IP}"

echo ""
echo "Using Pod Network CIDR:"
echo "${POD_NETWORK_CIDR}"

echo ""

sudo kubeadm init \
--apiserver-advertise-address="${CONTROL_PLANE_IP}" \
--pod-network-cidr="${POD_NETWORK_CIDR}" \
--v=5


# =========================================================
# 10. CONFIGURE kubectl
# =========================================================

echo ""
echo "[10/12] Configuring kubectl..."

mkdir -p "$HOME/.kube"

sudo cp -i /etc/kubernetes/admin.conf \
"$HOME/.kube/config"

sudo chown "$(id -u):$(id -g)" \
"$HOME/.kube/config"

echo ""
echo "kubectl configuration completed."

echo ""
echo "Cluster information:"
kubectl cluster-info


# =========================================================
# 11. INSTALL CALICO
# =========================================================

echo ""
echo "[11/12] Installing Calico ${CALICO_VERSION}..."

echo ""
echo "Installing Calico CRDs..."

kubectl create -f \
"https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/v1_crd_projectcalico_org.yaml"

echo ""
echo "Installing Tigera Operator..."

kubectl create -f \
"https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml"

echo ""
echo "Installing Calico Custom Resources..."

kubectl create -f \
"https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/custom-resources.yaml"


# =========================================================
# WAIT FOR CALICO
# =========================================================

echo ""
echo "Waiting for Calico components..."

sleep 10

echo ""
echo "Calico pods:"
kubectl get pods -n calico-system


# =========================================================
# 12. VERIFY CONTROL PLANE
# =========================================================

echo ""
echo "[12/12] Verifying Kubernetes cluster..."

echo ""
echo "========================================================="
echo " Nodes"
echo "========================================================="

kubectl get nodes -o wide


echo ""
echo "========================================================="
echo " All Pods"
echo "========================================================="

kubectl get pods -A


echo ""
echo "========================================================="
echo " Calico Status"
echo "========================================================="

kubectl get tigerastatus 2>/dev/null || true


# =========================================================
# GENERATE WORKER JOIN COMMAND
# =========================================================

echo ""
echo "========================================================="
echo " WORKER JOIN COMMAND"
echo "========================================================="

echo ""

kubeadm token create --print-join-command

echo ""
echo "========================================================="
echo " IMPORTANT"
echo "========================================================="
echo ""
echo "Copy the worker join command shown above."
echo ""
echo "Run that command on every worker node."
echo ""
echo "Example:"
echo ""
echo "  sudo kubeadm join <CONTROL-PLANE-IP>:6443 ..."
echo ""
echo "========================================================="


# =========================================================
# FINAL STATUS
# =========================================================

echo ""
echo "========================================================="
echo " CONTROL PLANE SETUP COMPLETED"
echo "========================================================="
echo ""
echo "Control Plane IP : ${CONTROL_PLANE_IP}"
echo "Hostname         : $(hostname)"
echo "Kubernetes       : ${K8S_VERSION}"
echo "Calico           : ${CALICO_VERSION}"
echo ""
echo "Check cluster:"
echo ""
echo "  kubectl get nodes -o wide"
echo ""
echo "  kubectl get pods -A"
echo ""
echo "========================================================="