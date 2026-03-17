#!/usr/bin/env bash
set -euo pipefail

export HDFS_NAMENODE_USER=root
export HDFS_DATANODE_USER=root
export HDFS_SECONDARYNAMENODE_USER=root
export YARN_RESOURCEMANAGER_USER=root
export YARN_NODEMANAGER_USER=root
export MAPRED_HISTORYSERVER_USER=root

export FS_DEFAULTFS="${FS_DEFAULTFS:-hdfs://localhost:9000}"
export OCI_TENANCY_OCID="${OCI_TENANCY_OCID:-}"
export OCI_USER_OCID="${OCI_USER_OCID:-}"
export OCI_FINGERPRINT="${OCI_FINGERPRINT:-}"
export OCI_PRIVATE_KEY_PATH="${OCI_PRIVATE_KEY_PATH:-/opt/oci/.oci_api_key.pem}"
export OCI_REGION="${OCI_REGION:-}"
export OCI_PROFILE="${OCI_PROFILE:-DEFAULT}"

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf "%s" "$s"
}

read_oci_config_value() {
  local key="$1"
  local cfg="${2:-/opt/oci/config}"
  local profile="${3:-DEFAULT}"

  [ -f "${cfg}" ] || return 1

  awk -v want_profile="[${profile}]" -v want_key="${key}" '
    function trim(str) {
      gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", str)
      return str
    }
    /^\s*#/ { next }
    /^\s*$/ { next }
    /^\s*\[/ {
      section = trim($0)
      in_section = (section == want_profile)
      next
    }
    in_section {
      eq = index($0, "=")
      if (eq > 0) {
        k = trim(substr($0, 1, eq - 1))
        v = trim(substr($0, eq + 1))
        if (k == want_key) {
          print v
          exit 0
        }
      }
    }
  ' "${cfg}"
}

load_oci_config_fallback() {
  local cfg="${OCI_CONFIG_FILE:-/opt/oci/config}"
  local profile="${OCI_PROFILE:-DEFAULT}"

  if [ -z "${OCI_TENANCY_OCID}" ]; then
    OCI_TENANCY_OCID="$(read_oci_config_value tenancy "${cfg}" "${profile}" || true)"
  fi
  if [ -z "${OCI_USER_OCID}" ]; then
    OCI_USER_OCID="$(read_oci_config_value user "${cfg}" "${profile}" || true)"
  fi
  if [ -z "${OCI_FINGERPRINT}" ]; then
    OCI_FINGERPRINT="$(read_oci_config_value fingerprint "${cfg}" "${profile}" || true)"
  fi
  if [ -z "${OCI_REGION}" ]; then
    OCI_REGION="$(read_oci_config_value region "${cfg}" "${profile}" || true)"
  fi

  if [ "${OCI_PRIVATE_KEY_PATH}" = "/opt/oci/.oci_api_key.pem" ]; then
    local key_file
    key_file="$(read_oci_config_value key_file "${cfg}" "${profile}" || true)"
    if [ -n "${key_file}" ]; then
      if [ -f "${key_file}" ]; then
        OCI_PRIVATE_KEY_PATH="${key_file}"
      else
        local key_base
        key_base="$(basename "${key_file}")"
        if [ -f "/opt/oci/${key_base}" ]; then
          OCI_PRIVATE_KEY_PATH="/opt/oci/${key_base}"
        fi
      fi
    fi
  fi
}

render_core_site() {
  local template="${HADOOP_CONF_DIR}/core-site.xml.template"
  local target="${HADOOP_CONF_DIR}/core-site.xml"
  cp "${template}" "${target}"

  sed -i "s|\${FS_DEFAULTFS}|${FS_DEFAULTFS}|g" "${target}"
  sed -i "s|\${OCI_TENANCY_OCID}|${OCI_TENANCY_OCID}|g" "${target}"
  sed -i "s|\${OCI_USER_OCID}|${OCI_USER_OCID}|g" "${target}"
  sed -i "s|\${OCI_FINGERPRINT}|${OCI_FINGERPRINT}|g" "${target}"
  sed -i "s|\${OCI_PRIVATE_KEY_PATH}|${OCI_PRIVATE_KEY_PATH}|g" "${target}"
  sed -i "s|\${OCI_REGION}|${OCI_REGION}|g" "${target}"

  cp "${target}" "${HIVE_HOME}/conf/core-site.xml"
  cp "${target}" "${SPARK_HOME}/conf/core-site.xml"
}

init_hdfs() {
  mkdir -p /data/spark-events
  chmod 1777 /data/spark-events

  if [ ! -f /data/hdfs/namenode/current/VERSION ]; then
    echo "[init] Formatting namenode"
    hdfs namenode -format -force
  fi

  echo "[init] Starting HDFS"
  hdfs --daemon start namenode
  hdfs --daemon start datanode

  echo "[init] Starting YARN + MapReduce history"
  yarn --daemon start resourcemanager
  yarn --daemon start nodemanager
  mapred --daemon start historyserver

  echo "[init] Waiting for HDFS"
  for _ in $(seq 1 20); do
    if hdfs dfs -ls / >/dev/null 2>&1; then
      break
    fi
    sleep 2
  done

  hdfs dfs -mkdir -p /tmp /warehouse/tablespace/managed/hive /user/root
  hdfs dfs -chmod -R 1777 /tmp
}

init_hive() {
  if [ ! -d /data/hive/metastore/metastore_db ]; then
    echo "[init] Initializing Hive metastore schema"
    schematool -dbType derby -initSchema || true
  fi

  # Keep Hive services on the OCI SDK Jersey stack (2.35) and avoid Hive's older Jersey/JAX-RS jars.
  local hs2_oci_backup="/opt/hive/lib/oci-hs2-conflict-backup"
  mkdir -p "${hs2_oci_backup}"
  for p in \
    /opt/hive/lib/jersey-*-2.25*.jar \
    /opt/hive/lib/javax.ws.rs-api-2.0.1.jar; do
    for f in ${p}; do
      [ -f "${f}" ] || continue
      mv -f "${f}" "${hs2_oci_backup}/"
    done
  done

  local oci_java_opts="-Djavax.ws.rs.ext.RuntimeDelegate=org.glassfish.jersey.internal.RuntimeDelegateImpl"

  echo "[init] Starting Hive metastore"
  HADOOP_CLIENT_OPTS="${HADOOP_CLIENT_OPTS:-} ${oci_java_opts}" \
    nohup hive --service metastore >/var/log/hadoop/hive-metastore.log 2>&1 &

  echo "[init] Waiting for Hive metastore on 9083"
  for _ in $(seq 1 30); do
    if timeout 1 bash -c "cat < /dev/null > /dev/tcp/127.0.0.1/9083" >/dev/null 2>&1; then
      break
    fi
    sleep 2
  done

  echo "[init] Starting HiveServer2"
  HADOOP_CLIENT_OPTS="${HADOOP_CLIENT_OPTS:-} ${oci_java_opts}" \
    nohup hiveserver2 >/var/log/hadoop/hiveserver2.log 2>&1 &
}

main() {
  load_oci_config_fallback
  render_core_site
  init_hdfs
  init_hive

  echo "[ready] Hadoop/Hive/Spark stack started"
  jps

  tail -f /var/log/hadoop/hive-metastore.log /var/log/hadoop/hiveserver2.log
}

main "$@"
