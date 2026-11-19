# Talca Isométrica — tareas del pipeline. Ver README.md.
PY ?= python3
# pin: «paquete==versión» de requirements.txt (la fuente de las versiones de Python; Dependabot la sube)
pin = $(strip $(shell sed -n 's/^\($(1)==[^ ]*\).*/\1/p' $(CURDIR)/requirements.txt))
PW ?= uv run --with "$(call pin,playwright)" python   # Python con Playwright, para las capturas (el del sistema no lo tiene)
PIL ?= uv run --with "$(call pin,pillow)" python      # Python con Pillow: lo que lee las teselas de Esri (golf) o dibuja paneles
ifeq ($(shell uname -s),Darwin)
GODOT ?= /Applications/Godot.app/Contents/MacOS/Godot
else
GODOT ?= $(or $(shell command -v godot 2>/dev/null),$(shell command -v godot4 2>/dev/null),godot)   # Linux: godot o godot4 del PATH
endif
PORT ?= 8765
DRY_RUN ?= 0
CINE ?= 1920x1080             # la resolución de make cine (1280x720 para una prueba rápida)
CINE_CRF ?= 20                # la calidad del H.264 de make cine (18: ~100 MB los 30 s; 23: ~45 MB)
.PHONY: all fetch osm data elevation ruta5 sentidos edificios edificios-ml golf pois build check golden lint smoke hooks validate diagnostics shots site-assets juego cine deploy serve clean

all: data elevation edificios golf pois build         ## pipeline completo (requiere raw/: make fetch)

fetch:                        ## descarga las fuentes a raw/ (~117 MB)
	./pipeline/fetch_sources.sh

osm:                          ## la API map de OSM sobre toda la comuna -> raw/osm/map-comuna.json (caminos rurales, Ruta 5, vía; ~240 cajas la primera vez)
	cd pipeline && $(PY) traces.py tiles-comuna

data:                         ## raw/ + config/trazados.json -> data/geometry.json
	cd pipeline && $(PY) process_geometry.py

elevation:                    ## raw/dem/copernicus/ (Copernicus GLO-30; pipeline/geotiff.py lo lee) -> data/elevation.json
	cd pipeline && $(PY) elevation.py

ruta5:                        ## raw/osm/map-comuna.json -> data/ruta5.json (calzadas y ramales de la Ruta 5; requiere traces.py tiles-comuna)
	cd pipeline && $(PY) traces.py calzadas comuna

sentidos:                     ## raw/osm/map-comuna.json -> data/sentidos.json (las calles de un sentido de OSM, para las flechas de los letreros del juego; requiere make osm)
	cd pipeline && $(PY) sentidos.py

edificios:                    ## raw/osm/map-comuna.json + config/edificios.json (+ config/techos.json) -> data/edificios.json (los edificios de OSM y, donde OSM no los tiene, las huellas de raw/edificios-ml/)
	cd pipeline && $(PY) edificios.py

edificios-ml:                 ## raw/overture, raw/msbuildings, raw/google-open-buildings* -> raw/edificios-ml/ (huellas de aprendizaje automático y alturas de Google 2.5D, para make edificios; uv)
	uv run --with-requirements requirements-geo.txt python -I tools/ml_buildings.py

golf:                         ## la imagen de Esri sobre el Talca Country Club (su contorno, en config/usos.json) -> data/golf.json (pasto cortado y copas; Pillow, por uv)
	cd pipeline && $(PIL) golf.py

pois:                         ## pipeline/pois.py -> data/pois.json + data/pois.csv
	cd pipeline && $(PY) pois.py

build:                        ## -> dist/: index.html, assets/ (el script, three.js y los datos, con hash) y los archivos de src/site/ (requiere npm install)
	cd pipeline && $(PY) build.py

check: build                  ## revisión rápida (~1 s): JSON, marcadores, hitos, node --check, los archivos que pide la página, trampas de config/ y data/, las pruebas de tests/ y que todo el Python compile; la corre el hook de pre-commit
	$(PY) tools/check.py
	$(PY) -m compileall -q pipeline tools tests
	$(PY) -m unittest discover -s tests -q

golden:                       ## las salidas de los comandos del pipeline contra una referencia (antes de refactorizar: make golden REF=shots/golden-ref SAVE=1; ~5 min)
	$(PY) tests/golden.py $(if $(SAVE),--save,--against) $(or $(REF),shots/golden-ref)

lint:                         ## ESLint (versión fija de package.json: npm install) sobre el script unido, con el archivo y la línea de src/ (~1 s; tools/lint.py)
	$(PY) tools/lint.py

