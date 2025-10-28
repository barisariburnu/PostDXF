#!/bin/sh
set -eu

cd /app
echo "[$(date +'%Y-%m-%d %H:%M:%S')] - DXF export job started"
python /app/src/app.py
echo "[$(date +'%Y-%m-%d %H:%M:%S')] - DXF export job finished"