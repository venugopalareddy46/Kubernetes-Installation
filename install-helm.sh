#!/bin/bash

# =========================================================
# Helm 4 Installation
# Kubernetes Package Manager
# =========================================================

set -e

echo "========================================================="
echo " Helm Installation"
echo "========================================================="


# =========================================================
# 1. UPDATE PACKAGE INDEX
# =========================================================

echo "[1/6] Updating package index..."

sudo apt update -y


# =========================================================
# 2. INSTALL REQUIRED PACKAGES
# =========================================================

echo "[2/6] Installing required packages..."

sudo apt install -y \
curl \
ca-certificates


# =========================================================
# 3. DOWNLOAD OFFICIAL HELM INSTALLER
# =========================================================

echo "[3/6] Downloading official Helm installer..."

curl -fsSL \
-o /tmp/get_helm.sh \
https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4

chmod 700 /tmp/get_helm.sh


# =========================================================
# 4. INSTALL HELM
# =========================================================

echo "[4/6] Installing Helm..."

/tmp/get_helm.sh


# =========================================================
# 5. REMOVE INSTALLER
# =========================================================

echo "[5/6] Removing temporary installer..."

rm -f /tmp/get_helm.sh


# =========================================================
# 6. VERIFY HELM
# =========================================================

echo "[6/6] Verifying Helm installation..."

echo ""
echo "Helm version:"
helm version

echo ""
echo "Helm binary:"
which helm

echo ""
echo "========================================================="
echo " Helm Installation Completed Successfully"
echo "========================================================="