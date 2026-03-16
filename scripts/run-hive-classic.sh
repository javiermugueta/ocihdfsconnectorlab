#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="${1:-ocilab-hadoop}"

podman exec -it "${CONTAINER_NAME}" bash -lc '
  hdfs dfs -mkdir -p /apps/banking/input
  hdfs dfs -put -f /workspace/data/transactions_sample.csv /apps/banking/input/transactions.csv
  beeline -u jdbc:hive2://localhost:10000/default -n root -f /workspace/hive/banking_hdfs.sql
  beeline -u jdbc:hive2://localhost:10000/default -n root -e "SELECT * FROM banking.daily_balance_hdfs ORDER BY account_id, txn_date"
'
