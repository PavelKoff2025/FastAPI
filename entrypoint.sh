#!/bin/sh
set -e

exec gunicorn main:app \
  --worker-class uvicorn.workers.UvicornWorker \
  --bind "${HOST:-0.0.0.0}:${PORT:-8000}" \
  --workers "${WORKERS:-1}" \
  --log-level "${LOG_LEVEL:-info}" \
  --access-logfile - \
  --error-logfile -
