#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${1:-ocilab-hadoop:latest}"
podman build -t "${IMAGE_NAME}" -f Containerfile .
echo "Image built: ${IMAGE_NAME}"
