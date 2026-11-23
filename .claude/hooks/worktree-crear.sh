#!/usr/bin/env bash
# Hook WorktreeCreate (.claude/settings.json): el worktree de una sesión de Claude Code (claude --worktree, EnterWorktree,
# un subagente aislado), listo para trabajar. Claude Code le pasa por stdin un JSON con «name»; el hook crea el
# worktree y escribe en stdout solo su ruta (todo lo demás va a stderr).
#
# Va siempre bajo la copia principal (.claude/worktrees/<name>, rama worktree-<name>, como los de Claude Code sin
# hook), aunque lo pida una sesión que ya está en un worktree: anidado, quitar el de afuera se lleva el de adentro.
# Parte de origin/main (al día, si hay red) desde la copia principal, y de la cabeza de quien lo pide desde un
# worktree (un subagente que trabaja en esa rama). Después, tools/preparar.sh: raw/, node_modules/ y las teselas de
# la maqueta en 3D, enlazados a los de la copia principal.
set -euo pipefail
llama="${CLAUDE_PROJECT_DIR:-$PWD}"
principal="${llama%%/.claude/worktrees/*}"
nombre="$(python3 -c "import sys, json; print(json.load(sys.stdin).get('name') or 'wt')")"
dir="$principal/.claude/worktrees/$nombre"
rama="worktree-$nombre"
if [[ ! -d $dir ]]; then
	if [[ $llama != "$principal" ]]; then
		base="$(git -C "$llama" rev-parse HEAD)"
		echo "worktree-crear: pedido desde el worktree $(basename "$llama"): $nombre parte de su cabeza, no de main" >&2
	else
		git -C "$principal" fetch -q origin main >&2 2>&1 || echo "worktree-crear: sin red, parte del origin/main que hay" >&2
		base="$(git -C "$principal" rev-parse --verify -q origin/main || git -C "$principal" rev-parse HEAD)"
	fi
	if git -C "$principal" show-ref -q --verify "refs/heads/$rama"; then
		git -C "$principal" worktree add "$dir" "$rama" >&2
	else
		git -C "$principal" worktree add -b "$rama" "$dir" "$base" >&2
	fi
fi
if [[ -x $dir/tools/preparar.sh ]]; then
	"$dir/tools/preparar.sh" >&2 || echo "worktree-crear: tools/preparar.sh dejó algo pendiente (arriba)" >&2
else
	echo "worktree-crear: esta rama no tiene tools/preparar.sh: raw/ y node_modules/, a mano" >&2
fi
echo "$dir"
