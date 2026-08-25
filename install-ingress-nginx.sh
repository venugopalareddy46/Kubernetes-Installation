#!/bin/bash

# =========================================================
# Kubernetes Ingress-NGINX Controller Installation
# Kubernetes v1.36
# =========================================================

set -e

INGRESS_VERSION="controller-v1.15.1"
INGRESS_NAMESPACE="ingress-nginx"

echo "========================================================="
echo " Ingress-NGINX Controller Installation"
echo " Version : ${INGRESS_VERSION}"
echo " Namespace : ${INGRESS_NAMESPACE}"
echo "========================================================="


# =========================================================
# 1. VERIFY KUBERNETES CLUSTER
# =========================================================

echo "[1/8] Checking Kubernetes cluster..."

kubectl cluster-info

echo ""
kubectl get nodes -o wide


# =========================================================
# 2. CHECK EXISTING INGRESS-NGINX INSTALLATION
# =========================================================

echo ""
echo "[2/8] Checking existing Ingress installation..."

if kubectl get namespace "${INGRESS_NAMESPACE}" >/dev/null 2>&1; then
    echo "Namespace ${INGRESS_NAMESPACE} already exists."
else
    echo "Namespace ${INGRESS_NAMESPACE} does not exist."
fi


# =========================================================
# 3. INSTALL INGRESS-NGINX
# =========================================================

echo ""
echo "[3/8] Installing Ingress-NGINX..."

kubectl apply -f \
"https://raw.githubusercontent.com/kubernetes/ingress-nginx/${INGRESS_VERSION}/deploy/static/provider/cloud/deploy.yaml"


# =========================================================
# 4. WAIT FOR INGRESS CONTROLLER
# =========================================================

echo ""
echo "[4/8] Waiting for Ingress-NGINX controller..."

kubectl wait \
--namespace "${INGRESS_NAMESPACE}" \
--for=condition=Ready \
pod \
--selector=app.kubernetes.io/component=controller \
--timeout=180s


# =========================================================
# 5. VERIFY PODS
# =========================================================

echo ""
echo "[5/8] Checking Ingress-NGINX pods..."

kubectl get pods \
-n "${INGRESS_NAMESPACE}" \
-o wide


# =========================================================
# 6. VERIFY SERVICES
# =========================================================

echo ""
echo "[6/8] Checking Ingress-NGINX services..."

kubectl get svc \
-n "${INGRESS_NAMESPACE}" \
-o wide


# =========================================================
# 7. VERIFY INGRESS CLASS
# =========================================================

echo ""
echo "[7/8] Checking IngressClass..."

kubectl get ingressclass


# =========================================================
# 8. FINAL STATUS
# =========================================================

echo ""
echo "========================================================="
echo " Ingress-NGINX Installation Completed"
echo "========================================================="

echo ""
echo "Namespace:"
kubectl get namespace "${INGRESS_NAMESPACE}"

echo ""
echo "Controller:"
kubectl get deployment \
-n "${INGRESS_NAMESPACE}"

echo ""
echo "Pods:"
kubectl get pods \
-n "${INGRESS_NAMESPACE}"

echo ""
echo "Services:"
kubectl get svc \
-n "${INGRESS_NAMESPACE}"

echo ""
echo "IngressClass:"
kubectl get ingressclass

echo ""
echo "========================================================="
echo " Ingress-NGINX Ready"
echo "========================================================="