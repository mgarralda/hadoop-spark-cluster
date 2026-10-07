#!/usr/bin/env bash
set -euo pipefail

sudo service ssh start
mkdir -p /home/sparker/hadoop_data/hdfs/namenode
# Refuse to format nonempty storage without a valid NameNode identity.
if [[ ! -f /home/sparker/hadoop_data/hdfs/namenode/current/VERSION ]]; then
    if [[ -n "$(find /home/sparker/hadoop_data/hdfs/namenode -mindepth 1 -print -quit)" ]]; then
        echo "NameNode storage is nonempty but has no VERSION; restore or inspect it before starting." >&2
        exit 1
    fi
    hdfs namenode -format -nonInteractive
fi

cleanup() {
    trap - TERM INT EXIT
    "$SPARK_HOME/sbin/stop-history-server.sh" || true
    "$SPARK_HOME/sbin/stop-master.sh" || true
    mapred --daemon stop historyserver || true
    yarn --daemon stop resourcemanager || true
    hdfs --daemon stop secondarynamenode || true
    hdfs --daemon stop namenode || true
}
trap cleanup EXIT
trap 'exit 0' TERM INT

hdfs --daemon start namenode
hdfs --daemon start secondarynamenode
yarn --daemon start resourcemanager
mapred --daemon start historyserver
"$SPARK_HOME/sbin/start-master.sh" -h spark-cluster-master -p 7077

# Workers start concurrently; wait for their DataNodes and HDFS safe mode.
ready=false
for attempt in {1..90}; do
    if timeout 10 hdfs dfsadmin -safemode get 2>/dev/null | grep -q 'Safe mode is OFF'; then
        ready=true
        break
    fi
    sleep 2
done
if [[ "$ready" != true ]]; then
    echo "HDFS did not become ready within the startup window." >&2
    exit 1
fi
hdfs dfs -mkdir -p /shared/spark-logs /tmp/logs
hdfs dfs -chmod 1777 /shared/spark-logs /tmp /tmp/logs
"$SPARK_HOME/sbin/start-history-server.sh"

while true; do
    processes=$(jps -l)
    for daemon in NameNode SecondaryNameNode ResourceManager JobHistoryServer org.apache.spark.deploy.master.Master org.apache.spark.deploy.history.HistoryServer; do
        if ! grep -Eq "[. ]${daemon}$" <<< "$processes"; then
            echo "Required daemon stopped: $daemon" >&2
            exit 1
        fi
    done
    sleep 10 &
    wait $!
done

