#!/bin/bash

echo "Initializing SSH"
sudo service ssh start

echo "Starting HDFS DataNode..."
$HADOOP_HOME/sbin/hadoop-daemon.sh start datanode

echo "Starting YARN NodeManager..."
$HADOOP_HOME/sbin/yarn-daemon.sh start nodemanager

echo "Starting Spark Worker to standalone spark cluster.."
#$SPARK_HOME/sbin/start-worker.sh -p 7177 -c 1 -m 1G spark://spark-cluster-master:7077
#$SPARK_HOME/sbin/start-worker.sh --host $(hostname) -p 7177 -c 1 -m 1G spark://spark-cluster-master:7077

# fallback values if none provided
CORES="${SPARK_WORKER_CORES:-1}"
MEM="${SPARK_WORKER_MEMORY:-1g}"

echo "Starting Spark Worker on $(hostname) with $CORES cores and $MEM memory"
$SPARK_HOME/sbin/start-worker.sh \
  --host "$(hostname)" \
  -p 7177 \
  --cores "$CORES" \
  --memory "$MEM" \
  spark://spark-cluster-master:7077


# Keep the container alive
tail -f /dev/null
