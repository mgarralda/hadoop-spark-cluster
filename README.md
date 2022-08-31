# hadoop-yarn-spark-docker-cluster
This repository contains Docker images for Apache Spark executed on Hadoop YARN.

Upgraded project downloaded from https://github.com/bartosz25/spark-docker in order to be feasible with new versions of Spark/Hadoop and whether use on **Windows 10 Docker** or **Linux**.

Image versions: Ubuntu 20.04, Spark v2.4.8 and Hadoop v.2.7.7

The purpose of them is to allow programmers to test Spark applications deployed on YARN easier. 
**It was not designed to be deployed in production environments**.

# Building the cluster

Download and unzip all files inside a folder named "hadoop-spark-cluster".

This project uses `docker-compose` to create a master and worker containers (nodes). It's executed with standard `docker-compose up` command and the number of workers is  defined with `--scale slave=X` property.

But before calling it, 3 Docker images must be built executing this windows powershell script:
```
build_images.ps1
```
On Linux:
```
make build_base_image
make build_master_image
make build_slave_image
```
Now we can create the cluster with a master and 3 slaves:
```
docker-compose up -d --scale slave=3
``` 
Stops containers and removes containers, networks, volumes, and images created by up:
```
docker-compose down
``` 
If the cluster exists and you just want to start or stop it:
```
docker-compose start
``` 
```
docker-compose stop
``` 

# Spark and Hadoop WebUIs
Spark, HDFS and YARN expose web UI used to track the execution of the applications:
* http://localhost:8088  - YARN UI's address
* http://localhost:18080 - Spark history UI's address
* http://localhost:50070 - Hadoop HDFS NodeManager WebUI

# Repository structure: Volumen linked
* conf-master: stores master's configuration files are stored there
* conf-slave: stores slave's configuration files are stored there 
* master: contains master's Dockerfile
* slave: contains slave's Dockerfile
* shared-master: this repository is shared between master's Docker container (/home/sparker/shared) and host. 
* shared-slave: this repository is shared between slave Docker containers (/home/sparker/shared) and host

Shared repositories can be used to, for example, put the JAR executed with spark-submit inside.

# To get access and run spark-submit commands inside the cluster, type the following in a Windows terminal:
```
docker exec -it hadoop-spark-cluster_master_1 /bin/bash
``` 

# Tests
To verify that the cluster was correctly installed, launch _SparkPi_ example:
```
spark-submit --class org.apache.spark.examples.SparkPi --master yarn --deploy-mode cluster --driver-memory 1g --executor-memory 1g --executor-cores 1 ~/spark-2.4.8-bin-hadoop2.7/examples/jars/spark-examples*.jar 1000
```

# Troubleshooting
## "Unhealthy Node local-dirs and log-dirs"
I encounter the issue when I had too few available disk space. It makes that the slave nodes are detected as unhealthy. You can fix that either by playing with the configuration 
https://stackoverflow.com/questions/29131449/why-does-hadoop-report-unhealthy-node-local-dirs-and-log-dirs-are-bad or simply by ensuring that you have enough free disk space
