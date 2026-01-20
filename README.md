# CadastralFlow — Parcel DXF Exporter (R2000)

Minimal exporter that connects to an existing PostgreSQL database, runs one optimized query, and writes per‑district DXF files in R2000 format. Each parcel is drawn as an exterior `LWPOLYLINE` and labeled at its centroid with `"Mahalle-Parsel-Ada"`.

## Folder Structure

- `src/` — application code (`src/app.py`)
- `scripts/` — runnable scripts (`scripts/command.sh` for cron)
- `config/` — container configs
  - `config/cron.d/dxf_export` — cron job definition (daily 01:00)
  - `config/supervisor/supervisord.conf` — keeps cron in foreground
- `output/` — generated DXF files (`<ILCE>.dxf`)
- `Dockerfile` — container image for the exporter
- `docker-compose.yml` — single service to run the exporter (`cadastralflow`)
- `.env` / `.env.example` — database connection configuration
- `requirements.txt` — Python dependencies

## Requirements

- `Python` 3.13 (or recent 3.x)
- `psycopg2-binary`, `loguru`, `python-dotenv`, `ezdxf`, `shapely`
- Existing PostgreSQL database accessible from the runtime environment

## Configuration

- Set the environment variables in `.env`:
  - `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`
- The app loads `.env` via `python-dotenv` and uses only the optimized SQL (`SQL_QUERY_OPTIMIZED`).
- If PostgreSQL runs on your Windows host, use `DB_HOST=host.docker.internal` so the container can connect to it.
- No database container is started; ensure network/firewall allows the container to reach your existing DB.

## Usage

- Local
  - `pip install -r requirements.txt`
  - `python src/app.py`
- Docker
  - `docker-compose up --build`
  - The container runs `supervisord` which starts `cron` in foreground to keep the container alive.
  - One‑off job run inside container: `docker-compose exec cadastralflow bash -lc "/app/scripts/command.sh"`
  - Optional: add a restart policy in `docker-compose.yml` (`restart: always`) if you want the service to auto‑start on daemon reboot.

## Cron Job

- Schedule: daily at `01:00`.
- Definition file: `config/cron.d/dxf_export`
- Command: `0 1 * * * root /app/scripts/command.sh >> /var/log/dxf_cron.log 2>&1`
- Logs:
  - App logs go to container stdout via `Loguru`.
  - Cron job output is appended to `/var/log/dxf_cron.log` inside the container.
- Change schedule: edit `config/cron.d/dxf_export` and rebuild (`docker-compose up --build`).
- Timezone: cron uses the container's timezone. If you need local time (not UTC), set `TZ` via environment and install `tzdata` in the image. Example compose env: `TZ=Europe/Istanbul`. Example Dockerfile addition: `apt-get update && apt-get install -y tzdata`.
- Verify cron running: `docker-compose exec cadastralflow bash -lc "ps aux | grep -E 'cron|supervisord'"`
- Check latest cron output: `docker-compose exec cadastralflow bash -lc "tail -n 200 /var/log/dxf_cron.log"`

## Outputs

- Location: `outputs/`
- Files: one DXF per district (e.g., `OSMANGAZİ.dxf`).
- Format: `R2000`, layers `PARCELS` (polylines) and `LABELS` (text).
- Label: centroid text `"<Mahalle>-<Parsel>-<Ada>"`.
- Persistence: In Docker, `./outputs` is mounted into the container (`./outputs:/app/outputs`) so files survive container restarts.

## Notes

- Uses only `SQL_QUERY_OPTIMIZED`; no CRS transformations.
- Accepts `Polygon` and `MultiPolygon` geometries via `ORJINAL_WKT`.
- Non‑polygon geometries or invalid WKT are skipped with warning logs.
- Customization: layer names, text height, or line thickness can be adjusted in `src/app.py`.
- Performance: the exporter streams rows and avoids holding full datasets in memory; keep `outputs/` on a fast disk for best results.

## Troubleshooting

- Connectivity: verify `.env` values and that the container/host can reach the DB (`DB_HOST`, `DB_PORT`).
- Permissions: ensure the `outputs/` directory is writable (mounted in compose).
- Logs: check `docker logs` for app output and `/var/log/dxf_cron.log` for cron job messages.
- Windows paths: if you change volume mappings, prefer relative paths (`./outputs`) to avoid drive letter quirks.
