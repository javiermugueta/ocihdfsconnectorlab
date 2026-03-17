# Podman Lab: Hadoop + YARN + Hive + Spark + OCI HDFS Connector

This lab builds a single container with:
- HDFS (NameNode/DataNode)
- YARN (ResourceManager/NodeManager)
- Hive (Metastore + HiveServer2)
- Spark
- OCI HDFS Connector (`com.oracle.oci.sdk:oci-hdfs-connector`)

It also includes a banking sample app in three modes:
- Classic version on HDFS
- Migrated version on OCI Object Storage with minimal changes (URI/config only)
- Spark version on YARN writing to OCI

## 1. Security (first)

Never commit real credentials.

- `.oci.env` and `.oci/*` are ignored by git.
- Use `.oci.env.example` as your local template.
- Mount `.oci` as read-only (already done by `run-container.sh`).

## 2. Build the image

```bash
./scripts/build-image.sh ocilab-hadoop:latest
```

## 3. OCI credentials (OCI modes only)

Copy your private key:

```bash
mkdir -p .oci
cp /path/to/your/oci_api_key.pem .oci/.oci_api_key.pem
chmod 600 .oci/.oci_api_key.pem
```

Export variables:

```bash
export OCI_TENANCY_OCID="ocid1.tenancy.oc1..."
export OCI_USER_OCID="ocid1.user.oc1..."
export OCI_FINGERPRINT="aa:bb:cc:dd:..."
export OCI_REGION="eu-frankfurt-1"
```

## 4. Start the container

```bash
./scripts/run-container.sh ocilab-hadoop:latest ocilab-hadoop
```

Container endpoints:
- HDFS NameNode UI: http://localhost:9870
- HDFS DataNode UI: http://localhost:9864
- YARN ResourceManager UI: http://localhost:18088/cluster
- YARN NodeManager UI: http://localhost:8042/node
- MapReduce JobHistory UI: http://localhost:19888/jobhistory
- HiveServer2 (Thrift/JDBC): localhost:10000
- HiveServer2 Web UI: http://localhost:10002

## 5. Run classic banking app (HDFS)

```bash
./scripts/run-banking-classic.sh ocilab-hadoop
```

Input:
- `hdfs://localhost:9000/apps/banking/input/transactions.csv`

Output:
- `hdfs://localhost:9000/apps/banking/output/daily-balance`

## 6. Run migrated banking app on OCI (minimal change)

The Java app is exactly the same. Only input/output URIs change:

```bash
./scripts/run-banking-oci.sh ocilab-hadoop oci://<bucket>@<namespace>/apps/banking
```

Example:

```bash
./scripts/run-banking-oci.sh ocilab-hadoop oci://banking-datalake@axxxxxxx/apps/banking
```

## 7. Run Spark on YARN over OCI

```bash
./scripts/run-banking-spark-oci-yarn.sh ocilab-hadoop oci://<bucket>@<namespace>/apps/banking
```

OCI output:
- `oci://<bucket>@<namespace>/apps/banking/output/daily-balance-spark-yarn`

Technical note: to avoid Spark+OCI dependency conflict (Guava),
`run-banking-spark-oci-yarn.sh` temporarily disables `guava-14.0.1.jar`
during execution and restores it at the end.

## 8. What actually changes in the migration

No business logic changes in code (`DailyBalanceJob`):
- Before: `hdfs://...`
- After: `oci://<bucket>@<namespace>/...`

## 9. Hive variant (same migration idea)

Classic HDFS:

```bash
./scripts/run-hive-classic.sh ocilab-hadoop
```

OCI Object Storage (only `LOCATION` changes):

```bash
./scripts/run-hive-oci.sh ocilab-hadoop oci://<bucket>@<namespace>/apps/banking/input
```

## 10. Hive app example (risk scoring)

Classic HDFS:

```bash
./scripts/run-hive-app-classic.sh ocilab-hadoop
```

OCI Object Storage:

```bash
./scripts/run-hive-app-oci.sh ocilab-hadoop oci://<bucket>@<namespace>/apps/banking/input
```

Note: the OCI variant uses Hive for metadata/DDL and Spark SQL (local mode) for the risk aggregation step.

Outputs:
- `banking.account_risk_hdfs`
- `banking.account_risk_oci`

## Structure

- `Containerfile`: image with Hadoop/Hive/Spark + OCI connector
- `entrypoint.sh`: service startup and `core-site.xml` rendering
- `conf/hadoop/*.xml`: HDFS/YARN/MapReduce config + OCI template
- `conf/hive/hive-site.xml`: local Derby metastore
- `banking-app/`: Java MapReduce job (banking scenario)
- `data/transactions_sample.csv`: sample dataset
- `scripts/*.sh`: build/run/test automation
- `hive/*.sql`: classic and OCI Hive scripts

## Expected output (parity)

Expected output in classic and OCI runs:

```text
ACC-1001|2026-03-01    2050
ACC-1001|2026-03-02    250
ACC-2002|2026-03-01    -200
ACC-3003|2026-03-02    1500
```

## Cleanup

```bash
./scripts/stop-container.sh ocilab-hadoop
```
