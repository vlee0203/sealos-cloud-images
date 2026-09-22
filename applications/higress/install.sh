#!/usr/bin/env bash
set -euo pipefail

CLOUD_DOMAIN="${CLOUD_DOMAIN:-}"
CLOUD_PORT="${CLOUD_PORT:-443}"

# 首次安装时命名空间还不存在，而下面两个资源带显式 namespace
kubectl create namespace higress-system --dry-run=client -o yaml | kubectl apply -f -

# helm 只在首次 install 时应用 chart 的 crds/，upgrade 会跳过，所以显式 apply 一次
kubectl apply -f charts/higress/charts/higress-core/crds/

kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: higress-https
  namespace: higress-system
data:
  cert: |
    automaticHttps: false
    fallbackForInvalidSecret: true
    acmeIssuer:
    - email: cloud@sealos.io
      name: letsencrypt
    renewBeforeDays: 1
    credentialConfig:
    - domains:
        - '*.${CLOUD_DOMAIN}'
        - '${CLOUD_DOMAIN}'
      tlsSecret: sealos-system/wildcard-cert
---
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: global-route-config
  namespace: higress-system
spec:
  configPatches:
    - applyTo: ROUTE_CONFIGURATION
      match:
        context: GATEWAY
      patch:
        operation: MERGE
        value:
          request_headers_to_add:
            - append: false
              header:
                key: x-real-ip
                value: '%REQ(X-ENVOY-EXTERNAL-ADDRESS)%'
---
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: tailscale-options
  namespace: higress-system
spec:
  configPatches:
    - applyTo: NETWORK_FILTER
      match:
        context: GATEWAY
        listener:
          filterChain:
            filter:
              name: envoy.filters.network.http_connection_manager
      patch:
        operation: MERGE
        value:
          typed_config:
            '@type': type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
            upgrade_configs:
              - upgrade_type: tailscale-control-protocol
EOF

cat >values.yaml <<EOF
higress-core:
  global:
    ingressClass: nginx
    enableStatus: false
    enableGatewayAPI: false
    disableAlpnH2: false
    enableIstioAPI: true
    enableSRDS: true
  gateway:
    kind: DaemonSet
    hostNetwork: true
    service:
      type: ClusterIP
    httpsPort: ${CLOUD_PORT}
    affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
            - matchExpressions:
                - key: node-role.kubernetes.io/control-plane
                  operator: Exists
    tolerations:
      - effect: "NoExecute"
        operator: "Exists"
      - effect: "NoSchedule"
        operator: "Exists"
    resources:
      requests:
        cpu: 256m
        memory: 256Mi
      limits:
        memory: 4Gi
  controller:
    affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
            - matchExpressions:
                - key: node-role.kubernetes.io/control-plane
                  operator: Exists
    tolerations:
      - effect: "NoExecute"
        operator: "Exists"
      - effect: "NoSchedule"
        operator: "Exists"
    resources:
      requests:
        cpu: 256m
        memory: 256Mi
  downstream:
    maxRequestHeadersKb: 8192
    http2:
      initialConnectionWindowSize: 4194304
      initialStreamWindowSize: 524288
      maxConcurrentStreams: 100
    # 同时决定 connection idle 与 stream idle（higress 用一个值喂两个字段）
    idleTimeout: 1800

higress-console:
  replicaCount: 0
EOF

helm upgrade --install higress charts/higress -n higress-system -f values.yaml
