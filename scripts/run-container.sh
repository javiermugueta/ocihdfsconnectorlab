#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${1:-ocilab-hadoop:latest}"
CONTAINER_NAME="${2:-ocilab-hadoop}"
OCI_ENV_FILE="${OCI_ENV_FILE:-.oci.env}"

mkdir -p .oci

if [ -f "${OCI_ENV_FILE}" ]; then
  set -a
  # shellcheck disable=SC1090
  . "${OCI_ENV_FILE}"
  set +a
fi

export OCI_PRIVATE_KEY_PATH="${OCI_PRIVATE_KEY_PATH:-/opt/oci/.oci_api_key.pem}"

podman run -d --name "${CONTAINER_NAME}" --hostname ocilab \
  -p 9870:9870 \
  -p 9864:9864 \
  -p 18088:8088 \
  -p 8042:8042 \
  -p 19888:19888 \
  -p 10000:10000 \
  -p 10002:10002 \
  -v "$(pwd)/banking-app:/workspace/banking-app:Z" \
  -v "$(pwd)/data:/workspace/data:Z" \
  -v "$(pwd)/hive:/workspace/hive:Z" \
  -v "$(pwd)/.oci:/opt/oci:ro,Z" \
  -e FS_DEFAULTFS="${FS_DEFAULTFS:-hdfs://localhost:9000}" \
  -e OCI_TENANCY_OCID \
  -e OCI_USER_OCID \
  -e OCI_FINGERPRINT \
  -e OCI_PRIVATE_KEY_PATH \
  -e OCI_REGION \
  -e OCI_PROFILE \
  -e OCI_CONFIG_FILE \
  "${IMAGE_NAME}"

echo "Container started: ${CONTAINER_NAME}"
echo "UI HDFS: http://localhost:9870"
echo "UI YARN: http://localhost:18088"
