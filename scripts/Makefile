ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)

.PHONY: all build build_base_image build_master_image build_slave_image build_jupyter_image
all:
	@echo "Run make build to build all four images."

build: build_master_image build_slave_image build_jupyter_image

build_base_image:
	docker build -f "$(ROOT)/Dockerfile" -t hadoop_spark_base_image:4.2.0 "$(ROOT)"

build_master_image: build_base_image
	docker build -f "$(ROOT)/master/Dockerfile" -t spark_master:4.2.0 "$(ROOT)"

build_slave_image: build_base_image
	docker build -f "$(ROOT)/slave/Dockerfile" -t spark_slave:4.2.0 "$(ROOT)"

build_jupyter_image: build_base_image
	docker build -f "$(ROOT)/Dockerfile.jupyter" -t spark_jupyter:4.2.0 "$(ROOT)"
