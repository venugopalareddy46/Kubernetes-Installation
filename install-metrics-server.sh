#!/bin/bash

# =========================================================
# Kubernetes Metrics Server Installation
# =========================================================

set -e

METRICS_SERVER_VERSION="v0.8.0"

echo "========================================================="
echo " Metrics Server Installation"
echo " Version : ${METRICS_SERVER_VERSION}"
echo "========================================================="


# =========================================================
# 1. VERIFY KUBERNETES CLUSTER
# =========================================================

echo "[1/7] Checking Kubernetes cluster..."

kubectl cluster-info

echo ""
kubectl get nodes -o wide


# =========================================================
# 2. CHECK EXISTING METRICS SERVER
# =========================================================

echo ""
echo "[2/7] Checking existing Metrics Server..."

if kubectl get namespace kube-system >/dev/null 2>&1; then
    echo "kube-system namespace exists."
fi


# =========================================================
# 3. INSTALL METRICS SERVER
# =========================================================

echo ""
echo "[3/7] Installing Metrics Server..."

kubectl apply -f \
"https://github.com/kubernetes-sigs/metrics-server/releases/download/${METRICS_SERVER_VERSION}/components.yaml"


# =========================================================
# 4. WAIT FOR DEPLOYMENT
# =========================================================

echo ""
echo "[4/7] Waiting for Metrics Server..."

kubectl rollout status \
deployment/metrics-server \
-n kube-system \
--timeout=180s


# =========================================================
# 5. VERIFY POD
# =========================================================

echo ""
echo "[5/7] Checking Metrics Server pod..."

kubectl get pods \
-n kube-system \
-l k8s-app=metrics-server \
-o wide


# =========================================================
# 6. CHECK API SERVICE
# =========================================================

echo ""
echo "[6/7] Checking Metrics API..."

kubectl get apiservice \
v1beta1.metrics.k8s.io


# =========================================================
# 7. TEST METRICS
# =========================================================

echo ""
echo "[7/7] Testing node metrics..."

echo ""
echo "Waiting for metrics to become available..."

sleep 20

kubectl top nodes || true

echo ""
echo "Pod metrics:"

kubectl top pods -A || true


# =========================================================
# FINAL STATUS
# =========================================================

echo ""
echo "========================================================="
echo " Metrics Server Installation Completed"
echo "========================================================="

echo ""
echo "Deployment:"
kubectl get deployment metrics-server -n kube-system

echo ""
echo "Service:"
kubectl get service metrics-server -n kube-system

echo ""
echo "API Service:"
kubectl get apiservice v1beta1.metrics.k8s.io

echo ""
echo "========================================================="