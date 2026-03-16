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
  cd /workspace/banking-app
  mvn -q -DskipTests package

  export HADOOP_USER_CLASSPATH_FIRST=true
  export HADOOP_CLASSPATH=/opt/oci-hdfs/lib/*

  hadoop fs -mkdir -p ${OCI_BUCKET_URI}/input
  hadoop fs -put -f /workspace/data/transactions_sample.csv ${OCI_BUCKET_URI}/input/transactions.csv
  hadoop fs -rm -r -f ${OCI_BUCKET_URI}/output/daily-balance || true

  hadoop jar target/banking-risk-job-1.0.0.jar \
    -Dmapreduce.framework.name=yarn \
    -Dmapreduce.job.user.classpath.first=true \
    -Dyarn.app.mapreduce.am.env=HADOOP_USER_CLASSPATH_FIRST=true,HADOOP_CLASSPATH=/opt/oci-hdfs/lib/* \
    -Dmapreduce.map.env=HADOOP_USER_CLASSPATH_FIRST=true,HADOOP_CLASSPATH=/opt/oci-hdfs/lib/* \
    -Dmapreduce.reduce.env=HADOOP_USER_CLASSPATH_FIRST=true,HADOOP_CLASSPATH=/opt/oci-hdfs/lib/* \
    ${OCI_BUCKET_URI}/input/transactions.csv \
    ${OCI_BUCKET_URI}/output/daily-balance

  echo '== OCI output (YARN) =='
  hadoop fs -cat ${OCI_BUCKET_URI}/output/daily-balance/part-r-00000
"
