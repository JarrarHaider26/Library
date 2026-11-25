#!/bin/bash
set -euo pipefail

exec > >(tee -a /var/log/k3s-demo-bootstrap.log) 2>&1

IMDS_TOKEN=$(curl -fsS -X PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
PUBLIC_IPV4=$(curl -fsS -H "X-aws-ec2-metadata-token: ${IMDS_TOKEN}" http://169.254.169.254/latest/meta-data/public-ipv4)
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --write-kubeconfig-mode 644 --tls-san ${PUBLIC_IPV4}" sh -
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

for attempt in $(seq 1 60); do
  if kubectl get nodes >/dev/null 2>&1; then
    break
  fi
  sleep 5
done

curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

cat >/tmp/argocd-values.yaml <<'YAML'
server:
  service:
    type: NodePort
    nodePortHttps: 30443
YAML

helm upgrade --install argocd argo/argo-cd \
  --version 10.20.0 \
  --namespace argocd \
  --create-namespace \
  --values /tmp/argocd-values.yaml \
  --wait \
  --timeout 15m

cat >/tmp/monitoring-values.yaml <<'YAML'
grafana:
  adminUser: admin
  adminPassword: demo-only-change-me
  persistence:
    enabled: false
  service:
    type: NodePort
    nodePort: 30300
prometheus:
  service:
    type: NodePort
    nodePort: 30901
  prometheusSpec:
    retention: 24h
    retentionSize: 1GB
    serviceMonitorSelectorNilUsesHelmValues: false
    serviceMonitorNamespaceSelector: {}
    ruleSelectorNilUsesHelmValues: false
    ruleNamespaceSelector: {}
    storageSpec: {}
alertmanager:
  alertmanagerSpec:
    storage: {}
YAML

helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --version 93.11.0 \
  --namespace monitoring \
  --create-namespace \
  --values /tmp/monitoring-values.yaml \
  --wait \
  --timeout 20m

cat >/tmp/library-application.yaml <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: library-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/JarrarHaider26/Library.git
    targetRevision: main
    path: helm-library
    helm:
      parameters:
        - name: app.service.type
          value: NodePort
        - name: app.service.nodePort
          value: "30800"
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
YAML

kubectl apply -f /tmp/library-application.yaml

for attempt in $(seq 1 60); do
  if kubectl get crd servicemonitors.monitoring.coreos.com >/dev/null 2>&1; then
    break
  fi
  sleep 5
done

cat >/tmp/library-monitoring.yaml <<'YAML'
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: library-api
  namespace: monitoring
  labels:
    release: monitoring
spec:
  endpoints:
    - interval: 15s
      path: /metrics
      port: http
  namespaceSelector:
    matchNames:
      - default
  selector:
    matchLabels:
      app: library-api
---
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: library-alerts
  namespace: monitoring
  labels:
    release: monitoring
spec:
  groups:
    - name: library-api
      rules:
        - alert: LibraryApiDown
          expr: up{namespace="default",service="library-api-service"} == 0
          for: 1m
          labels:
            severity: critical
          annotations:
            summary: Library API is down
            description: Prometheus cannot scrape the Library API metrics endpoint.
YAML

kubectl apply -f /tmp/library-monitoring.yaml
