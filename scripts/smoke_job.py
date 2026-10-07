"""Run with spark-submit on Standalone or YARN; exercises real Python workers."""
import platform
import socket
import uuid

from pyspark.sql import SparkSession
from pyspark.sql.functions import pandas_udf


def worker_info(_):
    import numpy
    import pandas
    import pyarrow

    yield (socket.gethostname(), platform.python_version(),
           numpy.__version__, pandas.__version__, pyarrow.__version__)


spark = SparkSession.builder.appName("Spark35MigrationSmoke").getOrCreate()
path = "hdfs://spark-cluster-master:9000/tmp/spark35-smoke-" + uuid.uuid4().hex
try:
    assert spark.version == "3.5.9", spark.version
    java = spark.sparkContext._jvm.java.lang.System.getProperty("java.version")
    assert java.startswith("11."), java
    workers = spark.sparkContext.parallelize(range(12), 12).mapPartitions(worker_info).collect()
    assert workers and all(info[1].startswith("3.10.") for info in workers), workers
    assert all(info[2:] == ("1.26.4", "2.2.3", "12.0.1") for info in workers), workers
    print("Worker runtimes:", sorted(set(workers)))

    @pandas_udf("long")
    def increment(values):
        return values + 1

    df = spark.range(100).repartition(6).select(increment("id").alias("value"))
    assert df.groupBy().sum("value").first()[0] == 5050
    df.write.parquet(path)
    restored = spark.read.parquet(path)
    assert restored.count() == 100
    assert restored.groupBy().sum("value").first()[0] == 5050
    print("PASS: Spark/Java/Python versions, distributed Python, Arrow UDF and HDFS round trip")
finally:
    jpath = spark.sparkContext._jvm.org.apache.hadoop.fs.Path(path)
    fs = jpath.getFileSystem(spark.sparkContext._jsc.hadoopConfiguration())
    fs.delete(jpath, True)
    spark.stop()
