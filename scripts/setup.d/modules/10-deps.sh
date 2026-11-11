# modules/10-deps.sh — công cụ nền mà harness cần
step_deps() {
  say "Công cụ nền"
  local c
  for c in git jq; do
    have "$c" && ok "$c" || fail "thiếu $c: $(os_hint "$c")"
  done
  if have agy; then ok "agy ($(tilde "$(command -v agy)"))"
  else fail "thiếu agy (cài Antigravity CLI trước: antigravity.google/docs/cli)"; fi
  for c in node npm; do
    have "$c" && ok "$c" || warn "thiếu $c: MCP chạy bằng npx (Context7) cần Node ($(os_hint node))"
  done
  os_deps
}
