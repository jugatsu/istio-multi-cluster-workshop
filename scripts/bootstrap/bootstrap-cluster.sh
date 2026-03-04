#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

CLUSTER="${1:-}"
[ -n "$CLUSTER" ] || die "usage: $0 <cluster1|cluster2>"

case "$CLUSTER" in
  cluster1|cluster2) ;;
  *) die "unsupported cluster: ${CLUSTER}" ;;
esac

CONTEXT="kind-${CLUSTER}"
ISTIO_VERSION="${ISTIO_VERSION:-1.26.2}"
CNI="${CNI:-calico}"
CALICO_VERSION="${CALICO_VERSION:-v3.28.1}"
METALLB_VERSION="${METALLB_VERSION:-v0.15.2}"

for c in kubectl helm; do
  require_cmd "$c"
done

install_cni() {
  case "$CNI" in
    calico)
      log "Installing Calico on ${CLUSTER}"
      kubectl --context="$CONTEXT" apply -f "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml"
      wait_rollout "$CONTEXT" kube-system daemonset/calico-node 10m
      wait_rollout "$CONTEXT" kube-system deployment/calico-kube-controllers 10m
      ;;
    cilium)
      require_cmd cilium
      log "Installing Cilium on ${CLUSTER}"
      cilium --context "$CONTEXT" install --values "${ROOT_DIR}/helm-values/cilium/values.yaml"
      cilium --context "$CONTEXT" status --wait --wait-duration 10m
      ;;
    none)
      log "Skipping CNI install on ${CLUSTER}"
      ;;
    *)
      die "unsupported CNI: ${CNI} (expected calico|cilium|none)"
      ;;
  esac
}

log "Configuring Istio namespace and CA certs on ${CLUSTER}"
kubectl --context="$CONTEXT" apply -f "${ROOT_DIR}/manifests/istio/${CLUSTER}-ns.yaml"
apply_cacerts_secret "$CONTEXT" "$CLUSTER"

log "Installing CNI for ${CLUSTER}"
install_cni

log "Installing Istio base on ${CLUSTER}"
helm --kube-context "$CONTEXT" upgrade --install --wait --version "$ISTIO_VERSION" \
  istio-base istio/base -n istio-system --create-namespace

log "Installing istiod on ${CLUSTER}"
helm --kube-context "$CONTEXT" upgrade --install --wait --version "$ISTIO_VERSION" \
  istiod istio/istiod -n istio-system \
  --values "${ROOT_DIR}/helm-values/${CLUSTER}/istiod/values.yaml"

log "Installing MetalLB on ${CLUSTER}"
kubectl --context="$CONTEXT" apply -f "https://raw.githubusercontent.com/metallb/metallb/${METALLB_VERSION}/config/manifests/metallb-native.yaml"
wait_rollout "$CONTEXT" metallb-system deployment/controller 10m
wait_rollout "$CONTEXT" metallb-system daemonset/speaker 10m

log "Applying MetalLB address pool config on ${CLUSTER}"
kubectl --context="$CONTEXT" apply -f "${ROOT_DIR}/manifests/metallb/${CLUSTER}-lb.yaml"

# log "Preparing east-west gateway namespace on ${CLUSTER}"
# kubectl --context="$CONTEXT" apply -f "${ROOT_DIR}/manifests/istio/istio-eastwest-ns.yaml"

log "Installing east-west gateway on ${CLUSTER}"
helm --kube-context "$CONTEXT" upgrade --install --wait --version "$ISTIO_VERSION" \
  istio-eastwestgateway istio/gateway \
  -n istio-eastwestgateway --create-namespace \
  -f "${ROOT_DIR}/helm-values/${CLUSTER}/istio-eastwestgateway/values.yaml"

log "Exposing east-west gateway on ${CLUSTER}"
kubectl --context="$CONTEXT" apply -n istio-eastwestgateway -f "${ROOT_DIR}/manifests/istio/eastwestgateway.yaml"

log "Services on ${CLUSTER}"
kubectl --context="$CONTEXT" get svc -A
