#!/usr/bin/env bash
# Hook WorktreeRemove (.claude/settings.json): quita el worktree de una sesión (Claude Code le pasa por stdin un JSON con
# «path»; --force dos veces, porque Claude Code los deja bloqueados). Los enlaces de tools/preparar.sh se borran como
# enlaces, sin tocar lo que apuntan. La rama worktree-<nombre> se borra solo si ya no lleva nada propio: unida a
# origin/main o igual a la que está en origin; si no, queda, y lo dice.
set -euo pipefail
principal="${CLAUDE_PROJECT_DIR:-$PWD}"
principal="${principal%%/.claude/worktrees/*}"
ruta="$(python3 -c "import sys, json; print(json.load(sys.stdin).get('path', ''))")"
[[ -n $ruta ]] || { echo "worktree-quitar: el JSON no trae «path»" >&2; exit 1; }
rama="worktree-$(basename "$ruta")"
git -C "$principal" worktree remove -f -f "$ruta" >&2 || echo "worktree-quitar: git worktree remove falló: $ruta" >&2
git -C "$principal" worktree prune
if git -C "$principal" show-ref -q --verify "refs/heads/$rama"; then
	sha="$(git -C "$principal" rev-parse "refs/heads/$rama")"
	if git -C "$principal" merge-base --is-ancestor "$sha" origin/main 2>/dev/null \
		|| [[ $sha == "$(git -C "$principal" rev-parse -q --verify "refs/remotes/origin/$rama" 2>/dev/null)" ]]; then
		git -C "$principal" branch -D "$rama" >&2
	else
		echo "worktree-quitar: la rama $rama tiene commits que no están en origin: queda (git branch -D $rama la borra)" >&2
	fi
fi
