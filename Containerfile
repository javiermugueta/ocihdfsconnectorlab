FROM eclipse-temurin:8-jdk-jammy

ARG HADOOP_VERSION=3.3.6
ARG HIVE_VERSION=3.1.3
ARG SPARK_VERSION=3.5.1
ARG OCI_HDFS_CONNECTOR_VERSION=3.4.1.0.0.1

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    curl \
    wget \
    ca-certificates \
    tar \
    gzip \
    procps \
    net-tools \
    python3 \
    gettext-base \
    maven \
    && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/opt/java/openjdk
ENV HADOOP_HOME=/opt/hadoop
ENV HIVE_HOME=/opt/hive
ENV SPARK_HOME=/opt/spark
ENV HADOOP_CONF_DIR=/opt/hadoop/etc/hadoop
ENV HIVE_CONF_DIR=/opt/hive/conf
ENV PATH=$PATH:/opt/hadoop/bin:/opt/hadoop/sbin:/opt/hive/bin:/opt/spark/bin:/opt/spark/sbin

RUN wget -q https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz -O /tmp/hadoop.tgz \
    && tar -xzf /tmp/hadoop.tgz -C /opt \
    && mv /opt/hadoop-${HADOOP_VERSION} ${HADOOP_HOME} \
    && rm /tmp/hadoop.tgz

RUN wget -q https://archive.apache.org/dist/hive/hive-${HIVE_VERSION}/apache-hive-${HIVE_VERSION}-bin.tar.gz -O /tmp/hive.tgz \
    && tar -xzf /tmp/hive.tgz -C /opt \
    && mv /opt/apache-hive-${HIVE_VERSION}-bin ${HIVE_HOME} \
    && rm /tmp/hive.tgz

RUN wget -q https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop3.tgz -O /tmp/spark.tgz \
    && tar -xzf /tmp/spark.tgz -C /opt \
    && mv /opt/spark-${SPARK_VERSION}-bin-hadoop3 ${SPARK_HOME} \
    && rm /tmp/spark.tgz

RUN mkdir -p /opt/oci-hdfs/lib /opt/build-oci
RUN cat > /opt/build-oci/pom.xml <<POM
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <groupId>local</groupId>
  <artifactId>oci-hdfs-bootstrap</artifactId>
  <version>1.0.0</version>
  <dependencies>
    <dependency>
      <groupId>com.oracle.oci.sdk</groupId>
      <artifactId>oci-hdfs-connector</artifactId>
      <version>${OCI_HDFS_CONNECTOR_VERSION}</version>
    </dependency>
  </dependencies>
</project>
POM
RUN mvn -q -f /opt/build-oci/pom.xml dependency:copy-dependencies -DincludeScope=runtime -DoutputDirectory=/opt/oci-hdfs/lib \
    && rm -rf /root/.m2/repository /opt/build-oci

RUN cp /opt/oci-hdfs/lib/*.jar ${HADOOP_HOME}/share/hadoop/common/lib/ \
    && cp /opt/oci-hdfs/lib/*.jar ${HIVE_HOME}/lib/ \
    && cp /opt/oci-hdfs/lib/*.jar ${SPARK_HOME}/jars/

RUN mkdir -p /data/hdfs/namenode /data/hdfs/datanode /data/hive/metastore /var/log/hadoop /workspace

COPY conf/hadoop/core-site.xml.template ${HADOOP_CONF_DIR}/core-site.xml.template
COPY conf/hadoop/hdfs-site.xml ${HADOOP_CONF_DIR}/hdfs-site.xml
COPY conf/hadoop/mapred-site.xml ${HADOOP_CONF_DIR}/mapred-site.xml
COPY conf/hadoop/yarn-site.xml ${HADOOP_CONF_DIR}/yarn-site.xml
COPY conf/hadoop/workers ${HADOOP_CONF_DIR}/workers
COPY conf/hive/hive-site.xml ${HIVE_HOME}/conf/hive-site.xml
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /workspace
EXPOSE 9870 9864 8088 8042 10000 10002 19888 9000

ENTRYPOINT ["/entrypoint.sh"]
