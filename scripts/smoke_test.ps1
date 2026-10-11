$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot
try {
    function Invoke-DockerCheck {
        param([string[]]$DockerArgs)
        & docker @DockerArgs
        if ($LASTEXITCODE -ne 0) { throw "Docker check failed: $($DockerArgs -join ' ')" }
    }
    Invoke-DockerCheck -DockerArgs @('compose', 'config', '--quiet')
    Invoke-DockerCheck -DockerArgs @('exec', 'spark-cluster-master', 'bash', '-lc',
        'test "$HADOOP_VERSION" = 3.5.0 && test "$SPARK_VERSION" = 4.2.0 && hdfs dfsadmin -report && yarn node -list')
    Invoke-DockerCheck -DockerArgs @('exec', 'spark-cluster-master', 'bash', '-lc',
        'hdfs dfsadmin -report | grep -q "Live datanodes (3)" && yarn node -list 2>&1 | grep -q "Total Nodes:3"')
    Invoke-DockerCheck -DockerArgs @('exec', 'spark-cluster-master', '/opt/pyspark/bin/python', '-c',
        'import json,urllib.request; data=json.load(urllib.request.urlopen("http://localhost:8080/json/")); workers=[w for w in data["workers"] if w["state"]=="ALIVE"]; assert len(workers)==3,workers; print("PASS: three live Spark workers")')
    Invoke-DockerCheck -DockerArgs @('cp', 'scripts/smoke_job.py', 'spark-cluster-master:/tmp/smoke_job.py')
    foreach ($clusterManager in @('spark://spark-cluster-master:7077', 'yarn')) {
        Invoke-DockerCheck -DockerArgs @('exec', 'spark-cluster-master', 'spark-submit',
            '--master', $clusterManager, '--deploy-mode', 'client',
            '--conf', 'spark.cores.max=3', '--num-executors', '3',
            '--executor-cores', '1', '--executor-memory', '1g', '/tmp/smoke_job.py')
    }
    Invoke-DockerCheck -DockerArgs @('exec', 'spark-cluster-master', 'spark-submit',
        '--master', 'yarn', '--deploy-mode', 'cluster', '--executor-memory', '1g',
        '--executor-cores', '1', '--num-executors', '3', '/tmp/smoke_job.py')
    Invoke-DockerCheck -DockerArgs @('exec', 'spark-cluster-master', 'bash', '-lc',
        'spark-submit --master yarn --deploy-mode cluster --num-executors 1 --executor-memory 1g --class org.apache.spark.examples.SparkPi "$SPARK_HOME"/examples/jars/spark-examples_2.13-*.jar 10')
    Invoke-DockerCheck -DockerArgs @('exec', 'spark-cluster-master', 'bash', '-lc',
        'hadoop jar "$HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.5.0.jar" pi 2 100')
    Invoke-DockerCheck -DockerArgs @('exec', 'spark-cluster-jupyterlab', '/opt/notebook/bin/python', '-c',
        'import sys,pyspark; assert sys.version_info[:2] == (3,12); assert pyspark.__version__ == "4.2.0"; print(sys.version, pyspark.__version__)')
    Invoke-DockerCheck -DockerArgs @('exec', 'spark-cluster-jupyterlab', 'jupyter', 'kernelspec', 'list')
    Write-Host 'Smoke checks passed. Run validate_notebooks.py and validate_persistence.ps1 to complete cluster acceptance. HiBench is deferred.'
} finally {
    Pop-Location
}
