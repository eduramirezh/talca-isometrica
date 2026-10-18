# Talca Isométrica — tareas del pipeline. Ver README.md.
PY ?= python3
PW ?= uv run --with "playwright==1.63" python   # Python con Playwright, para las capturas (el del sistema no lo tiene)
PORT ?= 8765
DRY_RUN ?= 0
.PHONY: all fetch osm data elevation ruta5 edificios golf pois build check smoke hooks validate diagnostics shots site-assets deploy serve clean

all: data elevation edificios golf pois build         ## pipeline completo (requiere raw/: make fetch)

fetch:                        ## descarga las fuentes a raw/ (~72 MB)
	./pipeline/fetch_sources.sh

osm:                          ## la API map de OSM sobre toda la comuna -> raw/osm/map-comuna.json (caminos rurales, Ruta 5, vía; ~240 cajas la primera vez)
	cd pipeline && $(PY) traces.py tiles-comuna

data:                         ## raw/ + config/trazados.json -> data/geometry.json
	cd pipeline && $(PY) process_geometry.py

elevation:                    ## raw/dem/ (SRTM) -> data/elevation.json
	cd pipeline && $(PY) elevation.py

ruta5:                        ## raw/osm/map-comuna.json -> data/ruta5.json (calzadas y ramales de la Ruta 5; requiere traces.py tiles-comuna)
	cd pipeline && $(PY) traces.py calzadas comuna

edificios:                    ## raw/osm/map-comuna.json + config/edificios.json (+ config/techos.json) -> data/edificios.json (los edificios de OSM donde OSM está completo)
	cd pipeline && $(PY) edificios.py

golf:                         ## la imagen de Esri sobre el Talca Country Club (su contorno, en config/usos.json) -> data/golf.json (pasto cortado y copas)
	cd pipeline && $(PY) golf.py

pois:                         ## pipeline/pois.py -> data/pois.json + data/pois.csv
	cd pipeline && $(PY) pois.py

build:                        ## -> dist/: index.html, assets/ (el script, three.js y los datos, con hash) y los archivos de src/site/ (requiere npm install)
	cd pipeline && $(PY) build.py

check: build                  ## revisión rápida (<1 s): JSON, marcadores, hitos, node --check, los archivos que pide la página; la corre el hook de pre-commit
	$(PY) tools/check.py

smoke: build                  ## carga la página en Chromium y falla si hay errores de consola o la generación sale vacía (~1 min)
	$(PW) tools/screenshot.py shots/smoke.png --strict

hooks:                        ## instala .githooks/ (pre-commit = make check; pre-push = make deploy al empujar main a origin, sin bloquear)
	git config core.hooksPath .githooks

deploy:                       ## make build y sube dist/ a Cloudflare Pages (talca.eduramirez.com); DRY_RUN=1 arma sin subir
	DRY_RUN=$(DRY_RUN) ./scripts/deploy-cloudflare.sh

validate:                     ## compara cada lugar con su dirección en la grilla (requiere raw/)
	cd pipeline && $(PY) geocode.py validate

diagnostics:                  ## paneles PNG de manzanas + calles + trazados (requiere raw/)
	cd pipeline && $(PY) diagnostics.py

shots: build                  ## capturas de referencia en shots/ (requiere npm install + playwright)
	$(PW) tools/screenshot.py shots/vista-inicial.png
	$(PW) tools/screenshot.py shots/corte.png --hash corte-apelaciones
	$(PW) tools/screenshot.py shots/movil-oscuro.png --size 390x844 --dark

site-assets: build            ## src/site/og.jpg (Open Graph, 1200 × 630), apple-touch-icon.png y los pósters del arranque (poster-*.webp), desde el mapa y el favicon
	uv run --with "playwright==1.63" --with pillow python tools/site_assets.py

serve: build                  ## sirve dist/ en http://localhost:$(PORT) y lo abre en el navegador (otro puerto: make serve PORT=9000)
	(sleep 1 && $(PY) -m webbrowser -t http://localhost:$(PORT)/ >/dev/null) & \
	cd dist && $(PY) -m http.server $(PORT)

clean:
	rm -rf shots diagnostics pipeline/__pycache__
