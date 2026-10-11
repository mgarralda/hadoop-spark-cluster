"""Execute notebook copies inside Jupyter and verify exact History Server IDs."""
import argparse
import json
import time
import urllib.request
from pathlib import Path

import nbformat
from nbclient import NotebookClient


def main(language='all'):
    output = Path('/tmp/notebook-validation')
    output.mkdir(exist_ok=True)
    workspace = Path('/home/jovyan/work')
    prefixes = {'all': ('scala_', 'pyspark_'), 'scala': ('scala_',),
                'python': ('pyspark_',)}[language]
    paths = sorted(path for path in workspace.glob('*.ipynb')
                   if path.name.startswith(prefixes))
    expected = {'all': 9, 'scala': 4, 'python': 5}[language]
    if len(paths) != expected:
        raise RuntimeError(f'Expected {expected} notebooks, found {len(paths)}')
    applications = {}
    marker = 'VALIDATION_SPARK_APPLICATION_ID='
    for path in paths:
        print('RUN', path.name, flush=True)
        notebook = nbformat.read(path, as_version=4)
        scala = path.name.startswith('scala_')
        has_spark = False
        for cell in notebook.cells:
            if cell.cell_type != 'code' or 'getOrCreate()' not in cell.source:
                continue
            has_spark = True
            if scala:
                cell.source += '''
assert(spark.version == "4.2.0")
assert(scala.util.Properties.versionNumberString == "2.13.18")
assert(System.getProperty("java.version").startsWith("17."))
assert(spark.sparkContext.getConf.getBoolean("spark.eventLog.enabled", false))
assert(spark.sparkContext.hadoopConfiguration.get("fs.defaultFS") == "hdfs://spark-cluster-master:9000")
println("VALIDATION_SPARK_APPLICATION_ID=" + spark.sparkContext.applicationId)
'''
            else:
                cell.source += '''
import sys
assert sys.version_info[:2] == (3, 12)
assert spark.version == "4.2.0"
assert spark.sparkContext.getConf().get("spark.eventLog.enabled") == "true"
assert spark.sparkContext._jsc.hadoopConfiguration().get("fs.defaultFS") == "hdfs://spark-cluster-master:9000"
print("VALIDATION_SPARK_APPLICATION_ID=" + spark.sparkContext.applicationId)
'''
        if scala and not has_spark:
            notebook.cells.append(nbformat.v4.new_code_cell(
                'assert(scala.util.Properties.versionNumberString == "2.13.18")'))
        NotebookClient(notebook, timeout=600, startup_timeout=180,
                       resources={'metadata': {'path': str(path.parent)}}).execute()
        nbformat.write(notebook, output / path.name)
        for cell in notebook.cells:
            for result in cell.get('outputs', []):
                for line in result.get('text', '').splitlines():
                    if line.startswith(marker):
                        applications[path.name] = line[len(marker):].strip()
        if has_spark and path.name not in applications:
            raise RuntimeError(f'Application ID missing from {path.name}')
        print('PASS', path.name, flush=True)
    expected_apps = {'all': 7, 'scala': 3, 'python': 4}[language]
    if len(applications) != expected_apps:
        raise RuntimeError(f'Expected {expected_apps} Spark applications: {applications}')
    deadline = time.monotonic() + 120
    while True:
        with urllib.request.urlopen(
            'http://spark-cluster-master:18080/api/v1/applications', timeout=15
        ) as response:
            history = {app['id']: app for app in json.load(response)}
        if all(any(attempt.get('completed') and
                   attempt.get('appSparkVersion') == '4.2.0'
                   for attempt in history.get(app_id, {}).get('attempts', []))
               for app_id in applications.values()):
            break
        if time.monotonic() >= deadline:
            raise RuntimeError(f'Completed applications missing from history: {applications}')
        time.sleep(3)
    report = {'spark_version': '4.2.0', 'applications': applications,
              'notebooks': [path.name for path in paths], 'history_completed': True}
    (output / f'report-{language}.json').write_text(json.dumps(report, indent=2) + '\n')
    print('PASS History Server:', json.dumps(applications), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--language', choices=('all', 'scala', 'python'), default='all')
    main(parser.parse_args().language)
