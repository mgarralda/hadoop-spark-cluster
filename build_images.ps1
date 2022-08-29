Write-Host "Ubuntu v.20.4 + Hadoop v.2.7.7 + Spark v.2.4.8 + Docker Images"

Write-Host "Creating Spark Base Image"
docker rmi --force spark_base_image; docker build -f ./Dockerfile . -t spark_base_image

Write-Host "Creating Spark Master Image"
docker rmi --force spark_compose_master; docker build -f ./master/Dockerfile . -t spark_compose_master

Write-Host "Creating Spark Slave Image"
docker rmi --force spark_compose_slave; docker build -f ./slave/Dockerfile . -t spark_compose_slave
