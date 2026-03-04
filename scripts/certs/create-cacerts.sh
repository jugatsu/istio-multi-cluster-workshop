#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OUT_DIR="${ROOT_DIR}/certs"
MAKEFILE="${SCRIPT_DIR}/Makefile.selfsigned.mk"

CLUSTERS=("${@:-}")
if [ "${#CLUSTERS[@]}" -eq 1 ] && [ -z "${CLUSTERS[0]}" ]; then
  CLUSTERS=(cluster1 cluster2)
fi

for cmd in make openssl; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "missing command: $cmd" >&2
    exit 1
  }
done

mkdir -p "$OUT_DIR"

(
  cd "$OUT_DIR"

  echo "Generating root CA and intermediate certs in ${OUT_DIR}"
  make -f "$MAKEFILE" root-ca

  for cluster in "${CLUSTERS[@]}"; do
    case "$cluster" in
      cluster1|cluster2)
        ;;
      *)
        echo "unsupported cluster name: $cluster (expected cluster1 or cluster2)" >&2
        exit 1
        ;;
    esac
    make -f "$MAKEFILE" "${cluster}-cacerts"
  done
)

echo "Done. Generated certs:"
for cluster in "${CLUSTERS[@]}"; do
  echo "  - certs/${cluster}/"
done
