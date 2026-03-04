#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

log() {
  printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || die "missing command: $cmd"
}

wait_rollout() {
  local context="$1"
  local namespace="$2"
  local resource="$3"
  local timeout="${4:-5m}"
  kubectl --context="$context" -n "$namespace" rollout status "$resource" --timeout="$timeout"
}

apply_cacerts_secret() {
  local context="$1"
  local cluster="$2"
  local cert_dir="${ROOT_DIR}/certs/${cluster}"

  [ -d "$cert_dir" ] || die "cert directory not found: $cert_dir"

  kubectl --context="$context" -n istio-system create secret generic cacerts \
    --from-file="${cert_dir}/ca-cert.pem" \
    --from-file="${cert_dir}/ca-key.pem" \
    --from-file="${cert_dir}/root-cert.pem" \
    --from-file="${cert_dir}/cert-chain.pem" \
    --dry-run=client -o yaml | kubectl --context="$context" apply -f -
}
