# Hadoop-YARN | Standalone Spark Cluster

This repository provides a fully functional Docker-based environment for running Apache Spark cluster.
on Hadoop YARN or in standalone mode. .

> ✅ Supports executing MapReduce and Spark applications on YARN or standalone mode. Additionally, it sets up an HDFS cluster for reliable data storage and access.
>
> ✅ Integrated [Jupyter notebook](http://localhost:8888) for interactive data analysis and visualization using PySpark and Scala.
> 
> ✅ Fully compatible with our modernized [HiBench](https://github.com/mgarralda/HiBench) version, enabling performance benchmarking of Spark workloads.

- **Base OS**: Ubuntu 20.04
- **Spark**: v3.3.2 Scala v2.12 and  Python (pyspark) v3.8
- **Hadoop**: v3.3.2

⚠️ While this setup aims to approximate a realistic production cluster, it is recommended for **development and experimental purposes**.

---

## 🏗️ Cluster Setup

### 1. Download & Prepare

Download and extract the contents into a folder of your choice (be sure there is enough space for the images and share data).

### 2. Build Docker Images

Run the following to build the required Docker images:

**On Windows (PowerShell):**
```powershell
.\scripts\build_images.ps1
```
⚠️ Windows Security: Unblocking PowerShell Script
If you downloaded this project (e.g., from GitHub), Windows may block the script for security reasons. 

To unblock it:
right-click the file `build_images.ps1`, select Properties and at the bottom of the General tab check Unblock.
---

**On Linux/macOS**
```bash
cd scripts
make build_base_image
make build_master_image
make build_slave_image
make build_jupyter_image
```

### 3. Launch the Hadoop-Spark cluster

To start a cluster with 1 master and 3 slave nodes:
```bash
docker-compose -p spark-cluster up -d
```
⚠️ If you want to create a different number of slaves or container's resources, you must modify the `docker-compose.yml` accordingly.

### 4. Add the Master and the Slave's to /etc/hosts
The docker-compose creates a Nginx internal reverse proxy to access the log files of the slaves. 
To ensure the slaves can resolve from the host, add the following line to each slave's `/etc/hosts` file:
```
127.0.0.1 spark-cluster-master
127.0.0.1 spark-cluster-slave-1
127.0.0.1 spark-cluster-slave-2
127.0.0.1 spark-cluster-slave-3
```
or using this command as administrator in Windows PowerShell:
```powershell
..\scripts\add_hosts.ps1
```

To stop and remove all associated containers, volumes, and networks:
```bash
docker-compose down
```

To restart existing containers:
```bash
docker-compose start
```

To stop running containers:
```bash
docker-compose stop
```
---

## 📦 Container Roles

| Role                   | Master             | Slaves     |
|------------------------|--------------------|------------|
| HDFS NameNode          | ✅                  | ❌          |
| HDFS SecondaryNameNode | ✅                  | ❌          |
| HDFS DataNode          | ❌                  | ✅          |
| YARN ResourceManager   | ✅                  | ❌          |
| YARN NodeManager       | ❌                  | ✅          |
| Spark History Server   | ✅                  | ❌          |
| Spark Master/Worker    | ✅/❌ (standalone)   | ❌/✅ (standalone) |


### 📘 Role Descriptions 

- **HDFS NameNode**: Central service managing file system metadata.
- **HDFS SecondaryNameNode**: Periodically merges fsimage and edit logs.
- **HDFS DataNode**: Stores actual data blocks; distributed across slaves.
- **YARN ResourceManager**: Manages cluster resources and job scheduling.
- **YARN NodeManager**: Runs containers and reports usage; one per slave.
- **Spark History Server**: Displays completed Spark jobs (UI).
- **Spark Master/Worker**: Not used in YARN mode (YARN handles scheduling).

---

## ⚙️ Resource Configuration: Docker Compose & YARN Integration

To control the CPU and memory usage of each Spark/YARN node (especially slaves), Docker resource limits can be declared in the `docker-compose.yml` file using `cpus` and `mem_limit`:

### 1️⃣ Docker Compose Example

```yaml
services:
  slave:
    image: spark_slave:latest
    deploy:
      resources:
        limits:
          cpus: '2.0'        # Limit to 2 CPU cores
          memory: 4g         # Limit to 4 GB of RAM
    mem_limit: 4g
    cpus: 2
    ...
  ```
### 2️⃣ Matching YARN Configuration

In the yarn-site.xml distributed to all nodes, the following properties must reflect the same limits:

```xml
<property>
<name>yarn.nodemanager.resource.memory-mb</name>
<value>4096</value>
</property>

<property>
<name>yarn.nodemanager.resource.cpu-vcores</name>
<value>2</value>
</property>

<property>
<name>yarn.scheduler.maximum-allocation-mb</name>
<value>4096</value>
</property>

<property>
<name>yarn.scheduler.maximum-allocation-vcores</name>
<value>2</value>
</property>
```
Ensure yarn.scheduler.minimum-allocation-mb and minimum-allocation-vcores are ≤ these values.

### 3️⃣ Spark Resource Configuration (spark-defaults.conf)
Spark must be configured accordingly to the maximum resources provided by YARN:

```yml

spark.executor.instances     3
spark.executor.memory        3g
spark.executor.cores         1
spark.driver.memory          2g
spark.driver.cores           1
```
Consistent resource settings across Docker, YARN, and Spark prevent resource oversubscription and ensure correct job execution within physical limits.

---

## 🌐 Web UIs
- [Jupyter notebook](http://localhost:8888)
- [YARN ResourceManager](http://localhost:8088)
- [Hadoop HDFS NameNode UI](http://localhost:9870)
- [Spark Standalone UI](http://localhost:8080)
- [Spark History Server](http://localhost:18080)

---

## 🔐 SSH Access

You can connect to the master container via SSH:

```bash
ssh sparker@spark-cluster-master -p 2222
```
> Password: `sparker`
---

## 📂 Project Structure

Volume mappings and folder descriptions:

| Folder          | Mapped Path                   | Purpose                         |
|-----------------|-------------------------------|---------------------------------|
| `conf-master`   | `/home/sparker/hadoop-*/conf` | Master Hadoop config            |
| `conf-slave`    | `/home/sparker/hadoop-*/conf` | Slave Hadoop config             |
| `master`        | -                             | Dockerfile for master           |
| `slave`         | -                             | Dockerfile for slave            |
| `shared-master` | `/home/sparker/shared`        | Shared directory for master     |
| `shared-slave`  | `/home/sparker/shared`        | Shared directory for each slave |
| `hibench-data`  | `/home/sparker/HiBench`       | Volume for HiBench benchmarks   |
| `jupyter`       | `/home/sparker/work`          | Jupyter notebook files          |

You can drop your Spark JARs into the shared folder and run them using `spark-submit`.

---

## 🛠️ Running Jobs

To access the Spark master container:
```bash
docker exec -it hadoop-spark-cluster-master /bin/bash
```

If unsure of the container name:
```bash
docker ps --format '{{.Names}}'
```

### Run a SparkPi Test:
```bash
spark-submit   --class org.apache.spark.examples.SparkPi   --master yarn   --deploy-mode client   --driver-memory 1g   --executor-memory 1g   --executor-cores 1   ~/spark-3.3.2-bin-hadoop3/examples/jars/spark-examples*.jar 1000
```
---

## 🧪 Spark benchmarking with HiBench

This cluster is ready to use with our modernized [HiBench](https://github.com/mgarralda/HiBench) for performance benchmarking of Spark applications, with optional MapReduce-based data generation.

---
##  ♻️ Updated Version

This version is a heavily improved fork of [bartosz25/spark-docker](https://github.com/bartosz25/spark-docker).

---

## 📖 Citation and Academic Use

If this repository, infrastructure, or derived configurations are used in research, technical documentation, benchmarking studies, or industrial reports, please cite the associated doctoral thesis.

```bibtex
@phdthesis{garralda2026selftuning,
  author    = {Mariano Garralda Barrio},
  title     = {AI-Driven Optimization in Distributed Computing Systems: A Self-Tuning Framework},
  school    = {University of Coruña},
  year      = {2026},
  type      = {Doctoral Thesis},
  url       = {https://hdl.handle.net/2183/48114}
}
