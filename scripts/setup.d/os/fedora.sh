# setup.d/os/fedora.sh — Fedora (kể cả Fedora Asahi Remix). dnf cần sudo, nên chỉ in lệnh.
OS_LABEL="Fedora"

os_pkg() {
  case "$1" in
    node) echo nodejs ;;
    terminal-notifier) echo "" ;;    # chỉ có trên macOS
    *) echo "$1" ;;
  esac
}

os_hint() {
  local p; p="$(os_pkg "$1")"
  [[ -n "$p" ]] && echo "sudo dnf install $p" || echo "không cần trên Fedora"
}

# os_install: giữ mặc định (trả 2) vì dnf cần sudo
