#!/usr/bin/env bash
# Publica el sitio en Cloudflare Pages (subida directa): talca.eduramirez.com.
#
# `make build` arma dist/ (index.html con su <head> y los archivos de src/site/); este script sube dist/ al proyecto
# de Cloudflare Pages con Wrangler, sin dist/talca.html (el fragmento para Claude, sin <head>: no debe quedar
# publicado como una segunda página). Se corre a mano (`make deploy`) o lo corre el hook de pre-push cuando se
# empuja main (.githooks/pre-push).
#
# Una sola vez (interactivo, con la cuenta de Cloudflare):
#   npx wrangler login
#   npx wrangler pages project create talca-isometrica --production-branch main
#
# Armar sin subir:
#   DRY_RUN=1 ./scripts/deploy-cloudflare.sh      (o: make deploy DRY_RUN=1)

set -euo pipefail

# Un hook puede traer variables de git que desvíen el build.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE

# El proyecto de Pages (su subdominio *.pages.dev). Se cambia con la variable.
CF_PAGES_PROJECT="${CF_PAGES_PROJECT:-talca-isometrica}"

say() { printf 'deploy-cloudflare: %s\n' "$1"; }

root=$(git rev-parse --show-toplevel)
cd "$root"

say "armando (make build)…"
make -s build >/dev/null

# Lo que se sube: dist/ sin el fragmento.
stage=$(mktemp -d "${TMPDIR:-/tmp}/talca-pages.XXXXXX")
trap 'rm -rf "$stage"' EXIT
cp -R dist/. "$stage/"
rm -f "$stage/talca.html"
[ -f "$stage/index.html" ] || { say "falta dist/index.html: ¿make build falló?" >&2; exit 1; }

if [ "${DRY_RUN:-0}" != "0" ]; then
  say "prueba (DRY_RUN): se subirían estos archivos, sin subir nada:"
  (cd "$stage" && find . -type f | sed 's|^\./||' | sort | while read -r f; do printf '  %8s  %s\n' "$(wc -c <"$f" | tr -d ' ')" "$f"; done)
  exit 0
fi

# --branch=main la marca como producción (la que sirve el dominio propio); otras ramas son vistas previas.
say "subiendo al proyecto de Cloudflare Pages '${CF_PAGES_PROJECT}'…"
npx --yes wrangler pages deploy "$stage" \
  --project-name="$CF_PAGES_PROJECT" \
  --branch=main \
  --commit-hash="$(git rev-parse HEAD)" \
  --commit-message="$(git log -1 --format=%s | cut -c1-200)" \
  --commit-dirty="$([ -z "$(git status --porcelain --untracked-files=no)" ] && echo false || echo true)"
say "publicado → https://talca.eduramirez.com/"
