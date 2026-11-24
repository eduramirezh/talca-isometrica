#!/usr/bin/env bash
# Godot (modelo3d/, o el juego que la usa) sin que se vea ni se quede con el teclado. Corrido directo, Godot se pone al frente al partir y le
# quita el teclado y el mouse a quien trabaja: en el Mac, aunque se le pida una ventana fuera de la pantalla
# (--position), sin foco (window/size/no_focus) o se lance con `open -g` (probado en noviembre de 2026); en Linux
# (Cinnamon, X11) una captura con la ventana a la vista se quedó con lo que se tecleaba (E y V: el personaje subió al
# auto, cambió a la bicicleta y volvió al auto, y salió andando a 14 km/h), y la carga, que espera a lo que ve la
# cámara, tardó 101 s en vez de 6.
# Las sesiones de Claude revisan Godot siempre así (--png, --caminar con --png, --fps, --cine --cuadro), nunca con
# el binario directo (--headless no dibuja, pero tampoco abre ventana: ese sí va directo).
#
#   tools/godot_oculto.sh --path modelo3d -- --png shots/x.png [--desde x,y …]   # los mismos argumentos que Godot
#   tools/godot_oculto.sh --path modelo3d -- --fps 6
#   make cine GODOT=tools/godot_oculto.sh
#
# En el Mac: el mismo Godot.app (GODOT_APP), lanzado oculto (`open -j -g`): la app al frente no cambia, no aparece
# ninguna ventana y dibuja con la GPU igual (la vista inicial: 68,1 cuadros por segundo oculta y 67,9 a la vista).
# `open` no le pasa al proceso ni el directorio ni el entorno: --path se vuelve absoluto y PWD va con --env (main.gd
# resuelve con él las rutas relativas de --png). La salida de Godot se junta en un archivo y se imprime al terminar.
#
# En Linux: godot (o godot4) del PATH, o GODOT_BIN, en una pantalla virtual de Xvfb (xvfb-run, del paquete xvfb) de
# GODOT_OCULTO_PANTALLA (3840x2160 por omisión, para que quepa la ventana de make cine): nada aparece en la pantalla de
# verdad. Godot elige la GPU dedicada, y con el driver propietario de NVIDIA dibuja con ella también en Xvfb (una
# GTX 1650: la captura de la plaza en 15 s, las 56 teselas en 6,3 s). Vulkan de Mesa (Intel, AMD) no puede presentar
# en Xvfb («No DRI3 support detected», y Godot falla con «!present_queue_family»): GODOT_OCULTO_VK=lavapipe usa el
# Vulkan de Mesa por CPU (llvmpipe), que sí, pero lento (la misma captura, 213 s) y sin cuadros por segundo que sirvan.
# La salida de Godot sale a medida que llega.
#
# Sale con 1 si hubo un SCRIPT ERROR o un ERROR, o si Godot salió con error. Sin --png, --fps, --recorrido (una toma
# de video, que sale al terminar) ni --cuadro Godot no sale solo: quedaría corriendo oculto (en el Mac, Cmd+Tab lo
# muestra; en Linux no se ve: Ctrl+C lo termina).
set -e
out=$(mktemp "${TMPDIR:-/tmp}/godot_oculto.XXXXXX")
trap 'rm -f "$out"' EXIT
st=0
if [[ $(uname -s) == Darwin ]]; then
  app=${GODOT_APP:-/Applications/Godot.app}
  args=()
  while (( $# )); do
    if [[ $1 == --path && $# -ge 2 ]]; then args+=(--path "$(cd "$2" && pwd -P)"); shift 2
    elif [[ $1 == --path=* ]]; then args+=("--path=$(cd "${1#--path=}" && pwd -P)"); shift
    else args+=("$1"); shift; fi
  done
  open -j -g -n -W --env PWD="$PWD" --stdout "$out" --stderr "$out" -a "$app" --args "${args[@]}" || st=$?
  cat "$out"
else
  bin=${GODOT_BIN:-$(command -v godot || command -v godot4 || true)}
  if [[ -z $bin ]]; then echo 'godot_oculto.sh: no hay godot ni godot4 en el PATH (o GODOT_BIN=<ruta del binario>)' >&2; exit 1; fi
  if ! command -v xvfb-run >/dev/null; then echo 'godot_oculto.sh: falta xvfb-run (Debian/Ubuntu: apt install xvfb)' >&2; exit 1; fi
  if [[ ${GODOT_OCULTO_VK:-} == lavapipe ]]; then export VK_DRIVER_FILES=/usr/share/vulkan/icd.d/lvp_icd.json; fi
  set -o pipefail
  xvfb-run -a -s "-screen 0 ${GODOT_OCULTO_PANTALLA:-3840x2160}x24" "$bin" "$@" 2>&1 | tee "$out" || st=$?
  if grep -q 'present_queue_family' "$out"; then
    echo 'godot_oculto.sh: la GPU no puede presentar en Xvfb (Vulkan de Mesa necesita DRI3); GODOT_OCULTO_VK=lavapipe dibuja por CPU, lento' >&2
  fi
fi
if (( st )) || grep -qE "^(SCRIPT )?ERROR" "$out"; then exit 1; fi
