# modules/60-settings.sh — trộn agy-settings.json vào ~/.gemini/antigravity-cli/settings.json
#
# Vì sao không đưa thẳng settings.json lên git: agy tự ghi file này (model, trustedWorkspaces…),
# và trustedWorkspaces chứa đường dẫn riêng tư của máy. Harness chỉ giữ phần nó quản lý rồi trộn vào:
#   - object: trộn sâu, giá trị của harness thắng
#   - permissions.allow/ask/deny: hợp hai danh sách (giữ quy tắc agy đã lưu khi bạn bấm "Always allow")
#   - chuỗi "@HOME@" được thay bằng $HOME của máy này
step_settings() {
  say "settings.json của agy"
  [[ -f "$HARNESS_SETTINGS" ]] || { fail "không có $(tilde "$HARNESS_SETTINGS")"; return; }
  jq empty "$HARNESS_SETTINGS" 2>/dev/null || { fail "$(tilde "$HARNESS_SETTINGS") không phải JSON hợp lệ"; return; }
  local live='{}' tmp keys
  if [[ -f "$CLI_SETTINGS" ]]; then
    jq empty "$CLI_SETTINGS" 2>/dev/null || { fail "$(tilde "$CLI_SETTINGS") không phải JSON hợp lệ, sửa tay rồi chạy lại"; return; }
    live="$(cat "$CLI_SETTINGS")"
  fi
  tmp="$(mktemp)"
  if ! _settings_merge "$live" > "$tmp"; then rm -f "$tmp"; fail "trộn settings thất bại; file gốc chưa bị đổi"; return; fi

  if [[ -f "$CLI_SETTINGS" ]] && jq -e --slurpfile a "$tmp" '. == $a[0]' "$CLI_SETTINGS" >/dev/null; then
    rm -f "$tmp"; ok "đã khớp với $(tilde "$HARNESS_SETTINGS")"; return
  fi
  keys=$(jq -r --argjson old "$live" '[to_entries[] | select($old[.key] != .value) | .key] | join(", ")' "$tmp")
  echo "  → cập nhật $(tilde "$CLI_SETTINGS"): $keys"
  if (( DRY == 1 )); then rm -f "$tmp"; return; fi
  mkdir -p "$CLI_DIR"
  if [[ -f "$CLI_SETTINGS" ]]; then
    cp "$CLI_SETTINGS" "$CLI_SETTINGS.bak-$(date +%Y%m%d-%H%M%S)"
    note "đã sao lưu bản cũ: $(tilde "$CLI_SETTINGS").bak-…"
  fi
  mv "$tmp" "$CLI_SETTINGS"
  ok "đã ghi"
}

_settings_merge() { # JSON đang dùng → in JSON đã trộn
  jq --arg home "$HOME" --argjson live "$1" '
    def uniq: reduce .[] as $x ([]; if index([$x]) then . else . + [$x] end);
    (walk(if type == "string" then gsub("@HOME@"; $home) else . end)) as $h
    | ($live.permissions // {}) as $lp | ($h.permissions // {}) as $hp
    | ($live * ($h | del(.permissions)))
    | if ($lp + $hp) == {} then . else
        .permissions = ((($lp | keys) + ($hp | keys) | unique)
          | map({key: ., value: (($lp[.] // []) + ($hp[.] // []) | uniq)}) | from_entries)
      end
  ' "$HARNESS_SETTINGS"
}
