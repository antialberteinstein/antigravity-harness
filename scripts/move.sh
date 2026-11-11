#!/usr/bin/env bash
# scripts/move.sh — turn a fresh clone of this repo into ~/.gemini itself.
#
#   git clone https://github.com/antialberteinstein/antigravity-harness.git ~/antigravity-harness
#   bash ~/antigravity-harness/scripts/move.sh [-n]
#
# What it does:
#   1. For every tracked file that already exists in ~/.gemini with different content,
#      moves the old file to ~/.gemini/backups/harness-<timestamp>/ (never overwrites silently).
#   2. Moves .git and the tracked files into ~/.gemini, then removes the empty clone.
# Untracked things in ~/.gemini (sign-in tokens, conversations, plugins, settings.json, …) are left alone.
# Target: $GEMINI_HOME if set, else ~/.gemini. Works with bash 3.2 (macOS).
set -euo pipefail

DRY=0
case "${1:-}" in
  -n|--dry-run) DRY=1 ;;
  "") ;;
  *) echo "Usage: move.sh [-n|--dry-run]" >&2; exit 2 ;;
esac

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
DEST="${GEMINI_HOME:-$HOME/.gemini}"
mkdir -p "$DEST"; DEST="$(cd "$DEST" && pwd -P)"

say() { printf '%s\n' "$*"; }
act() { if (( DRY )); then say "→ $*"; else "$@"; fi; }

[[ -d "$SRC/.git" ]] || { say "Not a git clone: $SRC" >&2; exit 1; }
if [[ "$SRC" == "$DEST" ]]; then say "Already in place: $DEST"; exit 0; fi
[[ -e "$DEST/.git" ]] && { say "$DEST is already a git repo. Remove $DEST/.git first if you really want to replace it." >&2; exit 1; }
[[ -z "$(git -C "$SRC" status --porcelain)" ]] || { say "The clone has uncommitted changes; commit or discard them first: $SRC" >&2; exit 1; }

say "Moving $SRC → $DEST"

BACKUP="$DEST/backups/harness-$(date +%Y%m%d-%H%M%S)"
backed=0
while IFS= read -r -d '' f; do
  if [[ -e "$DEST/$f" || -L "$DEST/$f" ]]; then
    if cmp -s "$SRC/$f" "$DEST/$f"; then :; else
      act mkdir -p "$BACKUP/$(dirname "$f")"
      act mv "$DEST/$f" "$BACKUP/$f"
      backed=$((backed+1))
    fi
  fi
  [[ "$f" == */* ]] && act mkdir -p "$DEST/${f%/*}"
  act mv -f "$SRC/$f" "$DEST/$f"
done < <(git -C "$SRC" ls-files -z)
act mv "$SRC/.git" "$DEST/.git"

if (( DRY )); then say "(dry run, nothing changed)"; exit 0; fi

# Remove the now-empty clone (only empty directories; anything left over stays).
find "$SRC" -depth -type d -empty -exec rmdir {} \; 2>/dev/null || true
[[ -d "$SRC" ]] && say "Left over in $SRC (untracked files, not touched)"

git -C "$DEST" update-index -q --refresh || true
t="~"; (( backed )) && say "Backed up $backed existing file(s) to ${BACKUP/#$HOME/$t} — diff them against the new ones and keep what you need."
say "Done. git status in $DEST:"
git -C "$DEST" status --short
say "Next: bash ~/.gemini/scripts/setup.sh"
