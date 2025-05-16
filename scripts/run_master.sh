#!/bin/bash

echo "Initializing SSH"
sudo service ssh start

# Setup ssh-agent for future automation
eval $(ssh-agent -s)
ssh-add

# Avoid SSH host key checking issues
for host in spark-cluster-master localhost 0.0.0.0; do
  ssh -oStrictHostKeyChecking=no "$host" uptime || true
done

echo "Starting NameNode and SecondaryNameNode (no DataNode)"
$HADOOP_HOME/sbin/hadoop-daemon.sh start namenode
$HADOOP_HOME/sbin/hadoop-daemon.sh start secondarynamenode

echo "Starting only YARN ResourceManager (no NodeManager)"
$HADOOP_HOME/bin/yarn resourcemanager > ~/resourcemanager.log 2>&1 &

echo "Starting Spark Master"
$SPARK_HOME/sbin/start-master.sh -h spark-cluster-master -p 7077

echo "Starting Spark History Server"
hdfs dfs -test -d /shared/spark-logs || {
  hdfs dfs -mkdir -p /shared/spark-logs
}
$SPARK_HOME/sbin/start-history-server.sh

# Keep container running
tail -f /dev/null

