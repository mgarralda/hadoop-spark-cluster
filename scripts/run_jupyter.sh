#!/usr/bin/env bash
set -euo pipefail
exec jupyter lab --ip=0.0.0.0 --port=8888 --no-browser \
    --ServerApp.root_dir=/home/jovyan/work "$@"
