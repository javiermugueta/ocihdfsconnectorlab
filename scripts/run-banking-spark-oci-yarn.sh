#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="${1:-ocilab-hadoop}"
OCI_BUCKET_URI="${2:-}"

if [ -z "${OCI_BUCKET_URI}" ]; then
  echo "Uso: $0 <container> oci://<bucket>@<namespace>/apps/banking"
  exit 1
fi

podman exec "${CONTAINER_NAME}" bash -lc "
  set -euo pipefail
  INPUT_URI='${OCI_BUCKET_URI}/input/transactions.csv'
  OUTPUT_URI='${OCI_BUCKET_URI}/output/daily-balance-spark-yarn'
  OLD_GUAVA='/opt/spark/jars/guava-14.0.1.jar'
  BAK_GUAVA='/tmp/guava-14.0.1.jar.bak'

  restore_guava() {
    if [ -f \"\${BAK_GUAVA}\" ]; then
      mv -f \"\${BAK_GUAVA}\" \"\${OLD_GUAVA}\"
    fi
  }
  trap restore_guava EXIT

  if [ -f \"\${OLD_GUAVA}\" ]; then
    mv -f \"\${OLD_GUAVA}\" \"\${BAK_GUAVA}\"
  fi

  cat > /tmp/daily_balance_spark.py <<'PY'
#!/usr/bin/env python3
import sys
from pyspark.sql import SparkSession
from pyspark.sql import functions as F


def main() -> int:
    if len(sys.argv) != 3:
        print('Uso: daily_balance_spark.py <input-uri> <output-uri>', file=sys.stderr)
        return 1

    input_uri = sys.argv[1]
    output_uri = sys.argv[2]

    spark = SparkSession.builder.appName('daily-balance-banking-spark').getOrCreate()

    txns = (
        spark.read.option('header', 'true')
        .option('inferSchema', 'true')
        .csv(input_uri)
        .select('txn_date', 'account_id', 'txn_type', 'amount')
    )

    balances = (
        txns.withColumn(
            'signed_amount',
            F.when(F.upper(F.col('txn_type')) == F.lit('DEBIT'), -F.col('amount')).otherwise(F.col('amount')),
        )
        .groupBy('account_id', 'txn_date')
        .agg(F.sum('signed_amount').alias('daily_balance'))
        .orderBy('account_id', 'txn_date')
    )

    print('== Spark result preview ==')
    balances.show(100, truncate=False)

    lines = balances.select(
        F.concat_ws('', F.col('account_id'), F.lit('|'), F.col('txn_date')).alias('key'),
        F.col('daily_balance').cast('string').alias('value'),
    ).select(F.concat_ws('\t', F.col('key'), F.col('value')).alias('line'))

    lines.write.mode('overwrite').text(output_uri)
    spark.stop()
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
PY

  spark-submit \
    --master yarn \
    --deploy-mode client \
    --conf spark.yarn.submit.waitAppCompletion=true \
    --conf spark.hadoop.fs.oci.impl=com.oracle.bmc.hdfs.BmcFilesystem \
    --conf spark.driver.userClassPathFirst=true \
    --conf spark.executor.userClassPathFirst=true \
    /tmp/daily_balance_spark.py \
    \"\${INPUT_URI}\" \
    \"\${OUTPUT_URI}\"
"
