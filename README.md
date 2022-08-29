# hadoop-yarn-spark-docker
This repository contains Docker images for Apache Spark executed on Hadoop YARN

Downloaded from https://github.com/bartosz25/spark-docker in order to upgrade versions and to use on **Windows 10 Docker**.

Versions: Ubuntu 20.04, Spark v2.4.8 and Hadoop v.2.7.7

The purpose of them is to allow programmers to test Spark applications deployed on YARN easier. 
**It was not designed to be deployed in production environments**. The project was tested on Ubuntu 20. 

# Building the cluster
This version uses `docker-compose` to create master and worker containers (nodes). It's executed with standard `docker-compose up` command and the number of workers is  defined with `--scale slave=X` property.

But before calling it, 3 Docker images must be built executing this windows powershell script:
```
build_images.ps1
```

Now we can create a cluster with a master and 3 slaves:
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
docker-compose stopt
``` 

# Spark and Hadoop WebUIs
Spark, HDFS and YARN expose web UI used to track the execution of the applications:
* http://localhost:8088  - YARN UI's address
* http://localhost:18080 - Spark history UI's address
* http://localhost:50070 - Hadoop HDFS NodeManager WebUI

```
open_webuis.ps1
``` 

# Repository structure: Volumen linked
* conf-master: stores master's configuration files are stored there
* conf-slave: stores slave's configuration files are stored there 
* master: contains master's Dockerfile
* slave: contains slave's Dockerfile
* shared-master: this repository is shared between master's Docker container (/home/sparker/shared) and host. 
* shared-slave: this repository is shared between slave Docker containers (/home/sparker/shared) and host

Shared repositories can be used to, for example, put the JAR executed with spark-submit inside.

# Tests
To verify that the cluster was correctly installed, launch _SparkPi_ example:
```
spark-submit --class org.apache.spark.examples.SparkPi --master yarn --deploy-mode cluster --driver-memory 1g --executor-memory 1g --executor-cores 1 ~/spark-2.4.8-bin-hadoop2.7/examples/jars/spark-examples*.jar 1000
```

# Troubleshooting
## "Unhealthy Node local-dirs and log-dirs"
I encounter the issue when I had too few available disk space. It makes that the slave nodes are detected as unhealthy. You can fix that either by playing with the configuration 
https://stackoverflow.com/questions/29131449/why-does-hadoop-report-unhealthy-node-local-dirs-and-log-dirs-are-bad or simply by ensuring that you have enough free disk space
