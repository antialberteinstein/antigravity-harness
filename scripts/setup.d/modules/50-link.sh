# modules/50-link.sh — đưa lệnh (LINKS trong config.sh) ra ~/.local/bin và kiểm tra PATH
step_link() {
  say "Lệnh trong ~/.local/bin"
  [[ -d "$BIN" ]] || act mkdir -p "$BIN"
  local n src dst cur
  for n in $LINKS; do
    src="$SCRIPTS/$n"; dst="$BIN/$n"
    if [[ ! -f "$src" ]]; then fail "không có $(tilde "$src")"; continue; fi
    cur=""; [[ -L "$dst" ]] && cur="$(readlink "$dst")"
    if [[ "$cur" == "$src" ]]; then ok "$n → $(tilde "$src")"
    elif [[ -n "$cur" && -e "$dst" ]]; then
      # vd. `show` đã trỏ vào ~/.claude/scripts/show: hai harness dùng chung một lệnh, không giành nhau
      ok "$n → $(tilde "$cur") (đã có, giữ nguyên)"
    elif [[ -e "$dst" && ! -L "$dst" ]]; then warn "$(tilde "$dst") là file thật, không ghi đè; xoá nó rồi chạy lại"
    else act ln -sfn "$src" "$dst"; fi
  done
  _link_path
}

_link_path() { # ~/.local/bin có trong PATH chưa (PATH trước khi setup.sh tự thêm)
  case ":$ORIG_PATH:" in *":$BIN:"*) ok "~/.local/bin đã có trong PATH"; return ;; esac
  local rc line='export PATH="$HOME/.local/bin:$PATH"  # antigravity harness'
  rc="$(os_rc_file "${SHELL##*/}")"
  if [[ -z "$rc" ]]; then
    warn "~/.local/bin chưa có trong PATH. fish: fish_add_path ~/.local/bin"
  elif [[ -f "$rc" ]] && grep -qE '# (antigravity|claude) harness' "$rc"; then
    warn "đã thêm vào $(tilde "$rc") nhưng shell hiện tại chưa nạp: mở terminal mới"
  elif (( ADD_PATH == 1 )); then
    echo "  → thêm vào $(tilde "$rc"): $line"
    (( DRY == 1 )) || printf '\n%s\n' "$line" >> "$rc"
  else
    warn "~/.local/bin chưa có trong PATH. Chạy lại với --add-path, hoặc thêm vào $(tilde "$rc"):"
    echo "      $line"
  fi
}
