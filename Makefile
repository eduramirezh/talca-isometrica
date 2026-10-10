# Talca Isométrica — tareas del pipeline. Ver README.md.
PY ?= python3
.PHONY: all fetch data pois build validate diagnostics shots serve clean

all: data pois build          ## pipeline completo (requiere raw/: make fetch)

fetch:                        ## descarga las fuentes a raw/ (~60 MB)
	./pipeline/fetch_sources.sh

data:                         ## raw/ + config/trazados.json -> data/geometry.json
	cd pipeline && $(PY) process_geometry.py

pois:                         ## pipeline/pois.py -> data/pois.json + data/pois.csv
	cd pipeline && $(PY) pois.py

build:                        ## -> dist/talca.html (fragmento) y dist/index.html (página completa)
	cd pipeline && $(PY) build.py --standalone

validate:                     ## compara cada lugar con su dirección en la grilla (requiere raw/)
	cd pipeline && $(PY) geocode.py validate

diagnostics:                  ## paneles PNG de manzanas + calles + trazados (requiere raw/)
	cd pipeline && $(PY) diagnostics.py

shots: build                  ## capturas de referencia en shots/ (requiere npm install + playwright)
	$(PY) tools/screenshot.py shots/vista-inicial.png
	$(PY) tools/screenshot.py shots/corte.png --hash corte-apelaciones
	$(PY) tools/screenshot.py shots/movil-oscuro.png --size 390x844 --dark

serve: build                  ## sirve dist/ en http://localhost:8000
	cd dist && $(PY) -m http.server 8000

clean:
	rm -rf shots diagnostics pipeline/__pycache__
