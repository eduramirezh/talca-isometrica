#!/usr/bin/env bash
# Descarga las fuentes de datos públicas a raw/ (≈ 117 MB tras el sparse checkout).
#   1. Manzanas del Censo 2017 (INE) en GeoJSON  — github.com/jiboncom/chile_geojson
#   2. Grafo vial de Talca extraído de OpenStreetMap — github.com/Shiroku36/cicloconecta
#   3. Elevación Copernicus DEM GLO-30 (tesela S36W072, 45 MB) del bucket público de AWS — registry.opendata.aws/copernicus-dem
#   4. Elevación SRTM 1" (tesela S36W072) de los Terrain Tiles de AWS — registry.opendata.aws/terrain-tiles
#      (el relieve hasta octubre de 2026; elevation.py --srtm, para comparar)
# Solo se baja lo necesario para la Región del Maule / Talca.
set -euo pipefail
cd "$(dirname "$0")/.."
RAW="${TALCA_RAW:-raw}"
mkdir -p "$RAW"

clone_sparse () {  # repo destino rutas...
  local repo="$1" dest="$2"; shift 2
  if [ -d "$dest/.git" ]; then echo "· $dest ya existe, se omite"; return; fi
  git clone --depth 1 --filter=blob:none --sparse "https://github.com/$repo" "$dest"
  git -C "$dest" sparse-checkout set --no-cone "$@"
}

clone_sparse jiboncom/chile_geojson "$RAW/chile_geojson" \
  '/manzanas/R07_MANZANA_IND_C17.shp.geojson' \
  '/manzanas/R07_MANZANA_SIN_INF_C17.shp.geojson' \
  '/manzanas/R07_MANZANA_ALDEA_C17.shp.geojson' '/README.md'

clone_sparse Shiroku36/cicloconecta "$RAW/cicloconecta" \
  '/data/cities/talca/*' '/README*' '/pipeline/*'

mkdir -p "$RAW/dem"
if [ -f "$RAW/dem/S36W072.hgt.gz" ]; then echo "· $RAW/dem/S36W072.hgt.gz ya existe, se omite"
else curl -fL --retry 3 -o "$RAW/dem/S36W072.hgt.gz" https://s3.amazonaws.com/elevation-tiles-prod/skadi/S36/S36W072.hgt.gz; fi

COP=Copernicus_DSM_COG_10_S36_00_W072_00_DEM
mkdir -p "$RAW/dem/copernicus"
if [ -f "$RAW/dem/copernicus/$COP.tif" ]; then echo "· $RAW/dem/copernicus/$COP.tif ya existe, se omite"
else curl -fL --retry 3 -o "$RAW/dem/copernicus/$COP.tif" "https://copernicus-dem-30m.s3.amazonaws.com/$COP/$COP.tif"; fi

echo "Listo. Fuentes en $RAW/"
