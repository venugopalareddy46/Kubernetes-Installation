
#!/bin/bash

# ============================================================
# COMPLETE KUBERNETES CONTROL PLANE INSTALLATION
# ============================================================
#
# Ubuntu EC2
#
# Components:
#   Kubernetes : v1.36.4
#   Container  : containerd
#   CNI        : Calico v3.32.2
#   Operator   : Tigera Operator
#   Ingress    : ingress-nginx v1.15.1
#
# Run as ROOT
# NO SUDO REQUIRED
#
# ============================================================

set -euo pipefail

# ============================================================
# CONFIGURATION
# ============================================================

K8S_MINOR_VERSION="v1.36"
K8S_VERSION="1.36.4"

CALICO_VERSION="v3.32.2"

INGRESS_VERSION="v1.15.1"

DEFAULT_HOSTNAME="control-plane"

DEFAULT_POD_CIDR="192.168.0.0/16"

CALICO_BASE_URL="https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests"

INGRESS_URL="https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-${INGRESS_VERSION}/deploy/static/provider/baremetal/deploy.yaml"


# ============================================================
# ROOT CHECK
# ============================================================

if [ "$(id -u)" -ne 0 ]; then
    echo
    echo "ERROR: This script must be executed as ROOT."
    echo
    echo "Run:"
    echo "  su -"
    echo "  bash install-k8s.sh"
    echo
    exit 1
fi


# ============================================================
# HEADER
# ============================================================

clear

echo
echo "============================================================"
echo " Kubernetes Complete Installation"
echo "============================================================"
echo
echo " Kubernetes       : ${K8S_VERSION}"
echo " Container Runtime : containerd"
echo " Calico            : ${CALICO_VERSION}"
echo " Ingress-NGINX     : ${INGRESS_VERSION}"
echo " Pod CIDR          : ${DEFAULT_POD_CIDR}"
echo
echo " Running as ROOT"
echo " No sudo required"
echo
echo "============================================================"
echo


# ============================================================
# HOSTNAME
# ============================================================

echo
echo "[1/18] Configure Hostname"
echo "------------------------------------------------------------"

read -rp "Use hostname '${DEFAULT_HOSTNAME}'? (y/n): " USE_DEFAULT_HOSTNAME

if [[ "${USE_DEFAULT_HOSTNAME}" =~ ^[Yy]$ ]]; then

    CONTROL_PLANE_HOSTNAME="${DEFAULT_HOSTNAME}"

elif [[ "${USE_DEFAULT_HOSTNAME}" =~ ^[Nn]$ ]]; then

    read -rp "Enter Control Plane Hostname: " CONTROL_PLANE_HOSTNAME

    if [ -z "${CONTROL_PLANE_HOSTNAME}" ]; then
        echo "ERROR: Hostname cannot be empty."
        exit 1
    fi

else

    echo "ERROR: Enter y or n."
    exit 1

fi

hostnamectl set-hostname "${CONTROL_PLANE_HOSTNAME}"

echo
echo "Hostname:"
hostname


# ============================================================
# CONTROL PLANE PRIVATE IP
# ============================================================

echo
echo "[2/18] Configure Control Plane Private IP"
echo "------------------------------------------------------------"

echo
echo "Your EC2 PRIVATE IPv4 address is required."
echo
echo "Check with:"
echo
echo "  ip -4 addr"
echo
echo "Example:"
echo "  10.0.1.10"
echo

read -rp "Enter Control Plane Private IP: " CONTROL_PLANE_IP

if [ -z "${CONTROL_PLANE_IP}" ]; then
    echo "ERROR: Private IP cannot be empty."
    exit 1
fi


# ============================================================
# VALIDATE IPV4
# ============================================================

