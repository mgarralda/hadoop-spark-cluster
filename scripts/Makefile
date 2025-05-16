all:
	@echo "Available commands are:"
	@echo "- build_base_image   - builds shared image"
	@echo "- build_master_image - builds master image"
	@echo "- build_slave_image  - builds slave image"

build_base_image:
	docker rmi --force hadoop_spark_base_image; docker build -f ./Dockerfile . -t hadoop_spark_base_image

build_master_image:
	docker rmi --force spark_master; docker build -f ./master/Dockerfile . -t spark__master

build_slave_image:
	docker rmi --force spark_slave; docker build -f ./slave/Dockerfile . -t spark_slave

build_jupyter_image:
    docker rmi --force spark_jupyter; docker build -f ./Dockerfile.jupyter . -t spark_jupyter
