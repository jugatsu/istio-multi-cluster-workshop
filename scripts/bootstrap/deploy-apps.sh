#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

require_cmd kubectl

label_injection() {
  local context="$1"
  kubectl --context "$context" label namespace default istio-injection=enabled --overwrite
}

apply_manifest() {
  local context="$1"
  local file="$2"
  kubectl --context "$context" apply -f "${ROOT_DIR}/manifests/apps/${file}"
}

log "Enabling sidecar injection on default namespace in both clusters"
label_injection kind-cluster1
label_injection kind-cluster2

log "Deploying apps to cluster1"
apply_manifest kind-cluster1 curl.yaml
apply_manifest kind-cluster1 curl-1.yaml
apply_manifest kind-cluster1 echo-1.yaml
apply_manifest kind-cluster1 app.yaml
apply_manifest kind-cluster1 helloworld-dc1.yaml

log "Deploying apps to cluster2"
apply_manifest kind-cluster2 curl.yaml
apply_manifest kind-cluster2 curl-1.yaml
apply_manifest kind-cluster2 curl-2.yaml
apply_manifest kind-cluster2 echo-2.yaml
apply_manifest kind-cluster2 app.yaml
apply_manifest kind-cluster2 helloworld-dc2.yaml
