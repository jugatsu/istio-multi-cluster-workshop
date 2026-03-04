#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

require_cmd istioctl
require_cmd kubectl

log "Creating remote secret: cluster2 -> cluster1"
istioctl create-remote-secret \
  --context=kind-cluster2 \
  --server=https://cluster2-control-plane:6443 \
  --name=cluster2 | \
  kubectl --context=kind-cluster1 apply -f -

log "Creating remote secret: cluster1 -> cluster2"
istioctl create-remote-secret \
  --context=kind-cluster1 \
  --server=https://cluster1-control-plane:6443 \
  --name=cluster1 | \
  kubectl --context=kind-cluster2 apply -f -

log "Verifying remote cluster visibility"
istioctl remote-clusters --context=kind-cluster1
istioctl remote-clusters --context=kind-cluster2
