# Migration to Spark 4.2.0

## Target runtime

| Component | Target |
| --- | --- |
| Spark | 4.2.0, official `bin-hadoop3` distribution |
| Hadoop HDFS / YARN / MapReduce | 3.5.0 |
| Java | OpenJDK 17 |
| Python | 3.12 on Ubuntu 24.04 |
| Scala / Almond | 2.13.18 / 0.14.5 |
| NumPy / pandas / PyArrow | 2.5.4 / 2.3.3 / 26.0.0 |

Spark 4.2 supports Java 17 and Scala 2.13, with Python 3.10 or newer.
Hadoop 3.5 requires Java 17 for its servers. Java 17 is therefore shared by all
images rather than mixing JVM versions. pandas remains on 2.3.3 because Spark
4.2 requires pandas below 3; updating every dependency to its newest major
version would not satisfy that constraint.

References: [Spark runtime requirements](https://spark.apache.org/docs/4.2.0/),
[PySpark dependencies](https://spark.apache.org/docs/4.2.0/api/python/getting_started/install.html),
[Hadoop 3.5 Java requirements](https://hadoop.apache.org/docs/r3.5.0/).

## Changes from Spark 3.5

- Ubuntu 24.04, OpenJDK 17 and Python 3.12 replace Ubuntu 22.04, Java 11 and Python 3.10.
- Scala notebooks use the `scala_2.13` kernel and Scala 2.13.18; Scala 2.12 JARs must be rebuilt.
- Almond uses the Java module options read from Spark's own launcher JAR.
  Its predef still loads Spark defaults and Hadoop XML resources for HDFS and event logging.
- The Scala predef includes `spark-yarn`, enabling the external YARN scheduler
  when Almond creates Spark contexts without going through `spark-submit`.
- PySpark and Py4J come from the same Spark distribution as the workers.
- Shared pinned requirements align NumPy, pandas and Arrow between notebook drivers and executors.
- Python 2 and obsolete mamba notebook instructions are removed.
- Added Scala and PySpark YARN notebooks alongside the Standalone and ML examples.
- Startup creates the notebook user's HDFS home with the correct owner, allowing
  YARN staging from Jupyter on a fresh filesystem without disabling permissions.
- Docker images use the `4.2.0` tag. The Compose project defaults to `spark42-cluster`, isolating new named volumes from the old `spark-cluster` project.

Spark 4 enables ANSI SQL behavior by default and changes SQL, Python and Scala
APIs. Check workload correctness before comparing timings. Read the
[SQL migration guide](https://spark.apache.org/docs/4.2.0/sql-migration-guide.html)
and [PySpark migration guide](https://spark.apache.org/docs/4.2.0/api/python/migration_guide/index.html).

## Data safety and switching versions

Do not attach the old Hadoop 3.3.6 volumes to Hadoop 3.5.0 as an automatic
upgrade. This branch starts with separate named volumes. Export the datasets
needed from the old cluster and import them into the new HDFS, or plan and test
an explicit Hadoop storage upgrade with backups.

Both branches use the same container hostnames, host ports and Docker subnet.
Only one cluster can run at a time. To stop the old deployment without deleting
its data, use its previous checkout's Compose file, or an unchanged saved copy:

```powershell
docker compose -p spark-cluster down
```

Keep the previous `latest` images and `spark-cluster_*` volumes for rollback.
The new `4.2.0` images do not overwrite those tags. Do not use `down -v` unless
you intend to delete that project's HDFS and HiBench volumes.

NameNode startup formats only an empty volume and rejects nonempty storage
without `current/VERSION`. HDFS replication remains 1; named volumes are not a
backup. The default DataNode disk reserve remains 5 GiB.

## Build and run

With Docker Desktop in Linux container mode, from the repository root:

```powershell
.\scripts\build_images.ps1
docker compose up -d --wait --wait-timeout 300
docker compose ps
docker logs spark-cluster-jupyterlab
```

Linux build: `make -f scripts/Makefile build`.
Images target Linux amd64. Direct Python dependencies are pinned; OS packages
and transitive Maven/pip dependencies are not fully locked.

The configured master, workers and Jupyter limits total 26 GiB, plus proxy and
Docker overhead. Each worker has 6 GiB / 6 cores, with 3 GiB offered to Spark or
YARN applications. Keep Docker, Spark and YARN allocations aligned. Run one
manager at a time because Standalone and YARN share the same workers.

## Acceptance checks

Status: passed on 2026-10-11 for the local Linux amd64 cluster on Docker Desktop
for Windows, using PowerShell 7.6.5. Installed Java: OpenJDK 17.0.20.1;
Python: 3.12.3. HiBench is excluded.

| Check | Result |
| --- | --- |
| Four images | Built successfully with tag `4.2.0` |
| Node registration | Three HDFS DataNodes, YARN NodeManagers and Standalone workers |
| Distributed Python | Standalone client, YARN client and YARN cluster passed, including pinned library imports, pandas UDF and HDFS Parquet round trip |
| SparkPi | YARN cluster succeeded; aggregated logs reported `3.142147142147142` |
| MapReduce Pi | YARN job succeeded and appears in MapReduce Job History |
| Nine notebooks | Python and Scala examples passed, including both ML examples and both YARN client examples |
| Spark History Server | Exact seven notebook application IDs verified as completed with Spark 4.2.0 |
| Source/image consistency | Final Almond predef matches the repository source |
| Persistence | HDFS marker content, all four storage identities and 20 completed Spark history entries survived Compose recreation |
| Execution after recreation | Scala Standalone and YARN notebooks passed again, including their corrected runtime-version output |
| Web interfaces | Six main interfaces and all nine worker proxy endpoints responded successfully |
| Source checks | Compose, XML uniqueness, PowerShell parsing, notebook JSON and Git whitespace checks passed |

Validated Docker image IDs:

- Base: `sha256:f99e618b47519c25510a4b935c3b726ed6351a4cd0be187889b3c4532b5809a7`.
- Master: `sha256:a326c45f6167b3e20bed73805d38292054c3310ad6dae9fc49098b153fce8285`.
- Worker: `sha256:1f97f94236589604be9ca468e0322fdfe1010db3342e1f4dd5fac390d8b6bba9`.
- Jupyter: `sha256:3c726c1242778f3f50fde576333ce21cee4d933e9aff381d7ef7c11112beabd3`.

Notebook application IDs from the complete acceptance run:

| Notebook | Application ID |
| --- | --- |
| PySpark local | `local-1791751835197` |
| PySpark ML | `app-20261011205045-0004` |
| PySpark Standalone | `app-20261011205106-0005` |
| PySpark YARN | `application_1791751549529_0002` |
| Scala ML | `app-20261011205221-0006` |
| Scala Standalone | `app-20261011205246-0007` |
| Scala YARN | `application_1791751549529_0003` |

SparkPi ran as `application_1791751161312_0003`; MapReduce Pi ran as
`job_1791751161312_0004`. The two hello-world notebooks validate their kernels
without creating Spark applications.

```powershell
.\scripts\smoke_test.ps1
docker cp scripts/validate_notebooks.py spark-cluster-jupyterlab:/tmp/validate_notebooks.py
docker exec spark-cluster-jupyterlab /opt/notebook/bin/python /tmp/validate_notebooks.py
docker cp spark-cluster-jupyterlab:/tmp/notebook-validation/report-all.json ./notebook-validation-report.json
.\scripts\validate_persistence.ps1
```

The smoke script exercises real Python workers on Standalone and YARN client /
cluster, verifies runtime versions, dependency imports, a pandas UDF, HDFS
Parquet write/read and SparkPi in YARN cluster mode.
It also runs Hadoop MapReduce Pi on YARN.

The notebook validator executes copies of all nine notebooks, including Scala
and PySpark YARN client sessions and both ML examples. It checks the exact Spark
application IDs against completed History Server entries. Use `--language scala`
or `--language python` for a narrower rerun. The two hello-world notebooks do
not create Spark applications. Executed copies and `report-all.json` are saved
under `/tmp/notebook-validation` inside Jupyter; repository notebooks are unchanged.

The persistence script recreates this branch's containers without deleting
volumes, then compares test file content, four storage identities and completed
History Server entries. It removes only its dedicated marker file.

Local build/test logs live in ignored `.validation/`. Review failures before
claiming acceptance; a passing image build alone does not prove distributed execution.

Runtime observations: Java prints an incubator-vector notice, and Spark ML
reports that native BLAS is unavailable before using its Java fallback. Both
ML notebooks passed with that fallback. Native BLAS performance is not part of
this release's acceptance; record the BLAS implementation when benchmarking.

## Deferred HiBench update

HiBench remains outside this release's acceptance scope. Rebuild it for Spark
4.2.0 / Scala 2.13 and adapt any legacy Python 2 scripts before testing SQL,
shuffle and ML workloads. Preserve dataset and allocation settings when
comparing results; old Spark 3.5 or Scala 2.12 workloads are not assumed compatible.
