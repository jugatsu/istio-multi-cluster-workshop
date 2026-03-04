# Istio Multicluster Kind Lab

Local lab to bootstrap a two-cluster Istio multicluster environment on Kind, including:

- per-cluster CA certs
- Istio control plane + east-west gateway on each cluster
- MetalLB for `LoadBalancer` services
- sample apps for cross-cluster traffic testing

## Prerequisites

Install these CLIs before running bootstrap:

- `kind`
- `kubectl`
- `helm`
- `istioctl`
- `task` (go-task)
- `make`
- `openssl`

## Quick Start

From the repo root:

```bash
task bootstrap
```

This runs:

1. tool checks (`task doctor`)
2. Kind cluster creation (`cluster1`, `cluster2`)
3. CA generation under `certs/`
4. Istio Helm repo setup
5. per-cluster bootstrap (CNI, Istio, MetalLB, east-west gateway)
6. multicluster linking (remote secrets)
7. sample app deployment
8. basic verification

## Common Commands

```bash
# Full environment bootstrap
task bootstrap

# Bootstrap without sample apps
task bootstrap SKIP_APPS=1

# Use Cilium instead of default Calico
task bootstrap CNI=cilium

# Install canary control plane on cluster1 (default)
task canary

# Install canary control plane on another cluster/canary name
task canary CLUSTER=cluster2 CANARY=canary2

# Verify cluster and remote-cluster status
task verify

# Tear down clusters
task down

# Tear down clusters + generated certs
task reset
```

## Key Versions

Defined in `Taskfile.yaml`:

- Kubernetes (Kind node image): `v1.30.10`
- Istio stable: `1.28.4`
- Istio canary: `1.29.0`

## Repo Layout

- `Taskfile.yaml`: main workflow and task orchestration
- `kind/`: Kind cluster configs
- `scripts/bootstrap/`: cluster bootstrap, mesh linking, app deployment
- `scripts/certs/`: CA/cert generation scripts
- `manifests/`: Istio, MetalLB, and sample app manifests
- `helm-values/`: cluster-specific Helm values
- `certs/`: generated cert artifacts

## Basic Verification

After bootstrap:

```bash
kubectl --context kind-cluster1 get pods -A
kubectl --context kind-cluster2 get pods -A
istioctl remote-clusters --context=kind-cluster1
istioctl remote-clusters --context=kind-cluster2
```

## Notes

- `task certs:clean` removes generated cert outputs in `certs/cluster1`, `certs/cluster2`, and root cert/key artifacts.
- The bootstrap flow is intended for local experimentation and is not production-hardened.
