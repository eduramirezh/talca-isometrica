"""Rutas y proyección compartidas por todo el pipeline.

Sistema de coordenadas local ("metros de grilla"):
  * Origen: centro de la Plaza de Armas de Talca (-35.42653, -71.66600).
  * Proyección equirectangular local (suficiente a escala de ciudad, error < 0,1 %).
  * Rotación de +5°: la grilla de calles numeradas de Talca está girada ~5° en sentido
    horario respecto del norte; al girar las coordenadas +5° las calles Norte/Sur quedan
    paralelas al eje x y las Oriente/Poniente al eje y. Así la grilla calza con los ejes
    isométricos del render.
  * x crece hacia el oriente, y hacia el norte. En three.js: X = x, Z = -y.
"""
import math, os
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW = Path(os.environ.get('TALCA_RAW', ROOT / 'raw'))        # fuentes descargadas (no versionadas)
DATA = ROOT / 'data'                                           # datos procesados (versionados)
CONFIG = ROOT / 'config'

MANZANAS_DIR = RAW / 'chile_geojson' / 'manzanas'
NAV_GRAPH = RAW / 'cicloconecta' / 'data' / 'cities' / 'talca' / 'nav_graph.json'

LAT0, LON0 = -35.42653, -71.66600
KX = 111320 * math.cos(math.radians(35.4265))   # metros por grado de longitud
KY = 110950                                      # metros por grado de latitud
TH = math.radians(5.0)                           # giro de la grilla

def loc(lon, lat):
    """(lon, lat) -> (x, y) en metros de grilla."""
    x = (lon - LON0) * KX
    y = (lat - LAT0) * KY
    return (x * math.cos(TH) - y * math.sin(TH), x * math.sin(TH) + y * math.cos(TH))

def unloc(x, y):
    """(x, y) en metros de grilla -> (lat, lon)."""
    xr = x * math.cos(-TH) - y * math.sin(-TH)
    yr = x * math.sin(-TH) + y * math.cos(-TH)
    return (LAT0 + yr / KY, LON0 + xr / KX)

def require(path, hint='Ejecute primero: make fetch'):
    if not Path(path).exists():
        raise SystemExit(f'Falta {path}.\n{hint}')
    return path
