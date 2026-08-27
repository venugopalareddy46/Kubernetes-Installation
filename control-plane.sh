#!/bin/bash

# =========================================================
# Kubernetes Control Plane Setup
# Kubernetes + Containerd + Calico
# =========================================================

set -e

# =========================================================
# DEFAULT CONFIGURATION
# =========================================================

DEFAULT_K8S_VERSION="v1.36"
DEFAULT_CONTROL_PLANE_HOSTNAME="control-plane"
DEFAULT_POD_NETWORK_CIDR="192.168.0.0/16"
DEFAULT_CALICO_VERSION="v3.32.1"


# =========================================================
# SCRIPT HEADER
# =========================================================

clear

echo ""
echo "========================================================="
echo "       Kubernetes Control Plane Setup"
echo "========================================================="
echo ""
echo " Kubernetes : kubeadm"
echo " Container  : containerd"
echo " CNI        : Calico"
echo ""
echo "========================================================="
echo ""


# =========================================================
# 1. KUBERNETES VERSION
# =========================================================

echo ""
echo "========================================================="
echo " Kubernetes Version Selection"
echo "========================================================="
echo ""

echo "Default Kubernetes Version: ${DEFAULT_K8S_VERSION}"
echo ""

read -p "Do you want to use the default version ${DEFAULT_K8S_VERSION}? (y/n): " USE_DEFAULT

if [[ "$USE_DEFAULT" == "y" || "$USE_DEFAULT" == "Y" ]]; then

    K8S_VERSION="${DEFAULT_K8S_VERSION}"

elif [[ "$USE_DEFAULT" == "n" || "$USE_DEFAULT" == "N" ]]; then

    echo ""
    read -p "Enter Kubernetes version (example: v1.35): " K8S_VERSION

    if [ -z "$K8S_VERSION" ]; then
        echo ""
        echo "ERROR: Kubernetes version cannot be empty."
        exit 1
    fi

else

    echo ""
    echo "ERROR: Please enter y or n."
    exit 1

fi


# =========================================================
# 2. CONTROL PLANE HOSTNAME
# =========================================================

echo ""
echo "========================================================="
echo " Control Plane Hostname"
echo "========================================================="
echo ""

echo "Default Hostname: ${DEFAULT_CONTROL_PLANE_HOSTNAME}"
echo ""

read -p "Do you want to use the default hostname ${DEFAULT_CONTROL_PLANE_HOSTNAME}? (y/n): " USE_DEFAULT_HOSTNAME

if [[ "$USE_DEFAULT_HOSTNAME" == "y" || "$USE_DEFAULT_HOSTNAME" == "Y" ]]; then

    CONTROL_PLANE_HOSTNAME="${DEFAULT_CONTROL_PLANE_HOSTNAME}"

elif [[ "$USE_DEFAULT_HOSTNAME" == "n" || "$USE_DEFAULT_HOSTNAME" == "N" ]]; then

    echo ""
    read -p "Enter Control Plane Hostname: " CONTROL_PLANE_HOSTNAME

    if [ -z "$CONTROL_PLANE_HOSTNAME" ]; then
        echo ""
        echo "ERROR: Hostname cannot be empty."
        exit 1
    fi

else

    echo ""
    echo "ERROR: Please enter y or n."
    exit 1

fi

sudo hostnamectl set-hostname "${CONTROL_PLANE_HOSTNAME}"

echo ""
echo "Control Plane Hostname:"
hostname


# =========================================================
# 3. CONTROL PLANE PRIVATE IP
# =========================================================

echo ""
echo "========================================================="
echo " Control Plane Private IP"
echo "========================================================="
echo ""

echo "IMPORTANT:"
echo ""
echo "You must enter the PRIVATE IPv4 address of this"
echo "Control Plane EC2 instance."
echo ""
echo "How to find it in AWS:"
echo ""
echo "  1. Open AWS Management Console."
echo "  2. Navigate to EC2."
echo "  3. Select Instances."
echo "  4. Select this Control Plane instance."
echo "  5. Open the instance Details."
echo "  6. Find 'Private IPv4 address'."
echo "  7. Copy that Private IPv4 address."
echo ""
echo "Example:"
echo "  10.0.1.10"
echo ""
echo "DO NOT use the Public IPv4 address."
echo ""

