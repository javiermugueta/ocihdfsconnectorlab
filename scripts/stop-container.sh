#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="${1:-ocilab-hadoop}"
podman rm -f "${CONTAINER_NAME}" || true
