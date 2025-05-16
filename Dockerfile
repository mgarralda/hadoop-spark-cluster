# Get base image
FROM ubuntu:20.04

# Install Java
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y software-properties-common && \
    add-apt-repository ppa:openjdk-r/ppa -y && \
    apt-get update && \
    apt-get install -y openjdk-8-jdk && \
    apt-get clean

# Install Python2 to use with HiBench
RUN apt-get update && \
    apt-get install -y python2 && \
    ln -s /usr/bin/python2 /usr/bin/python

# Install needed packages
RUN apt-get install -y less vim ssh openssh-server openssh-client rsync sudo wget net-tools iputils-ping bc gettext

# Configure SSH
RUN mkdir -p /var/run/sshd && \
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config && \
    echo "StrictHostKeyChecking no" >> /etc/ssh/ssh_config && \
    echo "UserKnownHostsFile /dev/null" >> /etc/ssh/ssh_config

# Create user sparker with sudo
RUN useradd -ms /bin/bash sparker && \
    echo "sparker ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER sparker
WORKDIR /home/sparker

# Setup passwordless SSH for user sparker
RUN ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa && \
    cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys && \
    chmod 700 ~/.ssh && \
    chmod 600 ~/.ssh/authorized_keys && \
    echo "Host *" > ~/.ssh/config && \
    echo "    StrictHostKeyChecking no" >> ~/.ssh/config && \
    echo "    UserKnownHostsFile /dev/null" >> ~/.ssh/config && \
    chmod 600 ~/.ssh/config

# Set environment variables
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/jre/
ENV HADOOP_VERSION=3.3.2
ENV HADOOP_HOME=/home/sparker/hadoop-$HADOOP_VERSION
ENV HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
ENV PATH=$PATH:$HADOOP_HOME/bin

# Download and install Hadoop
RUN wget https://archive.apache.org/dist/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz -q -O ./hadoop-$HADOOP_VERSION.tar.gz && \
    tar -xvzf ./hadoop-$HADOOP_VERSION.tar.gz && \
    echo "export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/jre/" >> $HADOOP_HOME/etc/hadoop/hadoop-env.sh

# Set Spark variables
ENV SPARK_VERSION=3.3.2
ENV SPARK_HOME=/home/sparker/spark-$SPARK_VERSION-bin-hadoop3
ENV SPARK_DIST_CLASSPATH="$HADOOP_HOME/etc/hadoop/*:$HADOOP_HOME/share/hadoop/common/lib/*:$HADOOP_HOME/share/hadoop/common/*:$HADOOP_HOME/share/hadoop/hdfs/*:$HADOOP_HOME/share/hadoop/hdfs/lib/*:$HADOOP_HOME/share/hadoop/hdfs/*:$HADOOP_HOME/share/hadoop/yarn/lib/*:$HADOOP_HOME/share/hadoop/yarn/*:$HADOOP_HOME/share/hadoop/mapreduce/lib/*:$HADOOP_HOME/share/hadoop/mapreduce/*:$HADOOP_HOME/share/hadoop/tools/lib/*"
ENV PATH=$PATH:${SPARK_HOME}/bin:${SPARK_HOME}/sbin

# Download and install Spark
RUN wget https://archive.apache.org/dist/spark/spark-$SPARK_VERSION/spark-$SPARK_VERSION-bin-hadoop3.tgz -q -O ./spark-$SPARK_VERSION-bin-hadoop3.tgz && \
    tar -xvzf ./spark-$SPARK_VERSION-bin-hadoop3.tgz

# Expose only necessary ports
# SSH
EXPOSE 22
# YARN NodeManager
EXPOSE 8040 8042
# YARN ResourceManager
EXPOSE 8030 8031 8032 8033 8088
# MapReduce Job History
EXPOSE 10020 19888
# Spark Master / UI
EXPOSE 7077 4040 18080
# HDFS NameNode (UI + RPC)
EXPOSE 9870 9000
