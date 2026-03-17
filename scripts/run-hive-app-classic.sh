#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="${1:-ocilab-hadoop}"

podman exec "${CONTAINER_NAME}" bash -lc '
  hdfs dfs -mkdir -p /apps/banking/input
  hdfs dfs -put -f /workspace/data/transactions_sample.csv /apps/banking/input/transactions.csv

  beeline -u jdbc:hive2://localhost:10000/default -n root -f /workspace/hive/banking_risk_hdfs.sql

  beeline -u jdbc:hive2://localhost:10000/default -n root -e "
    SELECT account_id, txn_date, txn_count, credit_total, debit_total, net_amount, large_txn_count, risk_level
    FROM banking.account_risk_hdfs
    ORDER BY account_id, txn_date
  "
'
