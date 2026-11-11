# modules/30-mcp.sh — MCP dùng chung (danh sách trong config.sh), ghi vào ~/.gemini/config/mcp_config.json
step_mcp() {
  say "MCP"
  have npx && ok "npx (Context7)" || warn "thiếu npx: Context7 cần Node ($(os_hint node))"
  have agy || { fail "thiếu agy, bỏ qua MCP"; return; }

  local cfg="$SHARED/mcp_config.json" name cmd out
  if [[ -f "$cfg" ]] && ! jq empty "$cfg" 2>/dev/null; then fail "$(tilde "$cfg") không phải JSON hợp lệ"; return; fi
  while IFS='|' read -r name cmd; do
    [[ -n "$name" ]] || continue
    if [[ -f "$cfg" ]] && jq -e --arg n "$name" '.mcpServers[$n]' "$cfg" >/dev/null 2>&1; then
      ok "$name"; continue
    fi
    echo "  → agy mcp add $name -- $cmd"
    (( DRY == 1 )) && continue
    # shellcheck disable=SC2086  # cmd được tách thành từng đối số có chủ đích
    if out=$(agy mcp add "$name" -- $cmd 2>&1 </dev/null); then ok "đã thêm $name"
    else fail "không thêm được $name: $out"; fi
  done <<<"$USER_MCP"

  if grep -q '^context7|' <<<"$USER_MCP"; then
    [[ -n "${CONTEXT7_API_KEY:-}" ]] && ok "CONTEXT7_API_KEY có trong môi trường" \
      || note "tuỳ chọn: export CONTEXT7_API_KEY=… trong file rc của shell (key miễn phí ở context7.com/dashboard)"
  fi
}
