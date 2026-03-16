#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="${1:-ocilab-hadoop}"
OCI_INPUT_URI="${2:-}"

if [ -z "${OCI_INPUT_URI}" ]; then
  echo "Uso: $0 <container> oci://<bucket>@<namespace>/apps/banking/input"
  exit 1
fi

podman exec -it "${CONTAINER_NAME}" bash -lc "
  hadoop fs -mkdir -p ${OCI_INPUT_URI}
  hadoop fs -put -f /workspace/data/transactions_sample.csv ${OCI_INPUT_URI}/transactions.csv
  OCI_INPUT_URI='${OCI_INPUT_URI}' envsubst < /workspace/hive/banking_oci.sql > /tmp/banking_oci.sql
  beeline -u jdbc:hive2://localhost:10000/default -n root -f /tmp/banking_oci.sql
  beeline -u jdbc:hive2://localhost:10000/default -n root -e \"SELECT * FROM banking.daily_balance_oci ORDER BY account_id, txn_date\"
"
