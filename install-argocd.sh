#!/bin/bash

# =========================================================
# Argo CD Installation
# GitOps Continuous Delivery
# =========================================================

set -e

ARGOCD_NAMESPACE="argocd"
ARGOCD_MANIFEST="https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"

echo "========================================================="
echo " Argo CD Installation"
echo " Namespace : ${ARGOCD_NAMESPACE}"
echo "========================================================="


# =========================================================
# 1. VERIFY KUBERNETES CLUSTER
# =========================================================

echo "[1/8] Checking Kubernetes cluster..."

kubectl cluster-info

echo ""
kubectl get nodes -o wide


# =========================================================
# 2. CREATE ARGO CD NAMESPACE
# =========================================================

echo ""
echo "[2/8] Creating Argo CD namespace..."

kubectl create namespace "${ARGOCD_NAMESPACE}" \
2>/dev/null || true


# =========================================================
# 3. INSTALL ARGO CD
# =========================================================

echo ""
echo "[3/8] Installing Argo CD..."

kubectl apply \
-n "${ARGOCD_NAMESPACE}" \
-f "${ARGOCD_MANIFEST}"


# =========================================================
# 4. WAIT FOR ARGO CD SERVER
# =========================================================

echo ""
echo "[4/8] Waiting for Argo CD server..."

kubectl rollout status \
deployment/argocd-server \
-n "${ARGOCD_NAMESPACE}" \
--timeout=300s


# =========================================================
# 5. CHECK ARGO CD PODS
# =========================================================

echo ""
echo "[5/8] Checking Argo CD pods..."

kubectl get pods \
-n "${ARGOCD_NAMESPACE}" \
-o wide


# =========================================================
# 6. CHECK ARGO CD SERVICES
# =========================================================

echo ""
echo "[6/8] Checking Argo CD services..."

kubectl get svc \
-n "${ARGOCD_NAMESPACE}"


# =========================================================
# 7. GET INITIAL ADMIN PASSWORD
# =========================================================

echo ""
echo "[7/8] Retrieving initial admin password..."

echo ""

if kubectl get secret \
-n "${ARGOCD_NAMESPACE}" \
argocd-initial-admin-secret \
>/dev/null 2>&1; then

    kubectl get secret \
    -n "${ARGOCD_NAMESPACE}" \
    argocd-initial-admin-secret \
    -o jsonpath="{.data.password}" | base64 -d

    echo ""

else

    echo "Initial admin secret is not available yet."
    echo "Check:"
    echo ""
    echo "kubectl get secret -n argocd"
fi


# =========================================================
# 8. FINAL STATUS
# =========================================================

echo ""
echo "========================================================="
echo " Argo CD Installation Completed"
echo "========================================================="

echo ""
echo "Namespace:"
kubectl get namespace "${ARGOCD_NAMESPACE}"

echo ""
echo "Pods:"
kubectl get pods -n "${ARGOCD_NAMESPACE}"

echo ""
echo "Services:"
kubectl get svc -n "${ARGOCD_NAMESPACE}"

echo ""
echo "========================================================="
echo " Access Argo CD"
echo "========================================================="

echo ""
echo "Run:"
echo ""
echo "kubectl port-forward -n argocd svc/argocd-server 8080:443"
echo ""
echo "Then open:"
echo ""
echo "https://localhost:8080"
echo ""
echo "Username:"
echo "admin"
echo ""
echo "========================================================="