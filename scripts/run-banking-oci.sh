#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="${1:-ocilab-hadoop}"
OCI_BUCKET_URI="${2:-}"

if [ -z "${OCI_BUCKET_URI}" ]; then
  echo "Uso: $0 <container> oci://<bucket>@<namespace>/apps/banking"
  exit 1
fi

podman exec "${CONTAINER_NAME}" bash -lc "
  cd /workspace/banking-app
  mvn -q -DskipTests package

  TMP_JAXRS_DIR=/tmp/oci-jaxrs-backup
  mkdir -p \${TMP_JAXRS_DIR}
  restore_jaxrs() {
    for d in \\
      /opt/hadoop/share/hadoop/common/lib \\
      /opt/hadoop/share/hadoop/hdfs/lib \\
      /opt/hadoop/share/hadoop/mapreduce/lib \\
      /opt/hadoop/share/hadoop/yarn/lib; do
      b=\$(basename \"\$d\")
      for f in \"\${TMP_JAXRS_DIR}/\${b}.\"*; do
        [ -f \"\$f\" ] || continue
        mv -f \"\$f\" \"\$d/\$(basename \"\$f\" | cut -d. -f2-)\"
      done
    done
  }
  trap restore_jaxrs EXIT

  # OCI SDK (Jersey2) requires JAX-RS 2.x; Hadoop ships jsr311 1.1.1 that can shadow it.
  for d in \\
    /opt/hadoop/share/hadoop/common/lib \\
    /opt/hadoop/share/hadoop/hdfs/lib \\
    /opt/hadoop/share/hadoop/mapreduce/lib \\
    /opt/hadoop/share/hadoop/yarn/lib; do
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

  TMP_LOCAL_CONF=/tmp/hadoop-local-oci-conf
  rm -rf \${TMP_LOCAL_CONF}
  cp -r /opt/hadoop/etc/hadoop \${TMP_LOCAL_CONF}
  cat > \${TMP_LOCAL_CONF}/mapred-site.xml <<'MAPREDLOCAL'
<?xml version=\"1.0\"?>
<configuration>
  <property>
    <name>mapreduce.framework.name</name>
    <value>local</value>
  </property>
</configuration>
MAPREDLOCAL

  hadoop fs -mkdir -p ${OCI_BUCKET_URI}/input
  hadoop fs -put -f /workspace/data/transactions_sample.csv ${OCI_BUCKET_URI}/input/transactions.csv
  hadoop fs -rm -r -f ${OCI_BUCKET_URI}/output/daily-balance || true

  HADOOP_CONF_DIR=\${TMP_LOCAL_CONF} hadoop jar target/banking-risk-job-1.0.0.jar \
    ${OCI_BUCKET_URI}/input/transactions.csv \
    ${OCI_BUCKET_URI}/output/daily-balance

  echo '== OCI output =='
  hadoop fs -cat ${OCI_BUCKET_URI}/output/daily-balance/part-r-00000
"
