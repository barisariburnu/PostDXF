import os
import sys
import time
from typing import Optional

import psycopg2
import psycopg2.extras
from loguru import logger
from dotenv import load_dotenv
import ezdxf
from shapely import wkt as shapely_wkt
from shapely.geometry import Polygon, MultiPolygon


# Loguru format: [YYYY-MM-DD HH:MM:SS] - message
logger.remove()
logger.add(sys.stdout, format="[{time:YYYY-MM-DD HH:mm:ss}] - {message}", level="INFO")


# Only SQL query (no CAST, minimal JOINs)
QUERY = """
SELECT 
    i.ad AS "ILCE_ADI",
    m.tapumahallead AS "TAPU_MAHALLE_ADI",
    p.adano AS "ADA",
    p.parselno AS "PARSEL",
    p.geom AS "GEOMETRY",
    p.orjinalgeomwkt AS "ORJINAL_WKT"
FROM public.tk_parsel p
INNER JOIN public.tk_mahalle m ON m.tapukimlikno = p.tapumahalleref
INNER JOIN public.tk_ilce i ON i.fid = m.ilceref
WHERE p.durum <> '2'
ORDER BY i.ad
"""


def _sanitize_filename(name: str) -> str:
    invalid = '<>:"/\\|?*'
    sanitized = ''.join('_' if ch in invalid else ch for ch in (name or ''))
    return sanitized.strip() or 'UNKNOWN'


def _new_dxf_doc(version: str = 'R2000'):
    doc = ezdxf.new(version)
    # minimal layers
    doc.layers.new('PARCELS')
    doc.layers.new('LABELS')
    return doc


def export_dxf_per_district(conn, output_dir: str, text_height: float = 2.5) -> None:
    t0 = time.perf_counter()
    cursor = conn.cursor(name='parcel_stream', cursor_factory=psycopg2.extras.DictCursor)
    cursor.itersize = 2000
    logger.info('Sorgu başlatılıyor: SQL (DXF)')
    cursor.execute(QUERY)

    current_ilce: Optional[str] = None
    doc = None
    msp = None
    district_start = None
    district_count = 0

    def save_current():
        nonlocal doc, msp, current_ilce, district_start, district_count
        if doc and current_ilce:
            filename = _sanitize_filename(current_ilce) + '.dxf'
            out_path = os.path.join(output_dir, filename)
            os.makedirs(output_dir, exist_ok=True)
            doc.saveas(out_path)
            elapsed = time.perf_counter() - (district_start or t0)
            logger.info(f"İlçe tamamlandı: {current_ilce}, süre={elapsed:.2f} sn, parsel={district_count}")
        doc = None
        msp = None
        district_start = None
        district_count = 0

    try:
        for row in cursor:
            ilce = (row['ILCE_ADI'] or '')
            mahalle = (row['TAPU_MAHALLE_ADI'] or '')
            ada = str(row['ADA'] or '')
            parsel = str(row['PARSEL'] or '')
            wkt_str = row['ORJINAL_WKT']

            if current_ilce != ilce:
                # new district boundary
                if current_ilce is not None:
                    save_current()
                current_ilce = ilce
                doc = _new_dxf_doc('R2000')
                msp = doc.modelspace()
                district_start = time.perf_counter()
                logger.info(f"İlçe başladı: {current_ilce}")

            if not wkt_str:
                logger.info("Uyarı: WKT boş, atlandı")
                continue

            try:
                geom = shapely_wkt.loads(wkt_str)
            except Exception:
                logger.info("Uyarı: WKT çözümlenemedi, atlandı")
                continue

            polygons = []
            if isinstance(geom, Polygon):
                polygons = [geom]
            elif isinstance(geom, MultiPolygon):
                polygons = list(geom.geoms)
            else:
                logger.info("Uyarı: beklenmeyen geometri tipi, atlandı")
                continue

            # Draw exterior ring only
            for poly in polygons:
                pts = [(float(x), float(y)) for x, y in list(poly.exterior.coords)]
                msp.add_lwpolyline(pts, close=True, dxfattribs={'layer': 'PARCELS'})

            # Label at centroid: mahalle-parsel-ada
            label = f"{mahalle}-{parsel}-{ada}"
            c = geom.centroid
            txt = msp.add_text(label, dxfattribs={'height': text_height, 'layer': 'LABELS'})
            try:
                txt.set_pos((float(c.x), float(c.y)), align='MIDDLE_CENTER')
            except Exception:
                # Fallback: place at insert without alignment
                pass

            district_count += 1

        # finalize last district
        save_current()
    except Exception as e:
        logger.info(f"Kritik hata: sorgu/çizim sırasında: {e}")
        raise
    finally:
        cursor.close()
        total_elapsed = time.perf_counter() - t0
        logger.info(f"Tüm işlem tamamlandı. Toplam süre={total_elapsed:.2f} sn")


def main() -> None:
    load_dotenv()
    t0_app = time.perf_counter()

    db_host = os.getenv('DB_HOST', 'localhost')
    db_port = int(os.getenv('DB_PORT', '5432'))
    db_user = os.getenv('DB_USER', '')
    db_password = os.getenv('DB_PASSWORD', '')
    db_name = os.getenv('DB_NAME', '')

    output_dir = os.path.join(os.getcwd(), 'outputs')
    os.makedirs(output_dir, exist_ok=True)

    logger.info('Veritabanına bağlanılıyor...')
    conn = None
    try:
        conn = psycopg2.connect(
            host=db_host,
            port=db_port,
            user=db_user,
            password=db_password,
            dbname=db_name,
        )
        logger.info('Bağlantı başarılı. Sorgu ile DXF üretilecek.')
        export_dxf_per_district(conn, output_dir)
    except Exception as e:
        logger.info(f"Kritik hata: veritabanı bağlantısı/sorgu: {e}")
        sys.exit(1)
    finally:
        if conn is not None:
            try:
                conn.close()
            except Exception:
                pass
        total_elapsed_app = time.perf_counter() - t0_app
        logger.info(f'İşlem tamamlandı. Toplam süre={total_elapsed_app:.2f} sn')


if __name__ == '__main__':
    main()