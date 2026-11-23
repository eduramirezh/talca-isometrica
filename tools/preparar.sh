#!/usr/bin/env bash
# Deja un worktree listo para trabajar: lo que no va en git y se comparte con la copia principal, enlazado a la de
# ella en vez de bajarlo o generarlo otra vez. Lo corre el hook WorktreeCreate de .claude/settings.json en cada
# worktree nuevo (.claude/hooks/worktree-crear.sh); a mano, en un worktree hecho con `git worktree add`.
#
#   tools/preparar.sh            # enlaza lo que falte; no toca lo que ya está
#   tools/preparar.sh --revisar  # sale con 1 si falta algo (y dice qué)
#
#   raw/                         las descargas (make fetch), ~GB; lo que una herramienta baja ahí queda para todas
#   node_modules/                three.js y ESLint (npm install): make build, make lint
#   scripts/deploy/node_modules/ Wrangler (~270 MB): el push a main desde un worktree publica el sitio (.githooks/pre-push)
#   modelo3d/mapa/, datos/       las teselas de la maqueta en 3D (make modelo3d, ~4 min, ~570 MB)
#
# Los enlaces son absolutos y no van en git (.gitignore y modelo3d/.gitignore los cubren también como enlaces). Lo que
# cada worktree genera por su cuenta (dist/, shots/, diagnostics/, modelo3d/.godot/) no se comparte. En la copia
# principal no enlaza nada: dice qué falta y con qué se hace.
set -euo pipefail
raiz="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$raiz"
revisar=0
[[ ${1:-} == --revisar ]] && revisar=1
principal="$(cd "$(git rev-parse --git-common-dir)/.." && pwd -P)"
falta=0
# ruta -> con qué se hace en la copia principal
for par in "raw:make fetch" "node_modules:npm install" "scripts/deploy/node_modules:se instala solo al publicar" \
	"modelo3d/mapa:make modelo3d" "modelo3d/datos:make modelo3d"; do
	n="${par%%:*}"; como="${par#*:}"
	[[ -e $n ]] && continue
	if [[ $principal == "$raiz" || ! -e $principal/$n ]]; then
		# raw/ y node_modules/ hacen falta para casi todo; lo demás, solo para publicar o para el 3D
		case $n in raw|node_modules) echo "preparar.sh: falta $n en la copia principal ($como)" >&2; falta=1;; esac
		continue
	fi
	if (( revisar )); then echo "preparar.sh: falta el enlace $n (tools/preparar.sh)" >&2; falta=1; continue; fi
	ln -s "$(cd "$principal/$n" && pwd -P)" "$n"
	echo "preparar.sh: $n -> $principal/$n" >&2
done
exit $falta
