# modules/70-validate.sh — file được cấu hình tham chiếu có thật không, và các lỗi cấu hình hay gặp
step_validate() {
  say "Kiểm tra cấu hình"
  _validate_rules
  _validate_commands
  _validate_plugin_hooks
  _validate_duplicate_skills
}

# GEMINI.md: có, không vượt 24 KB (agy cắt bớt phần thừa), các include @[..](..) trỏ tới file có thật
_validate_rules() {
  local f="$GEM/GEMINI.md" size inc p
  [[ -f "$f" ]] || { fail "thiếu $(tilde "$f")"; return; }
  size=$(wc -c < "$f" | tr -d ' ')
  while IFS= read -r inc; do
    [[ -n "$inc" ]] || continue
    p="${inc/#\~/$HOME}"; [[ "$p" == /* ]] || p="$GEM/$p"
    if [[ -f "$p" ]]; then size=$((size + $(wc -c < "$p" | tr -d ' ')))
    else fail "GEMINI.md include tới file không có: $inc"; fi
  done < <(grep -oE '@\[[^]]*\]\([^)]+\)' "$f" | sed -E 's/.*\(([^)]+)\)$/\1/')
  if (( size > 24000 )); then warn "GEMINI.md cùng include là $size byte, vượt giới hạn 24000: agy sẽ cắt bớt"
  else ok "GEMINI.md ($size byte kể cả include)"; fi
}

# Script mà statusLine của agy và config/hooks.json gọi tới
_validate_commands() {
  local cmd f seen="" hooks="$SHARED/hooks.json"
  if [[ -f "$hooks" ]] && ! jq empty "$hooks" 2>/dev/null; then fail "$(tilde "$hooks") không phải JSON hợp lệ"; hooks=""; fi
  while IFS= read -r cmd; do
    f=$(grep -oE '(~|\$HOME|/)[^ "'\'']+\.(sh|js|py)' <<<"$cmd" | head -1) || true
    [[ -n "$f" ]] || continue
    f="${f/#\~/$HOME}"; f="${f/#\$HOME/$HOME}"
    case " $seen " in *" $f "*) continue ;; esac
    seen="$seen $f"
    [[ -f "$f" ]] && ok "$(tilde "$f")" || fail "thiếu $(tilde "$f")"
  done < <(
    [[ -f "$CLI_SETTINGS" ]] && jq -r '.statusLine.command? // empty' "$CLI_SETTINGS" 2>/dev/null
    [[ -f "$hooks" ]] && jq -r '.. | objects | .command? | strings' "$hooks" 2>/dev/null
  )
}

# Plugin import từ Claude Code có hooks.json dạng {"hooks": {...}}: agy đọc thành MỘT hook tên "hooks"
# với các sự kiện kiểu Claude (Bash, Edit…) nên không chạy đúng. Chỉ cảnh báo plugin đang bật.
_validate_plugin_hooks() {
  local d name cfg="$SHARED/config.json" bad=""
  for d in "$SHARED"/plugins/*/; do
    [[ -f "$d/hooks.json" ]] || continue
    name="$(basename "$d")"
    jq -e 'has("hooks") and (.hooks | type == "object") and (.hooks | has("PreToolUse") or has("PostToolUse") or has("Stop") or has("SessionStart"))' \
      "$d/hooks.json" >/dev/null 2>&1 || continue
    if [[ -f "$cfg" ]] && jq -e --arg n "$name" '.plugins[$n].enabled == false' "$cfg" >/dev/null 2>&1; then continue; fi
    bad="$bad $name"
  done
  if [[ -n "$bad" ]]; then
    warn "plugin đang bật có hooks.json kiểu Claude Code (agy không chạy đúng):$bad"
    note "tắt bằng: agy plugin disable <tên>, hoặc thêm vào DISABLE_PLUGINS rồi chạy agy-sync"
  else
    ok "không plugin nào dùng hooks.json kiểu Claude Code"
  fi
}

# Skill lẻ trong ~/.gemini/config/skills trùng tên skill của plugin đang bật: một trong hai bị che,
# thường là bản cũ chép bằng tay hay bằng install.sh trước khi cài plugin
_validate_duplicate_skills() {
  local dir="$SHARED/skills" list d name owner dup=0
  [[ -d "$dir" ]] && have agy || return 0
  list=$(agy plugin list --json 2>/dev/null </dev/null) || return 0
  for d in "$dir"/*/; do
    [[ -f "$d/SKILL.md" ]] || continue
    name="$(basename "$d")"
    owner=$(jq -r --arg s "$name" '[.[] | select(.enabled != false and ((.skills // []) | index($s))) | .name] | join(", ")' <<<"$list" 2>/dev/null)
    [[ -n "$owner" ]] || continue
    warn "skill $name ở $(tilde "$dir") trùng với plugin $owner: chuyển bản lẻ vào ~/.gemini/backups/ nếu nó cũ hơn"
    dup=1
  done
  (( dup == 0 )) && ok "không skill lẻ nào trùng skill của plugin"
}
