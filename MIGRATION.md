# Migration to Spark 3.5.9

## Target runtime

- Spark 3.5.9, official `bin-hadoop3` distribution.
- Hadoop HDFS/YARN/MapReduce services 3.3.6.
- OpenJDK 11 from Ubuntu 22.04 packages.
- Python 3.10 on every image; Scala 2.12.18 / Almond 0.14.1 in Jupyter.

Jupyter derives from the same base as the workers. It imports the bundled PySpark
and Py4J rather than installing another Spark version from pip. Both notebook
and executor environments pin NumPy, pandas and PyArrow. Other Python libraries
used inside custom UDFs must also be installed on the executors.
Direct Python dependencies are pinned; OS updates and transitive pip/Maven
dependencies are not fully locked. The current build targets Linux amd64.

Spark keeps its bundled Hadoop client libraries, which may have a different
patch version from the Hadoop services. No server JARs are injected into Spark.
See [Spark on YARN](https://spark.apache.org/docs/3.5.9/running-on-yarn.html).

## Existing problems addressed

- Python 3 was absent from the workers; the notebook requested Python 3.8.
- Spark dependencies in Almond and Jupyter were independently fixed to 3.3.2.
- Almond launches outside `spark-submit`; its predef now loads
  `spark-defaults.conf` and Hadoop XML resources, enabling HDFS event logs and
  completed Scala applications in Spark History Server. Existing JVM properties
  take precedence over the defaults.
- All Hadoop server JARs were added to an already Hadoop-enabled Spark distribution.
- NameNode formatting occurred during image build; HDFS storage had no volumes.
- History Server started before HDFS readiness; MapReduce History Server was absent.
- Worker failure left a container running through `tail -f /dev/null`.
- YARN advertised 19 cores and 45 GiB per worker despite Docker limits of 6 cores / 15 GiB. The new local defaults use 6 cores / 6 GiB per worker.
- Worker Spark memory used the entire Docker allowance. Applications now have
  3 GiB per worker, leaving 3 GiB for Hadoop daemons and process overhead.
- Worker YARN configuration disabled log aggregation in a duplicate property and
  used an invalid environment expression for the log server URL.
- Linux build targets had wrong paths, whitespace and a misspelled image tag;
  PowerShell builds ignored failures and deleted previous images first.
- Notebook application UI ports were exposed on the master rather than Jupyter.
- Docker build contexts included benchmark/event data; shell line endings were
  not controlled; unnecessary privileged containers and public proxy bindings were removed.

## Before replacing existing containers

If the old cluster contains HDFS data, back it up **before** recreating it.
The old NameNode/DataNode directories are inside the containers, not in the
new volumes. Adding volumes does not migrate their contents. Preserve all node
directories as one consistent set after stopping Hadoop services, or export
needed HDFS files and restore them to a fresh cluster. Do not start new NameNode
metadata against old DataNode storage. Keep the old images for rollback.

The new startup formats only an empty NameNode volume. It refuses nonempty
storage without `current/VERSION`. Named volumes survive `docker compose down`;
`docker compose down -v` deletes them, including the HiBench volume.
HDFS replication remains 1 for this experimental cluster, so volumes are not
a replacement for a backup. DataNodes reserve 5 GiB of disk space; adjust this
for the Docker virtual disk size.

## Build and run

With Docker Desktop running in Linux container mode:

```powershell
.\scripts\build_images.ps1
docker compose -p spark-cluster up -d
docker compose -p spark-cluster ps
docker logs spark-cluster-jupyterlab
.\scripts\smoke_test.ps1
```

Jupyter uses its generated token; open the token URL from its logs at
http://localhost:8888. Notebook Spark UI is http://localhost:4042 (4043 for a
second concurrent context); master-client Spark UI remains on port 4040.
Workers intentionally depend on the master being started, not healthy: their
DataNodes are needed to make HDFS ready. Jupyter waits for a healthy master.