smoke: build lint             ## carga la página en Chromium y falla si hay errores de consola o la generación sale vacía (~1 min)
	$(PW) tools/screenshot.py shots/smoke.png --strict

hooks:                        ## instala .githooks/ (pre-commit = make check; pre-push = make deploy al empujar main a origin, sin bloquear)
	git config core.hooksPath .githooks

juego: build                  ## juego/mapa/: la comuna en teselas de 500 m, sus árboles, autos, faroles y letreros de las calles (con data/sentidos.json) como datos, sus edificios solos (de 1,8 a 3 km) y lo de lejos (tools/export.py --teselas; ~3 min, ~540 MB), el plano de los mapas (pipeline/plano.py) y la importación en Godot; luego: Godot --path juego
	rm -f juego/plaza.glb juego/plaza.glb.import juego/plaza.json   # el glb de 400 m de antes de noviembre de 2026
	$(PW) tools/export.py --teselas juego/mapa --comuna --tam 500 --instancias arboles,alamos,autos,autos-ruta5 --faroles --letreros --lejos --medio --liviano
	touch juego/mapa/.gdignore    # Godot no importa los glb: mapa.gd los lee al jugar
	mkdir -p juego/datos && cp config/fachadas.json data/plaza-osm.json data/ruta5.json juego/datos/   # lo que el juego comparte con la página
	cd pipeline && $(PY) plano.py   # juego/datos/plano.json: las calles, el agua y la red de calles de los mapas del juego (plano.gd, ruta.gd)
	$(GODOT) --headless --path juego --import

cine:                         ## la película de juego/cine.gd (requiere juego/mapa/: make juego): shots/cine/plaza.mp4 (H.264, 30 cuadros por segundo; ~1 min con la GPU del Mac)
	mkdir -p shots/cine
	@# juego/override.cfg (Godot lo lee al partir): el tamaño, porque --resolution no cambia lo que graba Movie Maker, y la calidad del MJPEG, que por omisión (0,75) deja una grilla de 8 × 8 en las copas oscuras y en el cielo de noche (y el H.264 gasta bits en copiarla); la ruta, absoluta: Godot la toma relativa a juego/
	printf '[display]\nwindow/size/viewport_width=%s\nwindow/size/viewport_height=%s\n[editor]\nmovie_writer/video_quality=1.0\n' $(subst x, ,$(strip $(CINE))) > juego/override.cfg
	$(GODOT) --path juego --write-movie $(CURDIR)/shots/cine/plaza.avi --fixed-fps 30 -- --cine; s=$$?; rm -f juego/override.cfg; exit $$s
	ffmpeg -y -loglevel error -i shots/cine/plaza.avi -c:v libx264 -preset slow -crf $(strip $(CINE_CRF)) -pix_fmt yuv420p -movflags +faststart -an shots/cine/plaza.mp4
	rm shots/cine/plaza.avi       # el intermedio: ~1,4 GB a 1080p
	@echo "-> shots/cine/plaza.mp4"

deploy:                       ## make build y sube dist/ a Cloudflare Pages (talca.eduramirez.com); DRY_RUN=1 arma sin subir
	DRY_RUN=$(DRY_RUN) ./scripts/deploy-cloudflare.sh

validate:                     ## compara cada lugar con su dirección en la grilla (requiere raw/)
	cd pipeline && $(PY) geocode.py validate

diagnostics:                  ## paneles PNG de manzanas + calles + trazados (requiere raw/; Pillow, por uv)
	cd pipeline && $(PIL) diagnostics.py

shots: build                  ## capturas de referencia en shots/ (requiere npm install + playwright)
	$(PW) tools/screenshot.py shots/vista-inicial.png
	$(PW) tools/screenshot.py shots/corte.png --hash corte-apelaciones
	$(PW) tools/screenshot.py shots/movil-oscuro.png --size 390x844 --dark

site-assets: build            ## src/site/og.jpg (Open Graph, 1200 × 630), apple-touch-icon.png y los pósters del arranque (poster-*.webp), desde el mapa y el favicon
	uv run tools/site_assets.py   # las dependencias, del encabezado del archivo

serve: build                  ## sirve dist/ en http://localhost:$(PORT) y lo abre en el navegador (otro puerto: make serve PORT=9000)
	(sleep 1 && $(PY) -m webbrowser -t http://localhost:$(PORT)/ >/dev/null) & \
	cd dist && $(PY) -m http.server $(PORT)

clean:
	rm -rf shots diagnostics pipeline/__pycache__
