# setup.d/os/darwin.sh — macOS. Cài bằng Homebrew (không cần sudo).
OS_LABEL="macOS"

os_pkg() {
  case "$1" in
    libnotify) echo "" ;;            # không dùng trên macOS
    *) echo "$1" ;;
  esac
}

os_hint() {
  local p; p="$(os_pkg "$1")"
  [[ -n "$p" ]] || { echo "không cần trên macOS"; return; }
  have brew && echo "brew install $p" || echo "cài Homebrew (brew.sh) rồi: brew install $p"
}

os_install() {
  local p; p="$(os_pkg "$1")"
  [[ -n "$p" ]] && have brew || return 2
  act brew install "$p"
}

os_open_url()  { open "$1" 2>/dev/null; }
os_file_mode() { stat -f '%Lp' "$1"; }

os_rc_file() {
  case "$1" in
    zsh)  echo "$HOME/.zshrc" ;;
    bash) echo "$HOME/.bash_profile" ;;   # Terminal/iTerm2 mở login shell
    fish) echo "" ;;
    *)    echo "$HOME/.profile" ;;
  esac
}

os_deps() {
  have brew && ok "brew" || warn "thiếu Homebrew: --install sẽ không tự cài được gì (brew.sh)"
  have terminal-notifier && ok "terminal-notifier" \
    || note "tuỳ chọn: brew install terminal-notifier (thông báo gọn hơn osascript)"
}
