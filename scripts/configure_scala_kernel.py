"""Apply Spark's own Java module options to Almond's directly launched JVM."""
import json
import os
import subprocess
import tempfile
from pathlib import Path

spark_home = Path(os.environ['SPARK_HOME'])
launcher = next((spark_home / 'jars').glob('spark-launcher_2.13-*.jar'))
with tempfile.TemporaryDirectory() as directory:
    source = Path(directory) / 'SparkJavaOptions.java'
    source.write_text('''
import org.apache.spark.launcher.JavaModuleOptions;
class SparkJavaOptions {
    public static void main(String[] args) {
        for (String option : JavaModuleOptions.defaultModuleOptionArray()) {
            System.out.println(option);
        }
    }
}
''')
    options = subprocess.check_output(
        ['java', '-cp', str(launcher), str(source)], text=True
    ).splitlines()
kernel = Path.home() / '.local/share/jupyter/kernels/scala_2.13/kernel.json'
spec = json.loads(kernel.read_text())
spec['argv'][1:1] = options
kernel.write_text(json.dumps(spec, indent=2) + '\n')
