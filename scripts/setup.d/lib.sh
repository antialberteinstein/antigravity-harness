# setup.d/lib.sh — hàm dùng chung cho mọi module, và hành vi mặc định của hồ sơ OS.
# Được setup.sh nạp (source), không chạy riêng.
#
# Quy ước để các phần gọi nhau dễ dàng:
#   - Hàm dùng ở nhiều module đặt ở đây (say, ok, warn, fail, act, have, tilde…).
#   - Hàm riêng của một module đặt trong module đó, tên bắt đầu bằng _<tên module>_.
#   - Hồ sơ OS ghi đè các hàm os_* bên dưới; module chỉ gọi os_*, không tự kiểm tra uname.

GEM="${GEMINI_HOME:-$HOME/.gemini}"          # repo này chính là ~/.gemini
SCRIPTS="$GEM/scripts"
SHARED="$GEM/config"                         # cấu hình chung của Antigravity IDE, app và agy
CLI_DIR="$GEM/antigravity-cli"
CLI_SETTINGS="$CLI_DIR/settings.json"        # settings.json của agy (do agy tự ghi)
HARNESS_SETTINGS="$GEM/agy-settings.json"        # phần harness quản lý, được trộn vào CLI_SETTINGS
BIN="$HOME/.local/bin"
ORIG_PATH="$PATH"
export PATH="$BIN:$GEM/bin:$PATH"   # thấy ngay CLI vừa cài bằng uv tool, và agy ở ~/.gemini/bin

nf=0; nw=0
say()   { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
ok()    { echo "  ✓ $*"; }
warn()  { echo "  ! $*"; nw=$((nw+1)); }
fail()  { echo "  ✗ $*"; nf=$((nf+1)); }
note()  { echo "  · $*"; }
act()   { echo "  → $*"; (( DRY == 1 )) && return 0; "$@"; }
have()  { command -v "$1" >/dev/null 2>&1; }
tilde() { local p="$1" t='~'; echo "${p/#$HOME/$t}"; }
interactive() { [[ -t 0 && -t 1 ]]; }

# ─── Giao diện hồ sơ OS (mặc định = Linux chung) ─────────────────────
# Một hồ sơ trong setup.d/os/ chỉ cần ghi đè những gì khác mặc định.
OS_LABEL="Linux"

# Tên gói của hệ điều hành cho một công cụ (tên chung: git jq node gh uv libnotify terminal-notifier)
os_pkg() { echo "$1"; }

# Lệnh để người dùng tự cài
os_hint() { echo "cài \"$(os_pkg "$1")\" bằng trình quản lý gói của hệ điều hành"; }

# Cài không cần sudo. Trả 0 nếu đã cài; trả 2 nếu không tự cài được (caller in os_hint)
os_install() { return 2; }

os_open_url()  { xdg-open "$1" >/dev/null 2>&1; }
os_file_mode() { stat -c '%a' "$1"; }

# File rc mà shell đăng nhập đọc
os_rc_file() {
  case "$1" in
    zsh)  echo "$HOME/.zshrc" ;;
    bash) echo "$HOME/.bashrc" ;;
    fish) echo "" ;;
    *)    echo "$HOME/.profile" ;;
  esac
}

# Công cụ chỉ cần trên OS này (vd. thông báo desktop). Gọi trong module deps.
os_deps() {
  have notify-send && ok "notify-send" || warn "thiếu notify-send (thông báo desktop): $(os_hint libnotify)"
}
