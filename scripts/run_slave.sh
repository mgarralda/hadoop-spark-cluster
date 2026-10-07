#!/usr/bin/env bash
set -euo pipefail

sudo service ssh start
cleanup() {
    trap - TERM INT EXIT
    "$SPARK_HOME/sbin/stop-worker.sh" || true
    yarn --daemon stop nodemanager || true
    hdfs --daemon stop datanode || true
}
trap cleanup EXIT
trap 'exit 0' TERM INT

hdfs --daemon start datanode
yarn --daemon start nodemanager
"$SPARK_HOME/sbin/start-worker.sh" \
    --host "$(hostname)" -p 7177 \
    --cores "${SPARK_WORKER_CORES:-6}" \
    --memory "${SPARK_WORKER_MEMORY:-3g}" \
    spark://spark-cluster-master:7077

while true; do
    processes=$(jps -l)
    for daemon in DataNode NodeManager org.apache.spark.deploy.worker.Worker; do
        if ! grep -Eq "[. ]${daemon}$" <<< "$processes"; then
            echo "Required daemon stopped: $daemon" >&2
            exit 1
        fi
    done
    sleep 10 &
    wait $!
done
