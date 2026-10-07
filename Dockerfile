# Shared runtime for Hadoop services, Spark executors and notebook drivers.
FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    openjdk-11-jdk-headless python3 python3-pip python3-venv python2 \
    ca-certificates curl less vim openssh-server openssh-client rsync sudo \
    wget net-tools iputils-ping bc gettext tini && \
    ln -s /usr/bin/python2 /usr/bin/python && \
    rm -rf /var/lib/apt/lists/*

# Python 2 is reserved for legacy HiBench scripts; Spark always uses Python 3.
ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
ENV HADOOP_VERSION=3.3.6
ENV SPARK_VERSION=3.5.9
ENV HADOOP_HOME=/home/sparker/hadoop-${HADOOP_VERSION}
ENV HADOOP_CONF_DIR=${HADOOP_HOME}/etc/hadoop
ENV HADOOP_MAPRED_HOME=${HADOOP_HOME}
ENV SPARK_HOME=/usr/local/spark
ENV PYSPARK_PYTHON=/opt/pyspark/bin/python
ENV HADOOP_HEAPSIZE_MAX=512
ENV YARN_HEAPSIZE=512
ENV MAPRED_HEAPSIZE=256
ENV SPARK_DAEMON_MEMORY=512m
ENV PATH=${JAVA_HOME}/bin:${HADOOP_HOME}/bin:${HADOOP_HOME}/sbin:${SPARK_HOME}/bin:${SPARK_HOME}/sbin:${PATH}

RUN mkdir -p /var/run/sshd && \
    echo 'PermitRootLogin no' >> /etc/ssh/sshd_config && \
    useradd -m -s /bin/bash sparker && \
    echo 'sparker:sparker' | chpasswd && \
    echo 'sparker ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/sparker

USER sparker
WORKDIR /home/sparker
RUN mkdir -p .ssh hadoop_data/hdfs/namenode hadoop_data/hdfs/datanode && \
    ssh-keygen -t rsa -P '' -f .ssh/id_rsa && \
    cat .ssh/id_rsa.pub >> .ssh/authorized_keys && \
    printf 'Host *\n    StrictHostKeyChecking no\n    UserKnownHostsFile /dev/null\n' > .ssh/config && \
    chmod 700 .ssh && chmod 600 .ssh/authorized_keys .ssh/config

# Verify archive checksums and keep downloaded archives out of the image.
RUN set -eu; \
    archive="hadoop-${HADOOP_VERSION}.tar.gz"; \
    url="https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}"; \
    wget --timeout=30 --tries=2 --progress=dot:giga "https://dlcdn.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/$archive" -O "$archive" || \
      wget --timeout=30 --tries=2 --progress=dot:giga "$url/$archive" -O "$archive"; \
    wget --timeout=30 --tries=2 -q "$url/$archive.sha512"; \
    expected=$(grep -oE '[a-fA-F0-9]{128}' "$archive.sha512"); \
    test -n "$expected"; \
    printf '%s  %s\n' "$expected" "$archive" | sha512sum -c -; \
    tar -xzf "$archive"; \
    rm "$archive" "$archive.sha512"; \
    printf '\nexport JAVA_HOME=%s\n' "$JAVA_HOME" >> "$HADOOP_HOME/etc/hadoop/hadoop-env.sh"

RUN set -eu; \
    archive="spark-${SPARK_VERSION}-bin-hadoop3.tgz"; \
    url="https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}"; \
    wget --timeout=30 --tries=2 --progress=dot:giga "https://dlcdn.apache.org/spark/spark-${SPARK_VERSION}/$archive" -O "$archive" || \
      wget --timeout=30 --tries=2 --progress=dot:giga "$url/$archive" -O "$archive"; \
    wget --timeout=30 --tries=2 -q "$url/$archive.sha512"; \
    expected=$(grep -oE '[a-fA-F0-9]{128}' "$archive.sha512"); \
    test -n "$expected"; \
    printf '%s  %s\n' "$expected" "$archive" | sha512sum -c -; \
    tar -xzf "$archive"; \
    rm "$archive" "$archive.sha512"

USER root
RUN ln -s "/home/sparker/spark-${SPARK_VERSION}-bin-hadoop3" "$SPARK_HOME"
COPY requirements-executors.txt /tmp/requirements-executors.txt
RUN python3 -m venv /opt/pyspark && \
    /opt/pyspark/bin/pip install --no-cache-dir -r /tmp/requirements-executors.txt && \
    /opt/pyspark/bin/pip check
COPY scripts/log4j2.properties /usr/local/spark/conf/log4j2.properties
USER sparker

# bin-hadoop3 already contains Hadoop clients: do not add server JARs.
EXPOSE 22 8040 8042 8030 8031 8032 8033 8088 10020 19888 7077 8080 8081 4040 18080 9870 9000

