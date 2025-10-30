import os
import sys
import time
import re
from typing import Optional

import psycopg2
import psycopg2.extras
from loguru import logger
from dotenv import load_dotenv
import ezdxf
from shapely import wkt as shapely_wkt
from shapely.geometry import Polygon, MultiPolygon

ezdxf.fonts.fonts.make_font(r'C:\WINDOWS\Fonts\tahoma.ttf', cap_height=1.2, width_factor=0.9)

# Loguru format: [YYYY-MM-DD HH:MM:SS] - message
logger.remove()
logger.add(sys.stdout, format="[{time:YYYY-MM-DD HH:mm:ss}] - {message}", level="INFO")


# SQL query: geometrileri SRID 2320’ye normalize eder
QUERY = """
SELECT 
    i.ad AS "ILCE_ADI",
    m.tapumahallead AS "TAPU_MAHALLE_ADI",
    p.adano AS "ADA",
    p.parselno AS "PARSEL",
    ST_AsText(ST_Transform(p.geom, 2320)) AS "ORJINAL_WKT"
FROM public.tk_parsel p
INNER JOIN public.tk_mahalle m ON m.tapukimlikno = p.tapumahalleref
INNER JOIN public.tk_ilce i ON i.fid = m.ilceref
WHERE p.durum <> '2' and i.ad = 'GÜRSU'
ORDER BY i.ad
"""


def _sanitize_filename(name: str) -> str:
    invalid = '<>:"/\\|?*'
    sanitized = ''.join('_' if ch in invalid else ch for ch in (name or ''))
    return sanitized.strip() or 'UNKNOWN'


def _turkish_to_ascii(text: str) -> str:
    """Map Turkish-specific letters to ASCII equivalents (escape Turkish).
    Examples: Ş→S, İ→I, Ğ→G, ç→c, ı→i, ö→o, ü→u.
    """
    if not isinstance(text, str):
        return text
    mapping = {
        'Ş': 'S', 'ş': 's',
        'İ': 'I', 'ı': 'i',
        'Ğ': 'G', 'ğ': 'g',
        'Ç': 'C', 'ç': 'c',
        'Ö': 'O', 'ö': 'o',
        'Ü': 'U', 'ü': 'u',
    }
    return ''.join(mapping.get(ch, ch) for ch in text)


def _normalize_text(s: str) -> str:
    """Normalize text containing literal unicode escapes.
    Supports patterns like 'YEN\u0130CE', '\\U+0130', and 'U+0130'.
    Only converts unicode escapes; leaves other escapes intact.
    """
    if not isinstance(s, str):
        return s
    text = s
    # Convert U+XXXX or \U+XXXX to actual characters
    def repl_uplus(match):
        code = match.group(1)
        try:
            return chr(int(code, 16))
        except Exception:
            return match.group(0)
    text = re.sub(r'(?:\\)?U\+([0-9A-Fa-f]{4,6})', repl_uplus, text)

    # Convert \uXXXX and \UXXXXXXXX escapes
    def repl_uesc(match):
        code = match.group(1)
        try:
            return chr(int(code, 16))
        except Exception:
            return match.group(0)
    text = re.sub(r'\\u([0-9A-Fa-f]{4})', repl_uesc, text)
    text = re.sub(r'\\U([0-9A-Fa-f]{8})', repl_uesc, text)
    # Finally, escape Turkish letters to ASCII fallbacks
    text = _turkish_to_ascii(text)
    return text


def _new_dxf_doc(version: str = 'AC1015'):
    doc = ezdxf.new(dxfversion=version)
    # minimal layers
    # set explicit colors to avoid white-on-white invisibility in some viewers
    doc.layers.new('PARCELS', dxfattribs={'color': 1, 'linetype': 'Continuous'})  # red
    doc.layers.new('LABELS', dxfattribs={'color': 2, 'linetype': 'Continuous'})   # yellow
    # Turkish codepage for proper rendering of Turkish characters
    try:
        doc.header['$DWGCODEPAGE'] = 'ANSI_1254'
    except Exception:
        pass
    return doc


def export_dxf_per_district(
    conn,
    output_dir: str,
    text_height: float = 1.2,
    width_factor: float = 0.9,
) -> None:
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
            
            try:
                doc.saveas(out_path, encoding='cp1254')
            except Exception:
                # Fallback: UTF-8 encoding dene
                try:
                    doc.saveas(out_path, encoding='utf-8')
                except Exception:
                    # Final fallback to default encoding
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
                doc = _new_dxf_doc('AC1015')
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

            # Label at centroid: mahalle-parsel-ada (normalized and ASCII-safe)
            label = f"{_normalize_text(mahalle)}-{_normalize_text(ada)}-{_normalize_text(parsel)}"
            c = geom.centroid
            x, y = float(c.x), float(c.y)
            txt = msp.add_text(label, dxfattribs={'height': text_height, 'layer': 'LABELS'})
            try:
                txt.dxf.width = float(width_factor)
            except Exception:
                pass
            # Robust placement across ezdxf versions
            try:
                txt.set_pos((x, y), align='MIDDLE_CENTER')
            except Exception:
                try:
                    # Older API
                    txt.set_placement((x, y))
                except Exception:
                    try:
                        # Manual alignment
                        txt.dxf.halign = 1  # center
                        txt.dxf.valign = 2  # middle
                        txt.dxf.align_point = (x, y)
                    except Exception:
                        # Final fallback: simple insert
                        txt.dxf.insert = (x, y)

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
        try:
            conn.set_client_encoding('UTF8')
        except Exception:
            pass
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