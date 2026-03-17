#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="${1:-ocilab-hadoop}"
OCI_INPUT_URI="${2:-}"

if [ -z "${OCI_INPUT_URI}" ]; then
  echo "Uso: $0 <container> oci://<bucket>@<namespace>/apps/banking/input"
  exit 1
fi

podman exec "${CONTAINER_NAME}" bash -lc "
  set -euo pipefail

  TMP_JAXRS_DIR=/tmp/oci-jaxrs-backup-hive-app
  mkdir -p \${TMP_JAXRS_DIR}
  restore_jaxrs() {
    for d in \\
      /opt/hadoop/share/hadoop/common/lib \\
      /opt/hadoop/share/hadoop/hdfs/lib; do
      b=\$(basename \"\$d\")
      for f in \"\${TMP_JAXRS_DIR}/\${b}.\"*; do
        [ -f \"\$f\" ] || continue
        mv -f \"\$f\" \"\$d/\$(basename \"\$f\" | cut -d. -f2-)\"
      done
    done
  }
  trap restore_jaxrs EXIT

  # Avoid classpath conflicts between Hadoop Jersey1/JAX-RS1 and OCI SDK Jersey2 stack.
  for d in \\
    /opt/hadoop/share/hadoop/common/lib \\
    /opt/hadoop/share/hadoop/hdfs/lib; do
    b=\$(basename \"\$d\")
    for p in \\
      jsr311-api-1.1.1.jar \\
      jersey-core-1*.jar \\
      jersey-client-1*.jar \\
      jersey-json-1*.jar \\
      jersey-server-1*.jar \\
      jersey-servlet-1*.jar \\
      jersey-guice-1*.jar; do
      for f in \"\$d\"/\$p; do
        [ -f \"\$f\" ] || continue
        mv -f \"\$f\" \"\${TMP_JAXRS_DIR}/\${b}.\$(basename \"\$f\")\"
      done
    done
  done

  hadoop fs -mkdir -p ${OCI_INPUT_URI}
  hadoop fs -put -f /workspace/data/transactions_sample.csv ${OCI_INPUT_URI}/transactions.csv

  cat > /tmp/banking_risk_oci_ddl.sql.tpl <<'HIVESQL'
CREATE DATABASE IF NOT EXISTS banking;

CREATE EXTERNAL TABLE IF NOT EXISTS banking.transactions_csv_app_oci (
  txn_id STRING,
  txn_date STRING,
  account_id STRING,
  customer_id STRING,
  txn_type STRING,
  amount INT,
  currency STRING,
  channel STRING
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES (
  'separatorChar' = ',',
  'quoteChar'     = '\"'
)
STORED AS TEXTFILE
LOCATION '\${OCI_INPUT_URI}'
TBLPROPERTIES (\"skip.header.line.count\"=\"1\");

DROP TABLE IF EXISTS banking.account_risk_oci;
HIVESQL

  OCI_INPUT_URI='${OCI_INPUT_URI}' envsubst < /tmp/banking_risk_oci_ddl.sql.tpl > /tmp/banking_risk_oci_ddl.sql
  beeline -u jdbc:hive2://localhost:10000/default -n root -f /tmp/banking_risk_oci_ddl.sql

  OLD_GUAVA='/opt/spark/jars/guava-14.0.1.jar'
  BAK_GUAVA='/tmp/guava-14.0.1.jar.bak-hive-app'
  restore_guava() {
    if [ -f \"\${BAK_GUAVA}\" ]; then
      mv -f \"\${BAK_GUAVA}\" \"\${OLD_GUAVA}\"
    fi
  }
  trap restore_guava EXIT
  if [ -f \"\${OLD_GUAVA}\" ]; then
    mv -f \"\${OLD_GUAVA}\" \"\${BAK_GUAVA}\"
  fi

  cat > /tmp/banking_risk_oci_spark.py <<'PY'
#!/usr/bin/env python3
from pyspark.sql import SparkSession


def main() -> int:
  spark = (
      SparkSession.builder
      .appName('banking-risk-oci-spark-sql')
      .config('spark.sql.catalogImplementation', 'hive')
      .config('hive.metastore.uris', 'thrift://localhost:9083')
      .enableHiveSupport()
      .getOrCreate()
  )

  spark.sql('CREATE DATABASE IF NOT EXISTS banking')
  spark.sql('DROP TABLE IF EXISTS banking.account_risk_oci')
  spark.sql(
      \"\"\"
      CREATE TABLE banking.account_risk_oci AS
      SELECT
        account_id,
        txn_date,
        COUNT(*) AS txn_count,
        SUM(CASE WHEN UPPER(txn_type)='CREDIT' THEN amount ELSE 0 END) AS credit_total,
        SUM(CASE WHEN UPPER(txn_type)='DEBIT'  THEN amount ELSE 0 END) AS debit_total,
        SUM(CASE WHEN UPPER(txn_type)='DEBIT'  THEN -amount ELSE amount END) AS net_amount,
        SUM(CASE WHEN amount >= 1000 THEN 1 ELSE 0 END) AS large_txn_count,
        CASE
          WHEN SUM(CASE WHEN amount >= 1000 THEN 1 ELSE 0 END) >= 1
               AND SUM(CASE WHEN UPPER(txn_type)='DEBIT' THEN -amount ELSE amount END) < 0
            THEN 'HIGH'
          WHEN SUM(CASE WHEN amount >= 1000 THEN 1 ELSE 0 END) >= 1
            THEN 'MEDIUM'
          ELSE 'LOW'
        END AS risk_level
      FROM banking.transactions_csv_app_oci
      WHERE LOWER(txn_id) <> 'txn_id'
      GROUP BY account_id, txn_date
      \"\"\"
  )
  spark.sql(
      \"\"\"
      SELECT account_id, txn_date, txn_count, credit_total, debit_total, net_amount, large_txn_count, risk_level
      FROM banking.account_risk_oci
      ORDER BY account_id, txn_date
      \"\"\"
  ).show(100, truncate=False)
  spark.stop()
  return 0


if __name__ == '__main__':
  raise SystemExit(main())
PY

  spark-submit \
    --master local[2] \
    --conf spark.hadoop.fs.oci.impl=com.oracle.bmc.hdfs.BmcFilesystem \
    --conf spark.driver.userClassPathFirst=true \
    --conf spark.executor.userClassPathFirst=true \
    /tmp/banking_risk_oci_spark.py
"
