#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="${1:-ocilab-hadoop}"

podman exec "${CONTAINER_NAME}" bash -lc '
  cd /workspace/banking-app
  mvn -q -DskipTests package

  hdfs dfs -mkdir -p /apps/banking/input
  hdfs dfs -put -f /workspace/data/transactions_sample.csv /apps/banking/input/transactions.csv
  hdfs dfs -rm -r -f /apps/banking/output/daily-balance || true

  hadoop jar target/banking-risk-job-1.0.0.jar \
    hdfs://localhost:9000/apps/banking/input/transactions.csv \
    hdfs://localhost:9000/apps/banking/output/daily-balance

  echo "== HDFS output =="
  hdfs dfs -cat /apps/banking/output/daily-balance/part-r-00000
'
