#!/bin/bash

# =========================================================
# Kubernetes Worker Node Setup
# Kubernetes + Containerd + Calico
# =========================================================

set -e

# =========================================================
# DEFAULT CONFIGURATION
# =========================================================

DEFAULT_POD_NETWORK_CIDR="192.168.0.0/16"


# =========================================================
# SCRIPT HEADER
# =========================================================

clear

echo ""
echo "========================================================="
echo "          Kubernetes Worker Node Setup"
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
echo " Kubernetes Version"
echo "========================================================="
echo ""

echo "IMPORTANT:"
echo ""
echo "The Kubernetes version on this Worker Node must match"
echo "the Kubernetes version installed on the Control Plane."
echo ""
echo "Example:"
echo ""
echo "  Control Plane : v1.36"
echo "  Worker Node   : v1.36"
echo ""
echo "Enter the SAME Kubernetes version used on the"
echo "Control Plane."
echo ""

read -p "Enter Kubernetes version: " K8S_VERSION

if [ -z "$K8S_VERSION" ]; then

    echo ""
    echo "ERROR: Kubernetes version cannot be empty."
    exit 1

fi

echo ""
echo "Selected Kubernetes version:"
echo "${K8S_VERSION}"


# =========================================================
# 2. WORKER HOSTNAME
# =========================================================

echo ""
echo "========================================================="
echo " Worker Node Hostname"
echo "========================================================="
echo ""

echo "IMPORTANT:"
echo ""
echo "Each Worker Node must have a UNIQUE hostname."
echo ""
echo "Examples:"
echo ""
echo "  worker-node-1"
echo "  worker-node-2"
echo "  worker-node-3"
echo ""

read -p "Enter Worker Node Hostname: " WORKER_HOSTNAME

if [ -z "$WORKER_HOSTNAME" ]; then

    echo ""
    echo "ERROR: Worker hostname cannot be empty."
    exit 1

fi


# =========================================================
# VALIDATE HOSTNAME
# =========================================================

if ! [[ "$WORKER_HOSTNAME" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ ]]; then

    echo ""
    echo "ERROR: Invalid hostname."
    echo ""
    echo "Examples:"
    echo "  worker-node-1"
    echo "  worker-node-2"
    exit 1

fi

sudo hostnamectl set-hostname "${WORKER_HOSTNAME}"

echo ""
echo "Worker hostname:"
hostname


# =========================================================
# 3. WORKER PRIVATE IP
# =========================================================

echo ""
echo "========================================================="
echo " Worker Private IP"
echo "========================================================="
echo ""

echo "The script will automatically detect the private IP"
echo "assigned to this EC2 Worker node."
echo ""

DETECTED_WORKER_IP=$(hostname -I | awk '{print $1}')


# =========================================================
# CHECK DETECTED IP
# =========================================================

if [ -z "$DETECTED_WORKER_IP" ]; then

    echo "Could not automatically detect the Worker IP."
    echo ""
    echo "You must enter it manually."
    echo ""

    read -p "Enter Worker Private IP: " WORKER_IP

    if [ -z "$WORKER_IP" ]; then

        echo ""
        echo "ERROR: Worker Private IP cannot be empty."
        exit 1

    fi

else

    echo "Detected Worker Private IP:"
    echo ""
    echo "  ${DETECTED_WORKER_IP}"
    echo ""

    read -p "Do you want to use this IP? (y/n): " USE_DETECTED_IP

    if [[ "$USE_DETECTED_IP" == "y" || "$USE_DETECTED_IP" == "Y" ]]; then

        WORKER_IP="${DETECTED_WORKER_IP}"

    elif [[ "$USE_DETECTED_IP" == "n" || "$USE_DETECTED_IP" == "N" ]]; then

        echo ""
        echo "Enter the Worker Private IP manually."
        echo ""

        read -p "Worker Private IP: " WORKER_IP

        if [ -z "$WORKER_IP" ]; then

            echo ""
            echo "ERROR: Worker Private IP cannot be empty."
            exit 1

        fi

    else

        echo ""
        echo "ERROR: Please enter y or n."
        exit 1

    fi

fi


# =========================================================
# VALIDATE WORKER IP FORMAT
# =========================================================