Linux/macOS build: `make -f scripts/Makefile build` from the project root.
Images still use local `latest` tags; tag old images before rebuilding if needed.
The configured limits total 26 GiB for master, workers and Jupyter, plus the proxy
and Docker overhead. Adjust Docker Desktop capacity or reduce limits and YARN /
Spark allocations together. Standalone and YARN share the same workers and each
has an independent resource scheduler: run benchmarks with only one manager
at a time to avoid double allocation.

## Validation status

Acceptance scope: the local Spark/Hadoop/Jupyter cluster, excluding HiBench.
Validation date: 2026-10-07. The following checks passed:

| Check | Result |
| --- | --- |
| Docker images | Base, master, worker and Jupyter built successfully |
| Installed runtime | Spark 3.5.9, Hadoop 3.3.6, OpenJDK 11.0.32.1, Python 3.10.12 |
| Cluster registration | Three live HDFS DataNodes, three running YARN NodeManagers and three Spark workers |
| Distributed PySpark | Standalone client, YARN client and YARN cluster; executor library imports, pandas UDF and HDFS Parquet write/read |
| SparkPi | YARN cluster application succeeded; aggregated logs contained the result |
| Notebooks | All seven Python/Scala notebooks, including both ML examples, executed successfully |
| Final Almond image | Three Scala notebooks rerun after loading Spark defaults and Hadoop resources |
| Scala History Server | Exact ML and Standalone application IDs confirmed as completed with Spark 3.5.9 |
| Storage persistence | Test file content and all four storage identities survived Compose recreation without deleting volumes |
| NameNode startup guard | Empty storage formatted once; valid storage preserved; nonempty unformatted storage rejected |
| Source checks | Compose, XML properties, shell/PowerShell syntax and Git whitespace checks passed |

The final Jupyter container uses image
`sha256:94a467d8f39ffdd85d4f1d12541410a7f1537d01958745f82cf53e0685637715`.
Its Almond predef was compared with `scripts/predef.sc` and matches after
normalizing line endings. The Scala hello-world notebook checks the kernel only;
it does not create a Spark application or a History Server entry.

Final acceptance application IDs:

- Scala ML: `app-20261007075852-0004`.
- Scala Standalone: `app-20261007075912-0005`.

Local execution logs are kept in ignored `.validation/` files; they are not
required to build or run the cluster. Executed notebook copies and the Scala
acceptance report are written under `/tmp/scala-validation` in Jupyter, leaving
the repository notebooks unchanged.

### Repeat Scala and History Server acceptance

From the repository root, with the cluster running:

```powershell
docker cp scripts/validate_scala.py spark-cluster-jupyterlab:/tmp/validate_scala.py
docker exec spark-cluster-jupyterlab /opt/notebook/bin/python /tmp/validate_scala.py
docker cp spark-cluster-jupyterlab:/tmp/scala-validation/report.json ./scala-validation-report.json
```

The validator executes all three Scala notebooks, checks Spark 3.5.9, enabled
event logging and the HDFS URL, then verifies the exact two Spark application
IDs appear as completed in the History Server API with version 3.5.9. A missing
entry or notebook failure causes a nonzero exit. Java 11 emits a Netty reflective
access warning during these runs; it did not prevent notebook execution.

Repeat distributed runtime checks with `./scripts/smoke_test.ps1`. To repeat
persistence acceptance, write a dedicated HDFS test file, record its content and
each node's `current/VERSION` identity properties, then run Compose `down`
without `-v` and `up -d`. Confirm the file and identities survive, and remove
only the dedicated test file. Timestamp comments in `VERSION` are not identities.

### Deferred HiBench update

HiBench validation is explicitly outside this release's acceptance scope. It
will be updated separately, rebuilt for Spark 3.5.9 / Scala 2.12 and tested with
representative SQL, shuffle and ML workloads. This repository does not include
HiBench sources; an existing JAR built for Spark 3.3 is not considered validated
for 3.5. Compare output correctness and execution plans before benchmark times;
consult the [SQL migration guide](https://spark.apache.org/docs/3.5.9/sql-migration-guide.html).

To isolate Spark performance changes, compare old and new Spark with the same
JDK, Hadoop, data, resource limits and settings. Existing benchmark results are
not directly comparable after the resource corrections in this migration.
