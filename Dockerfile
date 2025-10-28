# syntax=docker/dockerfile:1

FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Install Python dependencies first for better layer caching
COPY requirements.txt ./
RUN apt-get update && apt-get install -y --no-install-recommends vim cron supervisor \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY src/ ./src/
COPY scripts/ ./scripts/
COPY config/cron.d/dxf_export /etc/cron.d/dxf_export
COPY config/supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
RUN chmod +x /app/scripts/command.sh && chmod 0644 /etc/cron.d/dxf_export

# Default command: run the exporter (reads .env via python-dotenv in app.py)
CMD ["supervisord", "-n", "-c", "/etc/supervisor/conf.d/supervisord.conf"]