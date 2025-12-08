#!/bin/bash
set -e

# Set PATH to include user local bin
export PATH=/home/appuser/.local/bin:$PATH

# Collect static files (use full python path to ensure it works)
/home/appuser/.local/bin/python /app/manage.py collectstatic --noinput || echo "Warning: collectstatic failed, continuing anyway"

# Start Gunicorn (use full path)
exec /home/appuser/.local/bin/gunicorn --bind 0.0.0.0:8000 --workers 4 --threads 2 --worker-class gthread --timeout 120 --access-logfile - --error-logfile - whoosh_api.wsgi:application

