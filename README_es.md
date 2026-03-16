# Lab Podman: Hadoop + YARN + Hive + Spark + OCI HDFS Connector

Este laboratorio crea un contenedor unico con:
- HDFS (NameNode/DataNode)
- YARN (ResourceManager/NodeManager)
- Hive (Metastore + HiveServer2)
- Spark
- OCI HDFS Connector (`com.oracle.oci.sdk:oci-hdfs-connector`)

Tambien incluye una app bancaria en tres modos:
- Version clasica sobre HDFS
- Version migrada a OCI Object Storage con minimos cambios (solo URIs/config)
- Version Spark sobre YARN escribiendo en OCI

## 1. Seguridad (antes de todo)

Nunca subas credenciales reales al repo.

- `.oci.env` y `.oci/*` estan ignorados por git.
- Usa `.oci.env.example` como plantilla local.
- Monta `.oci` en solo lectura (ya lo hace `run-container.sh`).

## 2. Build de la imagen

```bash
./scripts/build-image.sh ocilab-hadoop:latest
```

## 3. Credenciales OCI (solo para modos OCI)

Copia tu clave privada en:

```bash
mkdir -p .oci
cp /ruta/a/tu/oci_api_key.pem .oci/.oci_api_key.pem
chmod 600 .oci/.oci_api_key.pem
```

Exporta variables:

```bash
export OCI_TENANCY_OCID="ocid1.tenancy.oc1..."
export OCI_USER_OCID="ocid1.user.oc1..."
export OCI_FINGERPRINT="aa:bb:cc:dd:..."
export OCI_REGION="eu-frankfurt-1"
```

## 4. Levantar contenedor

```bash
./scripts/run-container.sh ocilab-hadoop:latest ocilab-hadoop
```

Endpoints del contenedor:
- UI de HDFS NameNode: http://localhost:9870
- UI de HDFS DataNode: http://localhost:9864
- UI de YARN ResourceManager: http://localhost:18088/cluster
- UI de YARN NodeManager: http://localhost:8042/node
- UI de MapReduce JobHistory: http://localhost:19888/jobhistory
- HiveServer2 (Thrift/JDBC): localhost:10000
- UI web de HiveServer2: http://localhost:10002

## 5. Ejecutar app bancaria clasica (HDFS)

```bash
./scripts/run-banking-classic.sh ocilab-hadoop
```

Entrada:
- `hdfs://localhost:9000/apps/banking/input/transactions.csv`

Salida:
- `hdfs://localhost:9000/apps/banking/output/daily-balance`

## 6. Ejecutar app bancaria migrada a OCI (cambio minimo)

La app Java es exactamente la misma. Solo cambian las URIs de entrada/salida:

```bash
./scripts/run-banking-oci.sh ocilab-hadoop oci://<bucket>@<namespace>/apps/banking
```

Ejemplo:

```bash
./scripts/run-banking-oci.sh ocilab-hadoop oci://banking-datalake@axxxxxxx/apps/banking
```

## 7. Ejecutar version Spark en YARN sobre OCI

```bash
./scripts/run-banking-spark-oci-yarn.sh ocilab-hadoop oci://<bucket>@<namespace>/apps/banking
```

Salida OCI:
- `oci://<bucket>@<namespace>/apps/banking/output/daily-balance-spark-yarn`

Nota tecnica: para evitar conflicto de dependencias de Spark+OCI (Guava),
`run-banking-spark-oci-yarn.sh` desactiva temporalmente `guava-14.0.1.jar`
durante la ejecucion y la restaura al terminar.

## 8. Diferencia real de migracion

Sin cambios de logica de negocio en el codigo (`DailyBalanceJob`):
- Antes: `hdfs://...`
- Despues: `oci://<bucket>@<namespace>/...`

## 9. Variante Hive (misma idea de migracion)

HDFS clasico:

```bash
./scripts/run-hive-classic.sh ocilab-hadoop
```

OCI Object Storage (solo cambia `LOCATION`):

```bash
./scripts/run-hive-oci.sh ocilab-hadoop oci://<bucket>@<namespace>/apps/banking/input
```

## Estructura

- `Containerfile`: imagen con stack Hadoop/Hive/Spark + connector OCI
- `entrypoint.sh`: inicializacion de servicios y render de `core-site.xml`
- `conf/hadoop/*.xml`: configuracion HDFS/YARN/MapReduce + plantilla OCI
- `conf/hive/hive-site.xml`: metastore Derby local
- `banking-app/`: job MapReduce Java (caso bancario)
- `data/transactions_sample.csv`: dataset de ejemplo
- `scripts/*.sh`: automatizacion de build/run/test
- `hive/*.sql`: version Hive clasica y migrada a OCI

## Salida esperada (paridad)

En clasico y en OCI, la salida esperada es:

```text
ACC-1001|2026-03-01    2050
ACC-1001|2026-03-02    250
ACC-2002|2026-03-01    -200
ACC-3003|2026-03-02    1500
```

## Limpieza

```bash
./scripts/stop-container.sh ocilab-hadoop
```
