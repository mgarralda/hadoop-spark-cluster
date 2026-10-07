"""Run inside Jupyter: validate Scala notebooks and their History Server entries."""
import json
import time
import urllib.request
from pathlib import Path

import nbformat
from nbclient import NotebookClient


def main():
    output = Path('/tmp/scala-validation')
    output.mkdir(exist_ok=True)
    paths = sorted(Path('/home/jovyan/work').glob('scala_*.ipynb'))
    if len(paths) != 3:
        raise RuntimeError(f'Expected three Scala notebooks, found {len(paths)}')
    applications = {}
    marker = 'VALIDATION_SPARK_APPLICATION_ID='
    for path in paths:
        print('RUN', path.name, flush=True)
        notebook = nbformat.read(path, as_version=4)
        for cell in notebook.cells:
            if cell.cell_type == 'code' and 'getOrCreate()' in cell.source:
                cell.source += '''
assert(spark.version == "3.5.9")
assert(spark.sparkContext.getConf.getBoolean("spark.eventLog.enabled", false))
assert(spark.sparkContext.hadoopConfiguration.get("fs.defaultFS") == "hdfs://spark-cluster-master:9000")
println("VALIDATION_SPARK_APPLICATION_ID=" + spark.sparkContext.applicationId)
'''
        NotebookClient(notebook, timeout=300, startup_timeout=180,
                       resources={'metadata': {'path': str(path.parent)}}).execute()
        nbformat.write(notebook, output / path.name)
        for cell in notebook.cells:
            for result in cell.get('outputs', []):
                for line in result.get('text', '').splitlines():
                    if line.startswith(marker):
                        applications[path.name] = line[len(marker):].strip()
        print('PASS', path.name, flush=True)
    if len(applications) != 2:
        raise RuntimeError(f'Expected two Spark applications, found {applications}')
    deadline = time.monotonic() + 120
    while True:
        with urllib.request.urlopen(
            'http://spark-cluster-master:18080/api/v1/applications', timeout=15
        ) as response:
            history = {app['id']: app for app in json.load(response)}
        if all(any(attempt.get('completed') and
                   attempt.get('appSparkVersion') == '3.5.9'
                   for attempt in history.get(app_id, {}).get('attempts', []))
               for app_id in applications.values()):
            break
        if time.monotonic() >= deadline:
            raise RuntimeError(f'Completed applications missing from history: {applications}')
        time.sleep(3)
    report = {'spark_version': '3.5.9', 'applications': applications,
              'notebooks': [path.name for path in paths], 'history_completed': True}
    (output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print('PASS History Server:', json.dumps(applications), flush=True)


if __name__ == '__main__':
    main()
