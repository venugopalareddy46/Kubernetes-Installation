#!/bin/bash

# =========================================================
# Helm 3 Installation
# Kubernetes Package Manager
# =========================================================

set -e

echo "========================================================="
echo " Helm 3 Installation"
echo "========================================================="


# =========================================================
# 1. UPDATE PACKAGE INDEX
# =========================================================

echo "[1/7] Updating package index..."

sudo apt update -y


# =========================================================
# 2. INSTALL REQUIRED PACKAGES
# =========================================================

echo "[2/7] Installing required packages..."

sudo apt install -y \
curl \
ca-certificates


# =========================================================
# 3. REMOVE EXISTING HELM
# =========================================================

echo "[3/7] Removing existing Helm installation..."

sudo rm -f /usr/local/bin/helm
sudo rm -f /usr/bin/helm


# =========================================================
# 4. DOWNLOAD OFFICIAL HELM 3 INSTALLER
# =========================================================

echo "[4/7] Downloading official Helm 3 installer..."

curl -fsSL \
-o /tmp/get_helm-3.sh \
https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3

chmod 700 /tmp/get_helm-3.sh


# =========================================================
# 5. INSTALL HELM 3
# =========================================================

echo "[5/7] Installing Helm 3..."

/tmp/get_helm-3.sh


# =========================================================
# 6. CLEAN INSTALLER
# =========================================================

echo "[6/7] Removing temporary files..."

rm -f /tmp/get_helm-3.sh


# =========================================================
# 7. VERIFY HELM
# =========================================================

echo "[7/7] Verifying Helm..."

echo ""
echo "Helm version:"
helm version

echo ""
echo "Helm location:"
command -v helm

echo ""
echo "========================================================="
echo " Helm 3 Installation Completed"
echo "========================================================="