if ! [[ "$WORKER_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then

    echo ""
    echo "ERROR: Invalid IPv4 address."
    echo "Example: 10.0.1.11"
    exit 1

fi


# =========================================================
# VALIDATE IP OCTETS
# =========================================================

IFS='.' read -r -a IP_PARTS <<< "$WORKER_IP"

for PART in "${IP_PARTS[@]}"; do

    if (( PART < 0 || PART > 255 )); then

        echo ""
        echo "ERROR: Invalid IPv4 address: ${WORKER_IP}"
        exit 1

    fi

done


# =========================================================
# CHECK WORKER IP EXISTS
# =========================================================

echo ""
echo "Checking Worker IP..."

if ! ip -4 addr show | grep -qw "$WORKER_IP"; then

    echo ""
    echo "ERROR: ${WORKER_IP} is not assigned to this machine."
    echo ""
    echo "Available IPv4 addresses:"
    echo ""

    ip -4 addr show

    exit 1

fi

echo ""
echo "Worker IP verified:"
echo "${WORKER_IP}"


# =========================================================
# 4. POD NETWORK CIDR
# =========================================================

echo ""
echo "========================================================="
echo " Pod Network CIDR Selection"
echo "========================================================="
echo ""

echo "IMPORTANT:"
echo ""
echo "Use the SAME Pod Network CIDR configured on the"
echo "Control Plane."
echo ""
echo "Default Pod Network CIDR: ${DEFAULT_POD_NETWORK_CIDR}"
echo ""

read -p "Do you want to use the default Pod Network CIDR ${DEFAULT_POD_NETWORK_CIDR}? (y/n): " USE_DEFAULT_CIDR

if [[ "$USE_DEFAULT_CIDR" == "y" || "$USE_DEFAULT_CIDR" == "Y" ]]; then

    POD_NETWORK_CIDR="${DEFAULT_POD_NETWORK_CIDR}"

elif [[ "$USE_DEFAULT_CIDR" == "n" || "$USE_DEFAULT_CIDR" == "N" ]]; then

    echo ""
    read -p "Enter Pod Network CIDR used on Control Plane: " POD_NETWORK_CIDR

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
# 5. SHOW CONFIGURATION
# =========================================================

echo ""
echo "========================================================="
echo " Selected Worker Configuration"
echo "========================================================="
echo ""
echo " Worker Hostname   : ${WORKER_HOSTNAME}"
echo " Worker Private IP : ${WORKER_IP}"
echo " Kubernetes        : ${K8S_VERSION}"
echo " Pod Network CIDR  : ${POD_NETWORK_CIDR}"
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
# 6. UPDATE UBUNTU
# =========================================================

echo ""
echo "========================================================="
echo "[6/12] Updating Ubuntu"
echo "========================================================="
echo ""

sudo apt update -y
sudo apt upgrade -y


# =========================================================
# 7. DISABLE SWAP
# =========================================================

echo ""
echo "========================================================="
echo "[7/12] Disabling Swap"
echo "========================================================="
echo ""

sudo swapoff -a

sudo sed -i '/ swap / s/^/#/' /etc/fstab

echo ""
echo "Swap status:"
free -h


# =========================================================
# 8. LOAD KERNEL MODULES
# =========================================================

echo ""
echo "========================================================="
echo "[8/12] Loading Kubernetes Kernel Modules"
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
# 9. CONFIGURE KUBERNETES NETWORKING
# =========================================================

echo ""
echo "========================================================="
echo "[9/12] Configuring Kubernetes Networking"
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
# 10. INSTALL PREREQUISITES
# =========================================================

echo ""
echo "========================================================="
echo "[10/12] Installing Kubernetes Prerequisites"
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
# INSTALL CONTAINERD
# =========================================================

echo ""
echo "Installing containerd..."

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
# 11. KUBERNETES REPOSITORY
# =========================================================

echo ""
echo "========================================================="
echo "[11/12] Configuring Kubernetes Repository"
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
# INSTALL KUBERNETES PACKAGES
# =========================================================

echo ""
echo "Installing Kubernetes packages..."

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
# 12. KUBEADM JOIN
# =========================================================

echo ""
echo "========================================================="
echo "[12/12] Join Worker to Kubernetes Cluster"
echo "========================================================="
echo ""

echo "IMPORTANT:"
echo ""
echo "Before continuing, make sure:"
echo ""
echo "  1. Control Plane is successfully initialized."
echo "  2. Calico is installed on the Control Plane."
echo "  3. This Worker Kubernetes version matches"
echo "     the Control Plane Kubernetes version."
echo "  4. The Control Plane Private IP is reachable."
echo "  5. Port 6443 is accessible from this Worker."
echo ""
echo "========================================================="
echo ""

echo "On the Control Plane, generate the join command using:"
echo ""
echo "  kubeadm token create --print-join-command"
echo ""
echo "Example:"
echo ""
echo "  sudo kubeadm join 10.0.1.10:6443 --token <TOKEN> \\"
echo "      --discovery-token-ca-cert-hash sha256:<HASH>"
echo ""
echo "========================================================="
echo ""

read -p "Do you have the kubeadm join command? (y/n): " HAS_JOIN_COMMAND

if [[ "$HAS_JOIN_COMMAND" != "y" && "$HAS_JOIN_COMMAND" != "Y" ]]; then

    echo ""
    echo "Setup paused."
    echo ""
    echo "Generate the command on the Control Plane:"
    echo ""
    echo "  kubeadm token create --print-join-command"
    echo ""
    echo "Then run this Worker setup script again."
    echo ""

    exit 0

fi


# =========================================================
# READ JOIN COMMAND
# =========================================================

echo ""
echo "Paste the COMPLETE kubeadm join command."
echo ""

read -r -p "Join Command: " JOIN_COMMAND

if [ -z "$JOIN_COMMAND" ]; then

    echo ""
    echo "ERROR: Join command cannot be empty."
    exit 1

fi


# =========================================================
# VALIDATE JOIN COMMAND
# =========================================================

if [[ "$JOIN_COMMAND" != *"kubeadm join"* ]]; then

    echo ""
    echo "ERROR: Invalid kubeadm join command."
    echo ""
    echo "The command must contain:"
    echo ""
    echo "  kubeadm join"
    echo ""

    exit 1

fi


# =========================================================
# SHOW JOIN CONFIGURATION
# =========================================================

echo ""
echo "========================================================="
echo " Worker Join Configuration"
echo "========================================================="
echo ""
echo " Worker Hostname   : ${WORKER_HOSTNAME}"
echo " Worker Private IP : ${WORKER_IP}"
echo " Kubernetes        : ${K8S_VERSION}"
echo " Pod Network CIDR  : ${POD_NETWORK_CIDR}"
echo ""
echo "Join Command:"
echo ""
echo "${JOIN_COMMAND}"
echo ""
echo "========================================================="
echo ""

read -p "Join this Worker to the cluster? (y/n): " CONFIRM_JOIN

if [[ "$CONFIRM_JOIN" != "y" && "$CONFIRM_JOIN" != "Y" ]]; then

    echo ""
    echo "Worker join cancelled."
    exit 0

fi


# =========================================================
# CHECK CONTROL PLANE CONNECTIVITY
# =========================================================

echo ""
echo "Checking Kubernetes API Server connectivity..."

CONTROL_PLANE_ENDPOINT=$(echo "${JOIN_COMMAND}" | \
sed -n 's/.*kubeadm join \([^ ]*\).*/\1/p')

if [ -n "$CONTROL_PLANE_ENDPOINT" ]; then

    CONTROL_PLANE_HOST=$(echo "$CONTROL_PLANE_ENDPOINT" | cut -d':' -f1)
    CONTROL_PLANE_PORT=$(echo "$CONTROL_PLANE_ENDPOINT" | cut -d':' -f2)

    if [ -z "$CONTROL_PLANE_PORT" ]; then
        CONTROL_PLANE_PORT="6443"
    fi

    echo ""
    echo "Control Plane:"
    echo "${CONTROL_PLANE_HOST}:${CONTROL_PLANE_PORT}"
    echo ""

    if command -v nc >/dev/null 2>&1; then

        if nc -z -w 5 "$CONTROL_PLANE_HOST" "$CONTROL_PLANE_PORT"; then

            echo "API Server port ${CONTROL_PLANE_PORT} is reachable."

        else

            echo ""
            echo "WARNING: Could not connect to:"
            echo "${CONTROL_PLANE_HOST}:${CONTROL_PLANE_PORT}"
            echo ""
            echo "Check AWS Security Groups and networking."
            echo ""

            read -p "Continue anyway? (y/n): " CONTINUE_CONNECTIVITY

            if [[ "$CONTINUE_CONNECTIVITY" != "y" && "$CONTINUE_CONNECTIVITY" != "Y" ]]; then
                exit 1
            fi

        fi

    fi

fi


# =========================================================
# JOIN CLUSTER
# =========================================================

echo ""
echo "========================================================="
echo " Joining Kubernetes Cluster"
echo "========================================================="
echo ""

echo "Executing kubeadm join..."

sudo ${JOIN_COMMAND}


# =========================================================
# KUBELET STATUS
# =========================================================

echo ""
echo "========================================================="
echo " Worker Kubelet Status"
echo "========================================================="
echo ""

sudo systemctl is-active kubelet

echo ""
echo "Kubelet enabled:"
sudo systemctl is-enabled kubelet


# =========================================================
# FINAL MESSAGE
# =========================================================

echo ""
echo "========================================================="
echo " WORKER NODE SETUP COMPLETED"
echo "========================================================="
echo ""
echo " Worker Hostname   : ${WORKER_HOSTNAME}"
echo " Worker Private IP : ${WORKER_IP}"
echo " Kubernetes        : ${K8S_VERSION}"
echo " Containerd        : Installed"
echo " Pod Network CIDR  : ${POD_NETWORK_CIDR}"
echo ""
echo "========================================================="
echo ""
echo "Now go to the Control Plane and run:"
echo ""
echo "  kubectl get nodes -o wide"
echo ""
echo "You should see:"
echo ""
echo "  ${WORKER_HOSTNAME}"
echo ""
echo "with STATUS:"
echo ""
echo "  Ready"
echo ""
echo "========================================================="
echo ""