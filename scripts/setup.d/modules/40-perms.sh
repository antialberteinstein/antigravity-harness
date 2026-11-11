# modules/40-perms.sh — quyền chạy cho các script của harness
step_perms() {
  say "Quyền chạy cho script"
  local f
  for f in "$SCRIPTS"/*.sh $(for n in $LINKS; do echo "$SCRIPTS/$n"; done) "$GEM/statusline.sh"; do
    [[ -f "$f" ]] || continue
    if [[ -x "$f" ]]; then ok "$(tilde "$f")"; else act chmod +x "$f"; fi
  done
}