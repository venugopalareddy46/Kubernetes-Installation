
#!/bin/bash

# ============================================================
# COMPLETE KUBERNETES WORKER NODE INSTALLATION
# ============================================================
#
# Ubuntu EC2
#
# Kubernetes       : v1.36.4
# Containerd       : v2.4.0
# runc             : v1.5.1
# CNI Plugins      : v1.9.1
# Calico Cluster   : v3.32.2
#
# ROOT ONLY
# NO SUDO REQUIRED
#
# ============================================================

set -euo pipefail


# ============================================================
# VERSION CONFIGURATION
# ============================================================

K8S_MINOR_VERSION="v1.36"
K8S_VERSION="1.36.4"

CONTAINERD_VERSION="2.4.0"
RUNC_VERSION="1.5.1"
CNI_VERSION="1.9.1"

DEFAULT_HOSTNAME="worker-node-1"
DEFAULT_POD_CIDR="192.168.0.0/16"


# ============================================================
# ROOT CHECK
# ============================================================

if [ "$(id -u)" -ne 0 ]; then

    echo
    echo "ERROR: This script must be run as ROOT."
    echo
    echo "Run:"
    echo
    echo "  su -"
    echo "  bash install-worker.sh"
    echo

    exit 1

fi


# ============================================================
# HEADER
# ============================================================

clear

echo
echo "============================================================"
echo " Kubernetes Worker Node Installation"
echo "============================================================"
echo
echo " Kubernetes       : ${K8S_VERSION}"
echo " Containerd       : ${CONTAINERD_VERSION}"
echo " runc             : ${RUNC_VERSION}"
echo " CNI Plugins      : ${CNI_VERSION}"
echo " Calico           : v3.32.2"
echo " Pod CIDR         : ${DEFAULT_POD_CIDR}"
echo
echo " ROOT ONLY"
echo " NO SUDO REQUIRED"
echo
echo "============================================================"
echo


# ============================================================
# 1. WORKER HOSTNAME
# ============================================================

echo
echo "[1/16] Configure Worker Hostname"
echo "------------------------------------------------------------"

read -rp \
"Enter Worker Hostname [${DEFAULT_HOSTNAME}]: " \
WORKER_HOSTNAME

WORKER_HOSTNAME="${WORKER_HOSTNAME:-${DEFAULT_HOSTNAME}}"


# ============================================================
# HOSTNAME VALIDATION
# ============================================================

if ! [[ "${WORKER_HOSTNAME}" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ ]]; then

    echo
    echo "ERROR: Invalid hostname."
    echo
    echo "Example:"
    echo "  worker-node-1"
    echo "  worker-node-2"
    echo

    exit 1

fi


hostnamectl set-hostname "${WORKER_HOSTNAME}"

echo
echo "Worker hostname:"
hostname


# ============================================================
# 2. DETECT WORKER PRIVATE IP
# ============================================================

echo
echo "[2/16] Detect Worker Private IP"
echo "------------------------------------------------------------"

DETECTED_WORKER_IP=""

