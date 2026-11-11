# modules/20-tools.sh — CLI cho agent dùng thay MCP (danh sách trong config.sh): cài + đăng nhập
step_tools() {
  say "CLI cho agent ($(echo $(cut -d'|' -f1 <<<"$TOOLS") | tr ' ' ','))"
  local c uvpkg missing=""
  while IFS='|' read -r c uvpkg; do
    [[ -n "$c" ]] || continue
    if have "$c"; then ok "$c"
    elif (( INSTALL == 1 )); then _tools_install "$c" "$uvpkg"
    else missing="$missing $c"; warn "thiếu $c"; fi
  done <<<"$TOOLS"
  [[ -n "$missing" ]] && note "chạy lại với --install để cài:$missing"
  for c in $AUTH_TOOLS; do have "$c" && _tools_auth "$c"; done
}

_tools_install() { # lệnh, gói uv (trống = gói hệ điều hành)
  local c="$1" uvpkg="$2" rc
  if [[ -n "$uvpkg" ]]; then
    if have uv; then act uv tool install "$uvpkg" || fail "cài $c thất bại"
    else warn "cần uv trước để cài $c"; fi
    return
  fi
  os_install "$c"; rc=$?
  (( rc == 2 )) && warn "tự cài $c: $(os_hint "$c")"
}

_tools_authed() { # lệnh → 0 nếu đã đăng nhập
  case "$1" in
    gh) gh auth status >/dev/null 2>&1 ;;
    hf) hf auth whoami >/dev/null 2>&1 || huggingface-cli whoami >/dev/null 2>&1 ;;
    *)  return 1 ;;
  esac
}

_tools_auth() { # lệnh → in trạng thái; với --include-login thì mở lệnh đăng nhập
  case "$1" in
    gh|hf)
      if _tools_authed "$1"; then ok "$1: đã đăng nhập"
      elif (( LOGIN == 1 )); then _tools_login "$1"
      else warn "$1 chưa đăng nhập: $1 auth login (hoặc chạy lại với --include-login)"; fi ;;
    kaggle) _tools_kaggle ;;
  esac
}

_tools_login() { # gh | hf: chạy lệnh đăng nhập tương tác rồi kiểm tra lại
  echo "  → đăng nhập $1"
  (( DRY == 1 )) && return 0
  interactive || { warn "không có terminal tương tác, tự chạy: $1 auth login"; return; }
  "$1" auth login
  _tools_authed "$1" && ok "$1: đã đăng nhập" || warn "$1 vẫn chưa đăng nhập"
}

# Kaggle không có lệnh đăng nhập: cần kaggle.json (hoặc token trong biến môi trường)
_tools_kaggle() {
  local kj="${KAGGLE_CONFIG_DIR:-$HOME/.kaggle}/kaggle.json" mode
  if [[ -n "${KAGGLE_API_TOKEN:-}" || ( -n "${KAGGLE_USERNAME:-}" && -n "${KAGGLE_KEY:-}" ) ]]; then
    ok "kaggle: có token trong biến môi trường"
  elif [[ -f "$kj" ]]; then
    mode="$(os_file_mode "$kj")"
    [[ "$mode" == 600 ]] && ok "kaggle: có $(tilde "$kj")" \
      || warn "kaggle.json đang có quyền $mode, nên là 600: chmod 600 $(tilde "$kj")"
  elif (( LOGIN == 1 )); then _tools_kaggle_login "$kj"
  else warn "kaggle chưa đăng nhập: tải kaggle.json từ kaggle.com/settings → $(tilde "$kj"), chmod 600"; fi
}

_tools_kaggle_login() { # mở trang tạo token, chờ người dùng tải kaggle.json, rồi đặt đúng chỗ
  local kj="$1" url="https://www.kaggle.com/settings" dl="$HOME/Downloads/kaggle.json"
  echo "  → đăng nhập kaggle: mở $url, mục API → Create New Token"
  (( DRY == 1 )) && return 0
  interactive || { warn "không có terminal tương tác: tải kaggle.json từ $url → $(tilde "$kj"), chmod 600"; return; }
  os_open_url "$url"
  printf '    Tải kaggle.json xong thì nhấn Enter (để ở ~/Downloads cũng được)… '
  read -r _
  if [[ ! -f "$kj" && -f "$dl" ]]; then
    mkdir -p "$(dirname "$kj")" && mv "$dl" "$kj" && echo "  → đã chuyển ~/Downloads/kaggle.json → $(tilde "$kj")"
  fi
  if [[ -f "$kj" ]]; then chmod 600 "$kj"; ok "kaggle: có $(tilde "$kj") (quyền 600)"
  else warn "chưa thấy kaggle.json ở $(tilde "$kj")"; fi
}