read -p "Enter Control Plane Private IP: " CONTROL_PLANE_IP

if [ -z "$CONTROL_PLANE_IP" ]; then

    echo ""
    echo "ERROR: Control Plane Private IP cannot be empty."
    exit 1

fi


# =========================================================
# VALIDATE CONTROL PLANE IP FORMAT
# =========================================================

if ! [[ "$CONTROL_PLANE_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then

    echo ""
    echo "ERROR: Invalid IPv4 address."
    echo "Example: 10.0.1.10"
    exit 1

fi


# =========================================================
# VALIDATE IP OCTETS
# =========================================================

IFS='.' read -r -a IP_PARTS <<< "$CONTROL_PLANE_IP"

for PART in "${IP_PARTS[@]}"; do

    if (( PART < 0 || PART > 255 )); then

        echo ""
        echo "ERROR: Invalid IPv4 address: ${CONTROL_PLANE_IP}"
        exit 1

    fi

done


# =========================================================
# CHECK IP EXISTS ON THIS MACHINE
# =========================================================

echo ""
echo "Checking Control Plane IP..."

if ! ip -4 addr show | grep -qw "$CONTROL_PLANE_IP"; then

    echo ""
    echo "ERROR: ${CONTROL_PLANE_IP} is not assigned to this machine."
    echo ""
    echo "Available IPv4 addresses:"
    echo ""

    ip -4 addr show

    exit 1

fi

echo ""
echo "Control Plane IP verified:"
echo "${CONTROL_PLANE_IP}"


# =========================================================
# 4. POD NETWORK CIDR
# =========================================================

echo ""
echo "========================================================="
echo " Pod Network CIDR Selection"
echo "========================================================="
echo ""

echo "Default Pod Network CIDR: ${DEFAULT_POD_NETWORK_CIDR}"
echo ""

read -p "Do you want to use the default Pod Network CIDR ${DEFAULT_POD_NETWORK_CIDR}? (y/n): " USE_DEFAULT_CIDR

if [[ "$USE_DEFAULT_CIDR" == "y" || "$USE_DEFAULT_CIDR" == "Y" ]]; then

    POD_NETWORK_CIDR="${DEFAULT_POD_NETWORK_CIDR}"

elif [[ "$USE_DEFAULT_CIDR" == "n" || "$USE_DEFAULT_CIDR" == "N" ]]; then

    echo ""
    read -p "Enter Pod Network CIDR (example: 192.168.0.0/16): " POD_NETWORK_CIDR

    if [ -z "$POD_NETWORK_CIDR" ]; then

        echo ""
        echo "ERROR: Pod Network CIDR cannot be empty."
        exit 1

    fi

else

    echo ""
    echo "ERROR: Please enter y or n."
    exit 1

fi


# =========================================================
# BASIC CIDR VALIDATION
# =========================================================

if ! [[ "$POD_NETWORK_CIDR" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[1-2][0-9]|3[0-2])$ ]]; then

    echo ""
    echo "ERROR: Invalid Pod Network CIDR."
    echo "Example: 192.168.0.0/16"
    exit 1

fi


# =========================================================
# 5. CALICO VERSION
# =========================================================

echo ""
echo "========================================================="
echo " Calico Version Selection"
echo "========================================================="
echo ""

echo "Default Calico Version: ${DEFAULT_CALICO_VERSION}"
echo ""

read -p "Do you want to use the default Calico version ${DEFAULT_CALICO_VERSION}? (y/n): " USE_DEFAULT_CALICO

if [[ "$USE_DEFAULT_CALICO" == "y" || "$USE_DEFAULT_CALICO" == "Y" ]]; then

    CALICO_VERSION="${DEFAULT_CALICO_VERSION}"

elif [[ "$USE_DEFAULT_CALICO" == "n" || "$USE_DEFAULT_CALICO" == "N" ]]; then

    echo ""
    read -p "Enter Calico version (example: v3.32.1): " CALICO_VERSION

    if [ -z "$CALICO_VERSION" ]; then

        echo ""
        echo "ERROR: Calico version cannot be empty."
        exit 1

    fi

else

    echo ""
    echo "ERROR: Please enter y or n."
    exit 1

fi


# =========================================================
# 6. FINAL CONFIGURATION
# =========================================================

echo ""
echo "========================================================="
echo " Selected Configuration"
echo "========================================================="
echo ""
echo " Control Plane Hostname : ${CONTROL_PLANE_HOSTNAME}"
echo " Control Plane IP       : ${CONTROL_PLANE_IP}"
echo " Pod Network CIDR       : ${POD_NETWORK_CIDR}"
echo " Kubernetes             : ${K8S_VERSION}"
echo " Calico                 : ${CALICO_VERSION}"
echo ""
echo "========================================================="
echo ""

read -p "Continue with this configuration? (y/n): " CONFIRM

if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then

    echo ""
    echo "Setup cancelled."
    exit 0

fi


# =========================================================
# 7. UPDATE UBUNTU
# =========================================================

echo ""
echo "========================================================="
echo "[7/16] Updating Ubuntu"
echo "========================================================="
echo ""

sudo apt update -y
sudo apt upgrade -y


# =========================================================
# 8. DISABLE SWAP
# =========================================================

echo ""
echo "========================================================="
echo "[8/16] Disabling Swap"
echo "========================================================="
echo ""

sudo swapoff -a

sudo sed -i '/ swap / s/^/#/' /etc/fstab

echo ""
echo "Swap status:"
free -h


# =========================================================
# 9. LOAD KERNEL MODULES
# =========================================================

echo ""
echo "========================================================="
echo "[9/16] Loading Kubernetes Kernel Modules"
echo "========================================================="
echo ""

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
# 10. CONFIGURE KUBERNETES NETWORKING
# =========================================================

echo ""
echo "========================================================="
echo "[10/16] Configuring Kubernetes Networking"
echo "========================================================="
echo ""

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

echo ""
echo "IP Forwarding:"
sysctl net.ipv4.ip_forward


# =========================================================
# 11. INSTALL PREREQUISITES
# =========================================================

echo ""
echo "========================================================="
echo "[11/16] Installing Kubernetes Prerequisites"
echo "========================================================="
echo ""

sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gpg \
    conntrack \
    socat \
    ebtables \
    ethtool \
    iproute2 \
    iputils-ping \
    net-tools \
    jq \
    bash-completion


# =========================================================
# 12. INSTALL CONTAINERD
# =========================================================

echo ""
echo "========================================================="
echo "[12/16] Installing Containerd"
echo "========================================================="
echo ""

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
sudo systemctl is-active containerd

echo ""
echo "Containerd enabled:"
sudo systemctl is-enabled containerd


# =========================================================
# 13. KUBERNETES REPOSITORY
# =========================================================

echo ""
echo "========================================================="
echo "[13/16] Configuring Kubernetes Repository"
echo "========================================================="
echo ""

sudo mkdir -p -m 755 /etc/apt/keyrings

curl -fsSL \
"https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/Release.key" | \
sudo gpg --dearmor \
-o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/ /" | \
sudo tee /etc/apt/sources.list.d/kubernetes.list


# =========================================================
# 14. INSTALL KUBERNETES
# =========================================================

echo ""
echo "========================================================="
echo "[14/16] Installing Kubernetes Packages"
echo "========================================================="
echo ""

sudo apt-get update -y

sudo apt-get install -y \
    kubelet \
    kubeadm \
    kubectl

sudo apt-mark hold kubelet kubeadm kubectl

sudo systemctl enable --now kubelet

echo ""
echo "Kubernetes versions:"
echo ""

kubeadm version

echo ""

kubectl version --client

echo ""

kubelet --version


# =========================================================
# 15. INITIALIZE CONTROL PLANE
# =========================================================

echo ""
echo "========================================================="
echo "[15/16] Initializing Control Plane"
echo "========================================================="
echo ""

echo "Control Plane IP : ${CONTROL_PLANE_IP}"
echo "Pod Network CIDR : ${POD_NETWORK_CIDR}"
echo "Kubernetes       : ${K8S_VERSION}"
echo ""

sudo kubeadm init \
    --apiserver-advertise-address="${CONTROL_PLANE_IP}" \
    --pod-network-cidr="${POD_NETWORK_CIDR}" \
    --v=5


# =========================================================
# 16. CONFIGURE KUBECTL
# =========================================================

echo ""
echo "========================================================="
echo "[16/16] Configuring kubectl"
echo "========================================================="
echo ""

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
# INSTALL CALICO
# =========================================================

echo ""
echo "========================================================="
echo " Installing Calico ${CALICO_VERSION}"
echo "========================================================="
echo ""

CALICO_BASE_URL="https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests"


# =========================================================
# CALICO CRDs
# =========================================================

echo ""
echo "Installing Calico CRDs..."

kubectl apply -f \
"${CALICO_BASE_URL}/v1_crd_projectcalico_org.yaml"


# =========================================================
# TIGERA OPERATOR
# =========================================================

echo ""
echo "Installing Tigera Operator..."

kubectl apply -f \
"${CALICO_BASE_URL}/tigera-operator.yaml"


# =========================================================
# CALICO CUSTOM RESOURCES
# =========================================================

echo ""
echo "Installing Calico Custom Resources..."

TEMP_CALICO_FILE="/tmp/calico-custom-resources.yaml"

curl -fsSL \
"${CALICO_BASE_URL}/custom-resources.yaml" \
-o "${TEMP_CALICO_FILE}"

# Update the Calico IPPool CIDR to match the selected Pod CIDR.
sed -i \
"s#cidr: [0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/[0-9]\{1,2\}#cidr: ${POD_NETWORK_CIDR}#g" \
"${TEMP_CALICO_FILE}"

kubectl apply -f "${TEMP_CALICO_FILE}"

rm -f "${TEMP_CALICO_FILE}"


# =========================================================
# WAIT FOR CALICO
# =========================================================

echo ""
echo "========================================================="
echo " Waiting for Calico"
echo "========================================================="
echo ""

echo "Waiting for Calico components..."

kubectl wait \
    --for=condition=Available \
    deployment/tigera-operator \
    -n tigera-operator \
    --timeout=180s || true

sleep 20

echo ""
echo "Calico pods:"
kubectl get pods -n calico-system


# =========================================================
# CONTROL PLANE STATUS
# =========================================================

echo ""
echo "========================================================="
echo " Control Plane Node"
echo "========================================================="
echo ""

kubectl get nodes -o wide


# =========================================================
# ALL PODS
# =========================================================

echo ""
echo "========================================================="
echo " All Kubernetes Pods"
echo "========================================================="
echo ""

kubectl get pods -A


# =========================================================
# CALICO STATUS
# =========================================================

echo ""
echo "========================================================="
echo " Calico Status"
echo "========================================================="
echo ""

kubectl get tigerastatus 2>/dev/null || true


# =========================================================
# GENERATE WORKER JOIN COMMAND
# =========================================================

echo ""
echo "========================================================="
echo " WORKER NODE JOIN COMMAND"
echo "========================================================="
echo ""

echo "Run the following command on every Worker Node:"
echo ""

kubeadm token create --print-join-command

echo ""
echo "========================================================="
echo " IMPORTANT"
echo "========================================================="
echo ""
echo "Copy the complete kubeadm join command."
echo ""
echo "You will need it on every Worker Node."
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
echo " Hostname         : ${CONTROL_PLANE_HOSTNAME}"
echo " Control Plane IP : ${CONTROL_PLANE_IP}"
echo " Kubernetes       : ${K8S_VERSION}"
echo " Containerd       : Installed"
echo " Calico           : ${CALICO_VERSION}"
echo " Pod Network CIDR : ${POD_NETWORK_CIDR}"
echo ""
echo "Useful commands:"
echo ""
echo "  kubectl get nodes -o wide"
echo "  kubectl get pods -A"
echo "  kubectl get svc -A"
echo "  kubectl get tigerastatus"
echo ""
echo "========================================================="
echo ""