#!/bin/bash

# =========================================================
# Prometheus + Grafana Monitoring Stack
# kube-prometheus-stack
# =========================================================

set -e

NAMESPACE="monitoring"
RELEASE_NAME="kube-prometheus-stack"
CHART_VERSION="88.3.0"

echo "========================================================="
echo " Prometheus + Grafana Installation"
echo " Chart : kube-prometheus-stack ${CHART_VERSION}"
echo " Namespace : ${NAMESPACE}"
echo "========================================================="


# =========================================================
# 1. VERIFY KUBERNETES
# =========================================================

echo "[1/10] Checking Kubernetes cluster..."

kubectl cluster-info

echo ""
kubectl get nodes -o wide


# =========================================================
# 2. VERIFY HELM
# =========================================================

echo ""
echo "[2/10] Checking Helm..."

if ! command -v helm >/dev/null 2>&1; then
    echo "ERROR: Helm is not installed."
    echo "Install Helm 3 before continuing."
    exit 1
fi

helm version


# =========================================================
# 3. ADD PROMETHEUS COMMUNITY REPOSITORY
# =========================================================

echo ""
echo "[3/10] Adding Prometheus Community Helm repository..."

helm repo add prometheus-community \
https://prometheus-community.github.io/helm-charts

helm repo update


# =========================================================
# 4. CREATE MONITORING NAMESPACE
# =========================================================

echo ""
echo "[4/10] Creating monitoring namespace..."

kubectl create namespace "${NAMESPACE}" \
2>/dev/null || true


# =========================================================
# 5. INSTALL KUBE-PROMETHEUS-STACK
# =========================================================

echo ""
echo "[5/10] Installing kube-prometheus-stack..."

helm upgrade --install "${RELEASE_NAME}" \
prometheus-community/kube-prometheus-stack \
--namespace "${NAMESPACE}" \
--version "${CHART_VERSION}" \
--set grafana.enabled=true \
--set prometheus.enabled=true \
--set alertmanager.enabled=true \
--set nodeExporter.enabled=true \
--set kubeStateMetrics.enabled=true \
--wait \
--timeout 10m


# =========================================================
# 6. CHECK HELM RELEASE
# =========================================================

echo ""
echo "[6/10] Checking Helm release..."

helm list \
--namespace "${NAMESPACE}"


# =========================================================
# 7. CHECK PODS
# =========================================================

echo ""
echo "[7/10] Checking monitoring pods..."

kubectl get pods \
-n "${NAMESPACE}" \
-o wide


# =========================================================
# 8. CHECK SERVICES
# =========================================================

echo ""
echo "[8/10] Checking monitoring services..."

kubectl get svc \
-n "${NAMESPACE}"


# =========================================================
# 9. CHECK MONITORING COMPONENTS
# =========================================================

echo ""
echo "[9/10] Checking monitoring components..."

echo ""
echo "Prometheus:"
kubectl get prometheus \
-n "${NAMESPACE}" \
2>/dev/null || true

echo ""
echo "Grafana:"
kubectl get deployment \
-n "${NAMESPACE}" \
-l app.kubernetes.io/name=grafana \
2>/dev/null || true

echo ""
echo "Alertmanager:"
kubectl get alertmanager \
-n "${NAMESPACE}" \
2>/dev/null || true


# =========================================================
# 10. FINAL STATUS
# =========================================================

echo ""
echo "========================================================="
echo " Monitoring Stack Installation Completed"
echo "========================================================="

echo ""
echo "Namespace:"
kubectl get namespace "${NAMESPACE}"

echo ""
echo "Pods:"
kubectl get pods -n "${NAMESPACE}"

echo ""
echo "Services:"
kubectl get svc -n "${NAMESPACE}"

echo ""
echo "========================================================="
echo " Access Grafana"
echo "========================================================="

echo ""
echo "Run:"
echo ""
echo "kubectl port-forward -n ${NAMESPACE} svc/${RELEASE_NAME}-grafana 3000:80"
echo ""
echo "Then open:"
echo ""
echo "http://localhost:3000"
echo ""
echo "========================================================="