if ! [[ "${CONTROL_PLANE_IP}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo "ERROR: Invalid IPv4 address."
    exit 1
fi

IFS='.' read -r -a IP_PARTS <<< "${CONTROL_PLANE_IP}"

for PART in "${IP_PARTS[@]}"; do

    if (( PART < 0 || PART > 255 )); then
        echo "ERROR: Invalid IPv4 address."
        exit 1
    fi

done


# ============================================================
# CHECK IP EXISTS
# ============================================================

if ! ip -4 addr show | grep -qw "${CONTROL_PLANE_IP}"; then

    echo
    echo "ERROR:"
    echo "${CONTROL_PLANE_IP} is NOT assigned to this machine."
    echo
    echo "Available IPv4 addresses:"
    ip -4 addr show
    echo
    exit 1

fi

echo
echo "Control Plane IP verified:"
echo "${CONTROL_PLANE_IP}"


# ============================================================
# POD NETWORK CIDR
# ============================================================

echo
echo "[3/18] Configure Pod Network CIDR"
echo "------------------------------------------------------------"

echo
echo "Default:"
echo "  ${DEFAULT_POD_CIDR}"
echo

read -rp "Use ${DEFAULT_POD_CIDR}? (y/n): " USE_DEFAULT_CIDR

if [[ "${USE_DEFAULT_CIDR}" =~ ^[Yy]$ ]]; then

    POD_NETWORK_CIDR="${DEFAULT_POD_CIDR}"

elif [[ "${USE_DEFAULT_CIDR}" =~ ^[Nn]$ ]]; then

    read -rp "Enter Pod Network CIDR: " POD_NETWORK_CIDR

    if [ -z "${POD_NETWORK_CIDR}" ]; then
        echo "ERROR: Pod CIDR cannot be empty."
        exit 1
    fi

else

    echo "ERROR: Enter y or n."
    exit 1

fi


# ============================================================
# BASIC CIDR VALIDATION
# ============================================================

if ! [[ "${POD_NETWORK_CIDR}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[1-2][0-9]|3[0-2])$ ]]; then
    echo "ERROR: Invalid Pod Network CIDR."
    exit 1
fi


# ============================================================
# FINAL CONFIGURATION
# ============================================================

echo
echo "============================================================"
echo " Selected Configuration"
echo "============================================================"
echo
echo " Hostname          : ${CONTROL_PLANE_HOSTNAME}"
echo " Private IP        : ${CONTROL_PLANE_IP}"
echo " Kubernetes        : ${K8S_VERSION}"
echo " Kubernetes Repo   : ${K8S_MINOR_VERSION}"
echo " Pod CIDR          : ${POD_NETWORK_CIDR}"
echo " Calico            : ${CALICO_VERSION}"
echo " Ingress-NGINX     : ${INGRESS_VERSION}"
echo
echo "============================================================"
echo

read -rp "Continue? (y/n): " CONFIRM

if [[ ! "${CONFIRM}" =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 0
fi


# ============================================================
# UPDATE UBUNTU
# ============================================================

echo
echo "[4/18] Update Ubuntu"
echo "------------------------------------------------------------"

apt-get update -y
apt-get upgrade -y


# ============================================================
# DISABLE SWAP
# ============================================================

echo
echo "[5/18] Disable Swap"
echo "------------------------------------------------------------"

swapoff -a

sed -i '/^[^#].*[[:space:]]swap[[:space:]]/s/^/#/' /etc/fstab

echo
echo "Swap:"
free -h


# ============================================================
# KERNEL MODULES
# ============================================================

echo
echo "[6/18] Configure Kernel Modules"
echo "------------------------------------------------------------"

cat > /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

echo
echo "Loaded:"
lsmod | grep -E 'overlay|br_netfilter' || true


# ============================================================
# SYSCTL
# ============================================================

echo
echo "[7/18] Configure Kubernetes Networking"
echo "------------------------------------------------------------"

cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system

echo
echo "IP Forwarding:"
sysctl net.ipv4.ip_forward


# ============================================================
# PREREQUISITES
# ============================================================

echo
echo "[8/18] Install Prerequisites"
echo "------------------------------------------------------------"

apt-get install -y \
    ca-certificates \
    curl \
    gpg \
    apt-transport-https \
    conntrack \
    socat \
    ebtables \
    ethtool \
    iproute2 \
    iputils-ping \
    net-tools \
    jq \
    bash-completion


# ============================================================
# CONTAINERD
# ============================================================

echo
echo "[9/18] Install Containerd"
echo "------------------------------------------------------------"

apt-get install -y containerd

mkdir -p /etc/containerd

containerd config default > /etc/containerd/config.toml

sed -i \
    's/SystemdCgroup = false/SystemdCgroup = true/' \
    /etc/containerd/config.toml

systemctl daemon-reload

systemctl enable containerd

systemctl restart containerd

echo
echo "Containerd status:"
systemctl is-active containerd

echo
echo "Containerd enabled:"
systemctl is-enabled containerd


# ============================================================
# KUBERNETES REPOSITORY
# ============================================================

echo
echo "[10/18] Configure Kubernetes Repository"
echo "------------------------------------------------------------"

mkdir -p -m 755 /etc/apt/keyrings

rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg

curl -fsSL \
    "https://pkgs.k8s.io/core:/stable:/${K8S_MINOR_VERSION}/deb/Release.key" \
    | gpg --dearmor --yes \
    -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

cat > /etc/apt/sources.list.d/kubernetes.list <<EOF
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_MINOR_VERSION}/deb/ /
EOF

apt-get update -y


# ============================================================
# INSTALL KUBERNETES
# ============================================================

echo
echo "[11/18] Install Kubernetes"
echo "------------------------------------------------------------"

apt-get install -y \
    kubelet="${K8S_VERSION}-*" \
    kubeadm="${K8S_VERSION}-*" \
    kubectl="${K8S_VERSION}-*"

apt-mark hold kubelet kubeadm kubectl

systemctl enable kubelet

echo
echo "Kubernetes versions:"
echo

kubeadm version

echo

kubectl version --client

echo

kubelet --version


# ============================================================
# PRE-CHECK
# ============================================================

echo
echo "[12/18] Kubernetes Pre-Checks"
echo "------------------------------------------------------------"

echo
echo "Container Runtime:"
crictl --version 2>/dev/null || true

echo
echo "Hostname:"
hostname

echo
echo "Private IP:"
ip -4 addr show

echo
echo "Swap:"
swapon --show

echo
echo "CRI socket:"
ls -l /run/containerd/containerd.sock


# ============================================================
# KUBEADM INIT
# ============================================================

echo
echo "[13/18] Initialize Kubernetes Control Plane"
echo "------------------------------------------------------------"

kubeadm init \
    --apiserver-advertise-address="${CONTROL_PLANE_IP}" \
    --pod-network-cidr="${POD_NETWORK_CIDR}" \
    --cri-socket=unix:///run/containerd/containerd.sock


# ============================================================
# KUBECTL CONFIGURATION
# ============================================================

echo
echo "[14/18] Configure kubectl"
echo "------------------------------------------------------------"

mkdir -p /root/.kube

cp -f /etc/kubernetes/admin.conf /root/.kube/config

chown root:root /root/.kube/config

export KUBECONFIG=/etc/kubernetes/admin.conf

echo
echo "Cluster:"
kubectl cluster-info

echo
echo "Nodes:"
kubectl get nodes


# ============================================================
# CALICO CRDs
# ============================================================

echo
echo "[15/18] Install Tigera Operator + Calico"
echo "------------------------------------------------------------"

echo
echo "Installing Calico CRDs..."

kubectl create -f \
    "${CALICO_BASE_URL}/v1_crd_projectcalico_org.yaml"


# ============================================================
# TIGERA OPERATOR
# ============================================================

echo
echo "Installing Tigera Operator..."

kubectl create -f \
    "${CALICO_BASE_URL}/tigera-operator.yaml"


echo
echo "Waiting for Tigera Operator..."

kubectl wait \
    --namespace tigera-operator \
    --for=condition=Available \
    deployment/tigera-operator \
    --timeout=180s


# ============================================================
# CALICO CUSTOM RESOURCES
# ============================================================

echo
echo "Installing Calico Custom Resources..."

TEMP_CALICO_FILE="/tmp/calico-custom-resources.yaml"

curl -fsSL \
    "${CALICO_BASE_URL}/custom-resources.yaml" \
    -o "${TEMP_CALICO_FILE}"


# ------------------------------------------------------------
# Replace default Calico CIDR with selected Pod CIDR
# ------------------------------------------------------------

sed -i \
    -E "s#cidr: [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+#cidr: ${POD_NETWORK_CIDR}#g" \
    "${TEMP_CALICO_FILE"


# ------------------------------------------------------------
# Install
# ------------------------------------------------------------

kubectl create -f "${TEMP_CALICO_FILE}"

rm -f "${TEMP_CALICO_FILE}"


# ============================================================
# WAIT FOR CALICO
# ============================================================

echo
echo "Waiting for Calico components..."

sleep 20

echo
echo "Tigera Operator:"
kubectl get pods -n tigera-operator

echo
echo "Calico:"
kubectl get pods -n calico-system

echo
echo "Tigera Status:"
kubectl get tigerastatus


# ============================================================
# WAIT FOR CALICO NODE
# ============================================================

echo
echo "Waiting for Calico node..."

for i in {1..30}; do

    if kubectl get pods \
        -n calico-system \
        -l k8s-app=calico-node \
        --no-headers 2>/dev/null \
        | grep -q "Running"; then

        echo "Calico node is running."
        break
    fi

    echo "Waiting... ${i}/30"
    sleep 10

done


# ============================================================
# REMOVE CONTROL PLANE TAINT
# ============================================================

echo
echo "Removing control-plane taint for single-node testing..."

kubectl taint nodes \
    "${CONTROL_PLANE_HOSTNAME}" \
    node-role.kubernetes.io/control-plane:NoSchedule- \
    2>/dev/null || true


# ============================================================
# INSTALL INGRESS-NGINX
# ============================================================

echo
echo "[16/18] Install Ingress-NGINX"
echo "------------------------------------------------------------"

echo
echo "Installing Ingress-NGINX ${INGRESS_VERSION}..."

kubectl apply -f "${INGRESS_URL}"


# ============================================================
# WAIT FOR INGRESS
# ============================================================

echo
echo "Waiting for Ingress-NGINX controller..."

kubectl wait \
    --namespace ingress-nginx \
    --for=condition=ready \
    pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=300s


# ============================================================
# INGRESS STATUS
# ============================================================

echo
echo "Ingress-NGINX Pods:"
kubectl get pods -n ingress-nginx

echo
echo "Ingress-NGINX Service:"
kubectl get svc -n ingress-nginx


# ============================================================
# FINAL CLUSTER CHECK
# ============================================================

echo
echo "[17/18] Final Cluster Verification"
echo "------------------------------------------------------------"

echo
echo "============================================================"
echo " NODES"
echo "============================================================"

kubectl get nodes -o wide


echo
echo "============================================================"
echo " ALL PODS"
echo "============================================================"

kubectl get pods -A


echo
echo "============================================================"
echo " TIGERA STATUS"
echo "============================================================"

kubectl get tigerastatus


echo
echo "============================================================"
echo " CALICO NODES"
echo "============================================================"

kubectl get pods -n calico-system -o wide


echo
echo "============================================================"
echo " INGRESS"
echo "============================================================"

kubectl get pods -n ingress-nginx

echo

kubectl get svc -n ingress-nginx


# ============================================================
# WORKER JOIN COMMAND
# ============================================================

echo
echo "[18/18] Generate Worker Join Command"
echo "------------------------------------------------------------"

echo
echo "============================================================"
echo " WORKER NODE JOIN COMMAND"
echo "============================================================"
echo

kubeadm token create --print-join-command

echo
echo "============================================================"


# ============================================================
# FINAL INFORMATION
# ============================================================

echo
echo
echo "============================================================"
echo " INSTALLATION COMPLETED"
echo "============================================================"
echo
echo "Hostname          : ${CONTROL_PLANE_HOSTNAME}"
echo "Private IP        : ${CONTROL_PLANE_IP}"
echo "Kubernetes        : ${K8S_VERSION}"
echo "Container Runtime : containerd"
echo "Calico            : ${CALICO_VERSION}"
echo "Pod CIDR          : ${POD_NETWORK_CIDR}"
echo "Ingress-NGINX     : ${INGRESS_VERSION}"
echo
echo "============================================================"
echo " USEFUL COMMANDS"
echo "============================================================"
echo
echo "kubectl get nodes -o wide"
echo "kubectl get pods -A"
echo "kubectl get svc -A"
echo "kubectl get tigerastatus"
echo "kubectl get pods -n calico-system"
echo "kubectl get pods -n ingress-nginx"
echo "kubectl get svc -n ingress-nginx"
echo
echo "============================================================"
echo " INGRESS NODEPORT"
echo "============================================================"
echo
echo "Run:"
echo
echo "kubectl get svc ingress-nginx-controller -n ingress-nginx"
echo
echo "Use the displayed HTTP/HTTPS NodePort in your"
echo "AWS EC2 Security Group."
echo
echo "============================================================"
echo " DONE"
echo "============================================================"

