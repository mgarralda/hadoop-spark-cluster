Write-Host "Ubuntu v20.04 + Hadoop v3.3.2 + Spark v3.3.2 + Jupyter Docker Images"

Write-Host "Creating Spark Base Image"
docker rmi --force hadoop_spark_base_image
docker build -f ./Dockerfile -t hadoop_spark_base_image .

Write-Host "Creating Spark Master Image"
docker rmi --force spark_master
docker build -f ./master/Dockerfile -t spark_master .

Write-Host "Creating Spark Slave Image"
docker rmi --force spark_slave
docker build -f ./slave/Dockerfile -t spark_slave .

Write-Host "Creating Jupyter Spark Image"
docker rmi --force spark_jupyter
docker build -f ./Dockerfile.jupyter -t spark_jupyter .
