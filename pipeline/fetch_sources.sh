#!/usr/bin/env bash
# Descarga las dos fuentes de datos públicas a raw/ (≈ 60 MB tras el sparse checkout).
#   1. Manzanas del Censo 2017 (INE) en GeoJSON  — github.com/jiboncom/chile_geojson
#   2. Grafo vial de Talca extraído de OpenStreetMap — github.com/Shiroku36/cicloconecta
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

echo "Listo. Fuentes en $RAW/"