DETECTED_WORKER_IP=$(ip -4 route get 1.1.1.1 2>/dev/null \
    | awk '
        {
            for(i=1;i<=NF;i++)
                if($i=="src")
                    print $(i+1)
        }
    ' \
    | head -1)


if [ -z "${DETECTED_WORKER_IP}" ]; then

    DETECTED_WORKER_IP=$(hostname -I \
        | awk '{print $1}')

fi


if [ -z "${DETECTED_WORKER_IP}" ]; then

    echo
    echo "ERROR: Could not detect Worker private IP."
    echo
    ip -4 addr show
    exit 1

fi


echo
echo "Detected Worker Private IP:"
echo
echo "  ${DETECTED_WORKER_IP}"
echo


read -rp \
"Use this IP? (y/n): " USE_DETECTED_IP


if [[ "${USE_DETECTED_IP}" =~ ^[Yy]$ ]]; then

    WORKER_IP="${DETECTED_WORKER_IP}"

elif [[ "${USE_DETECTED_IP}" =~ ^[Nn]$ ]]; then

    read -rp "Enter Worker Private IP: " WORKER_IP

else

    echo "ERROR: Enter y or n."
    exit 1

fi


# ============================================================
# IP VALIDATION
# ============================================================

if ! [[ "${WORKER_IP}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then

    echo
    echo "ERROR: Invalid IPv4 address."
    exit 1

fi


IFS='.' read -r -a IP_PARTS <<< "${WORKER_IP}"

for PART in "${IP_PARTS[@]}"; do

    if (( PART < 0 || PART > 255 )); then

        echo
        echo "ERROR: Invalid IPv4 address:"
        echo "${WORKER_IP}"
        exit 1

    fi

done


if ! ip -4 addr show | grep -qw "${WORKER_IP}"; then

    echo
    echo "ERROR:"
    echo "${WORKER_IP} is not assigned to this Worker."
    echo
    ip -4 addr show

    exit 1

fi


echo
echo "Worker IP verified:"
echo "${WORKER_IP}"


# ============================================================
# 3. POD NETWORK CIDR
# ============================================================

echo
echo "[3/16] Configure Pod Network CIDR"
echo "------------------------------------------------------------"

echo
echo "The Worker does NOT create the Pod CIDR."
echo
echo "It must match the Control Plane configuration."
echo
echo "Default:"
echo
echo "  ${DEFAULT_POD_CIDR}"
echo

read -rp \
"Use ${DEFAULT_POD_CIDR}? (y/n): " USE_DEFAULT_CIDR


if [[ "${USE_DEFAULT_CIDR}" =~ ^[Yy]$ ]]; then

    POD_NETWORK_CIDR="${DEFAULT_POD_CIDR}"

elif [[ "${USE_DEFAULT_CIDR}" =~ ^[Nn]$ ]]; then

    read -rp \
    "Enter Control Plane Pod Network CIDR: " \
    POD_NETWORK_CIDR

else

    echo "ERROR: Enter y or n."
    exit 1

fi


if ! [[ "${POD_NETWORK_CIDR}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[1-2][0-9]|3[0-2])$ ]]; then

    echo
    echo "ERROR: Invalid Pod Network CIDR."
    echo
    exit 1

fi


# ============================================================
# 4. CONTROL PLANE ENDPOINT
# ============================================================

echo
echo "[4/16] Configure Control Plane"
echo "------------------------------------------------------------"

echo
echo "Example:"
echo
echo "  10.0.1.10:6443"
echo

read -rp \
"Enter Control Plane API Server endpoint: " \
CONTROL_PLANE_ENDPOINT


if [ -z "${CONTROL_PLANE_ENDPOINT}" ]; then

    echo
    echo "ERROR: Control Plane endpoint cannot be empty."
    exit 1

fi


# ============================================================
# EXTRACT CONTROL PLANE HOST AND PORT
# ============================================================

CONTROL_PLANE_HOST="${CONTROL_PLANE_ENDPOINT%:*}"
CONTROL_PLANE_PORT="${CONTROL_PLANE_ENDPOINT##*:}"


if [ -z "${CONTROL_PLANE_PORT}" ]; then
    CONTROL_PLANE_PORT="6443"
fi


echo
echo "Control Plane:"
echo "  ${CONTROL_PLANE_HOST}:${CONTROL_PLANE_PORT}"


# ============================================================
# 5. SHOW CONFIGURATION
# ============================================================

echo
echo "============================================================"
echo " Worker Configuration"
echo "============================================================"
echo
echo " Hostname          : ${WORKER_HOSTNAME}"
echo " Private IP        : ${WORKER_IP}"
echo " Control Plane     : ${CONTROL_PLANE_ENDPOINT}"
echo " Kubernetes        : ${K8S_VERSION}"
echo " Containerd        : ${CONTAINERD_VERSION}"
echo " runc              : ${RUNC_VERSION}"
echo " CNI Plugins       : ${CNI_VERSION}"
echo " Pod CIDR          : ${POD_NETWORK_CIDR}"
echo
echo "============================================================"
echo

read -rp "Continue? (y/n): " CONFIRM


if [[ ! "${CONFIRM}" =~ ^[Yy]$ ]]; then

    echo
    echo "Installation cancelled."
    exit 0

fi


# ============================================================
# 6. UPDATE UBUNTU
# ============================================================

echo
echo "[6/16] Update Ubuntu"
echo "------------------------------------------------------------"

apt-get update -y
apt-get upgrade -y


# ============================================================
# 7. DISABLE SWAP
# ============================================================

echo
echo "[7/16] Disable Swap"
echo "------------------------------------------------------------"

swapoff -a

sed -i \
    '/^[^#].*[[:space:]]swap[[:space:]]/s/^/#/' \
    /etc/fstab


echo
echo "Swap:"
swapon --show || true


# ============================================================
# 8. KERNEL MODULES
# ============================================================

echo
echo "[8/16] Configure Kernel Modules"
echo "------------------------------------------------------------"

cat > /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF


modprobe overlay
modprobe br_netfilter


echo
echo "Kernel modules:"
lsmod | grep -E 'overlay|br_netfilter' || true


# ============================================================
# 9. KUBERNETES NETWORKING
# ============================================================

echo
echo "[9/16] Configure Kubernetes Networking"
echo "------------------------------------------------------------"

cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF


sysctl --system


echo
echo "IP forwarding:"
sysctl net.ipv4.ip_forward


# ============================================================
# 10. INSTALL PREREQUISITES
# ============================================================

echo
echo "[10/16] Install Prerequisites"
echo "------------------------------------------------------------"

apt-get install -y \
    ca-certificates \
    curl \
    wget \
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
    bash-completion \
    netcat-openbsd \
    tar


# ============================================================
# 11. INSTALL CONTAINERD
# ============================================================

echo
echo "[11/16] Install Containerd ${CONTAINERD_VERSION}"
echo "------------------------------------------------------------"


ARCH="$(dpkg --print-architecture)"

if [ "${ARCH}" != "amd64" ]; then

    echo
    echo "This script is currently configured for amd64 EC2."
    echo
    echo "Detected architecture:"
    echo "${ARCH}"
    echo

    exit 1

fi


# ------------------------------------------------------------
# Remove old containerd package if present
# ------------------------------------------------------------

apt-get remove -y \
    containerd \
    containerd.io \
    2>/dev/null || true


# ------------------------------------------------------------
# Download containerd
# ------------------------------------------------------------

cd /tmp

CONTAINERD_TARBALL="containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz"

wget -q \
    "https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/${CONTAINERD_TARBALL}" \
    -O "${CONTAINERD_TARBALL}"


# ------------------------------------------------------------
# Install containerd binaries
# ------------------------------------------------------------

rm -rf /usr/local/bin/containerd \
       /usr/local/bin/ctr \
       /usr/local/bin/containerd-shim* \
       /usr/local/bin/containerd-stress

tar -C /usr/local -xzf "${CONTAINERD_TARBALL}"


# ============================================================
# CONTAINERD SYSTEMD SERVICE
# ============================================================

mkdir -p /usr/local/lib/systemd/system

curl -fsSL \
    "https://raw.githubusercontent.com/containerd/containerd/v${CONTAINERD_VERSION}/containerd.service" \
    -o /usr/local/lib/systemd/system/containerd.service


# ============================================================
# 12. INSTALL RUNC
# ============================================================

echo
echo "[12/16] Install runc ${RUNC_VERSION}"
echo "------------------------------------------------------------"

RUNC_BINARY="runc.amd64"

wget -q \
    "https://github.com/opencontainers/runc/releases/download/v${RUNC_VERSION}/${RUNC_BINARY}" \
    -O /usr/local/sbin/runc


chmod +x /usr/local/sbin/runc


# ============================================================
# INSTALL CNI PLUGINS
# ============================================================

echo
echo "Installing CNI Plugins ${CNI_VERSION}..."

mkdir -p /opt/cni/bin

CNI_TARBALL="cni-plugins-linux-amd64-v${CNI_VERSION}.tgz"

wget -q \
    "https://github.com/containernetworking/plugins/releases/download/v${CNI_VERSION}/${CNI_TARBALL}" \
    -O "/tmp/${CNI_TARBALL}"


tar -C /opt/cni/bin \
    -xzf "/tmp/${CNI_TARBALL}"


# ============================================================
# CONTAINERD CONFIGURATION
# ============================================================

echo
echo "Configuring containerd..."

mkdir -p /etc/containerd

/usr/local/bin/containerd config default \
    > /etc/containerd/config.toml


# ------------------------------------------------------------
# Enable systemd cgroups
# ------------------------------------------------------------

sed -i \
    's/SystemdCgroup = false/SystemdCgroup = true/' \
    /etc/containerd/config.toml


# ------------------------------------------------------------
# Configure CRI sandbox image
# ------------------------------------------------------------

if grep -q 'sandbox_image' /etc/containerd/config.toml; then

    sed -i \
        's#sandbox_image = .*#sandbox_image = "registry.k8s.io/pause:3.10"#' \
        /etc/containerd/config.toml

fi


# ============================================================
# START CONTAINERD
# ============================================================

systemctl daemon-reload

systemctl enable containerd

systemctl restart containerd


echo
echo "Containerd:"
systemctl is-active containerd

echo
echo "Containerd enabled:"
systemctl is-enabled containerd


# ============================================================
# CONTAINERD VERSION
# ============================================================

echo
echo "Containerd version:"
/usr/local/bin/containerd --version


echo
echo "runc version:"
/usr/local/sbin/runc --version | head -1


# ============================================================
# 13. INSTALL CRICTL
# ============================================================

echo
echo "[13/16] Install crictl"
echo "------------------------------------------------------------"

CRICTL_VERSION="v1.34.0"

cd /tmp

CRICTL_TARBALL="crictl-${CRICTL_VERSION}-linux-amd64.tar.gz"

wget -q \
    "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/${CRICTL_TARBALL}" \
    -O "${CRICTL_TARBALL}"


tar -C /usr/local/bin \
    -xzf "${CRICTL_TARBALL}"


chmod +x /usr/local/bin/crictl


cat > /etc/crictl.yaml <<EOF
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF


echo
echo "crictl:"
crictl --version


# ============================================================
# 14. KUBERNETES REPOSITORY
# ============================================================

echo
echo "[14/16] Configure Kubernetes Repository"
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
# INSTALL EXACT KUBERNETES VERSION
# ============================================================

echo
echo "Installing Kubernetes ${K8S_VERSION}..."

KUBE_PACKAGE_VERSION="1.36.4-1.1"


apt-get install -y \
    kubelet="${KUBE_PACKAGE_VERSION}" \
    kubeadm="${KUBE_PACKAGE_VERSION}" \
    kubectl="${KUBE_PACKAGE_VERSION}"


apt-mark hold kubelet kubeadm kubectl


systemctl enable kubelet


echo
echo "kubeadm:"
kubeadm version


echo
echo "kubectl:"
kubectl version --client


echo
echo "kubelet:"
kubelet --version


# ============================================================
# 15. NETWORK CONNECTIVITY CHECK
# ============================================================

echo
echo "[15/16] Check Control Plane Connectivity"
echo "------------------------------------------------------------"

echo
echo "Testing:"
echo
echo "  ${CONTROL_PLANE_HOST}:${CONTROL_PLANE_PORT}"
echo


if nc -z -w 5 \
    "${CONTROL_PLANE_HOST}" \
    "${CONTROL_PLANE_PORT}"; then

    echo
    echo "SUCCESS:"
    echo "Kubernetes API Server is reachable."

else

    echo
    echo "ERROR:"
    echo "Cannot reach Kubernetes API Server."
    echo
    echo "Check:"
    echo
    echo "1. Control Plane is running"
    echo "2. AWS Security Group allows TCP 6443"
    echo "3. Worker and Control Plane are in reachable networks"
    echo "4. Control Plane private IP is correct"
    echo
    exit 1

fi


# ============================================================
# KUBELET PRE-JOIN
# ============================================================

echo
echo "Kubelet status before join:"
systemctl is-active kubelet || true


# ============================================================
# 16. KUBEADM JOIN
# ============================================================

echo
echo "[16/16] Join Worker to Kubernetes Cluster"
echo "------------------------------------------------------------"

echo
echo "Generate the join command on the Control Plane:"
echo
echo "  kubeadm token create --print-join-command"
echo
echo "Example:"
echo
echo "  kubeadm join 10.0.1.10:6443 \\"
echo "    --token <TOKEN> \\"
echo "    --discovery-token-ca-cert-hash sha256:<HASH>"
echo
echo "============================================================"
echo


read -r -p "Paste complete kubeadm join command: " JOIN_COMMAND


if [ -z "${JOIN_COMMAND}" ]; then

    echo
    echo "ERROR: Join command cannot be empty."
    exit 1

fi


# ============================================================
# VALIDATE JOIN COMMAND
# ============================================================

if [[ "${JOIN_COMMAND}" != *"kubeadm join"* ]]; then

    echo
    echo "ERROR: Invalid kubeadm join command."
    echo
    echo "The command must contain:"
    echo
    echo "  kubeadm join"
    echo

    exit 1

fi


# ============================================================
# REMOVE POSSIBLE SUDO
# ============================================================

JOIN_COMMAND="${JOIN_COMMAND#sudo }"


# ============================================================
# SHOW JOIN COMMAND
# ============================================================

echo
echo "============================================================"
echo " Join Configuration"
echo "============================================================"
echo
echo "Worker:"
echo "  ${WORKER_HOSTNAME}"
echo
echo "Private IP:"
echo "  ${WORKER_IP}"
echo
echo "Kubernetes:"
echo "  ${K8S_VERSION}"
echo
echo "Control Plane:"
echo "  ${CONTROL_PLANE_ENDPOINT}"
echo
echo "============================================================"
echo


read -rp "Join this Worker? (y/n): " CONFIRM_JOIN


if [[ ! "${CONFIRM_JOIN}" =~ ^[Yy]$ ]]; then

    echo
    echo "Worker join cancelled."
    exit 0

fi


# ============================================================
# EXECUTE JOIN
# ============================================================

echo
echo "Executing kubeadm join..."
echo


eval "${JOIN_COMMAND}"


# ============================================================
# WAIT FOR KUBELET
# ============================================================

echo
echo "Waiting for kubelet..."

sleep 10


systemctl enable kubelet

systemctl restart kubelet


# ============================================================
# KUBELET STATUS
# ============================================================

echo
echo "============================================================"
echo " Kubelet Status"
echo "============================================================"
echo

systemctl is-active kubelet

echo

systemctl is-enabled kubelet


# ============================================================
# CRICTL TEST
# ============================================================

echo
echo "============================================================"
echo " Container Runtime Test"
echo "============================================================"
echo

crictl info >/dev/null

echo "CRI runtime is working."


# ============================================================
# LOCAL WORKER CHECK
# ============================================================

echo
echo "============================================================"
echo " Worker Information"
echo "============================================================"
echo

echo "Hostname:"
hostname

echo

echo "Private IP:"
ip -4 addr show

echo

echo "Kubernetes:"
kubelet --version

echo

echo "Containerd:"
/usr/local/bin/containerd --version

echo

echo "runc:"
/usr/local/sbin/runc --version | head -1


# ============================================================
# FINAL MESSAGE
# ============================================================

echo
echo
echo "============================================================"
echo " WORKER NODE INSTALLATION COMPLETED"
echo "============================================================"
echo
echo " Worker Hostname   : ${WORKER_HOSTNAME}"
echo " Worker Private IP : ${WORKER_IP}"
echo " Kubernetes        : ${K8S_VERSION}"
echo " Containerd        : ${CONTAINERD_VERSION}"
echo " runc              : ${RUNC_VERSION}"
echo " CNI Plugins       : ${CNI_VERSION}"
echo " Pod Network CIDR  : ${POD_NETWORK_CIDR}"
echo
echo "============================================================"
echo " VERIFY FROM CONTROL PLANE"
echo "============================================================"
echo
echo "Run:"
echo
echo "  kubectl get nodes -o wide"
echo
echo "Then:"
echo
echo "  kubectl get pods -A"
echo
echo "Expected Worker status:"
echo
echo "  Ready"
echo
echo "============================================================"
echo " DONE"
echo "============================================================"

