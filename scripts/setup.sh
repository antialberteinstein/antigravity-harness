#!/usr/bin/env bash
# ~/.gemini/scripts/setup.sh — chuẩn bị harness cho Antigravity (IDE, app, CLI agy) trên một máy.
# Chạy lại bao nhiêu lần cũng được: bước nào đã xong thì bỏ qua.
#
# Dùng:  setup.sh                   chạy mọi module
#        setup.sh -n                chạy thử, chỉ in ra sẽ làm gì
#        setup.sh --install         cài các CLI còn thiếu (không bao giờ sudo; lệnh cần sudo chỉ được in ra)
#        setup.sh --include-login   CLI nào chưa đăng nhập thì mở lệnh đăng nhập (cần terminal tương tác)
#        setup.sh --add-path        thêm ~/.local/bin vào PATH trong file rc của shell nếu thiếu
#        setup.sh --sync            chạy xong thì gọi agy-sync (cài plugin + ECC chọn lọc)
#        setup.sh --only tools,mcp  chỉ chạy các module được nêu
#        setup.sh --os fedora       bỏ qua nhận diện, dùng hồ sơ OS được nêu
#        setup.sh --list            in OS nhận diện được và danh sách module, rồi thoát
#
# Cấu trúc:
#   setup.d/lib.sh          hàm dùng chung + hành vi mặc định của hồ sơ OS
#   setup.d/config.sh       danh sách CLI, MCP, plugin, lệnh cần đưa ra ~/.local/bin (sửa ở đây)
#   setup.d/config.local.sh (tuỳ chọn, không bắt buộc) ghi đè config cho riêng máy này
#   setup.d/os/<id>.sh      phần riêng của từng hệ điều hành (darwin, fedora, linux = dự phòng)
#   setup.d/modules/NN-<tên>.sh   mỗi file một bước, định nghĩa hàm step_<tên>, chạy theo thứ tự NN
# Thêm OS: tạo os/<ID trong /etc/os-release>.sh. Thêm bước: tạo modules/NN-<tên>.sh.
# Chạy được với bash 3.2.

set -uo pipefail

# Thư mục thật của script, kể cả khi gọi qua symlink (không dùng readlink -f: macOS cũ không có)
src="${BASH_SOURCE[0]}"
while [[ -L "$src" ]]; do
  d="$(cd "$(dirname "$src")" && pwd)"; src="$(readlink "$src")"; [[ "$src" == /* ]] || src="$d/$src"
done
SETUP_DIR="$(cd "$(dirname "$src")" && pwd)/setup.d"
[[ -d "$SETUP_DIR" ]] || { echo "Không thấy $SETUP_DIR" >&2; exit 1; }

DRY=0; SYNC=0; ADD_PATH=0; INSTALL=0; LOGIN=0; ONLY=""; FORCE_OS=""; LIST=0
while (( $# )); do
  case "$1" in
    -n) DRY=1 ;;
    --sync) SYNC=1 ;;
    --add-path) ADD_PATH=1 ;;
    --install) INSTALL=1 ;;
    --include-login|--login) LOGIN=1 ;;
    --only) ONLY="${2:-}"; shift ;;
    --os) FORCE_OS="${2:-}"; shift ;;
    --list) LIST=1 ;;
    -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Tham số lạ: $1" >&2; exit 2 ;;
  esac
  shift
done

# shellcheck source=setup.d/lib.sh
. "$SETUP_DIR/lib.sh"
# shellcheck source=setup.d/config.sh
. "$SETUP_DIR/config.sh"
[[ -f "$SETUP_DIR/config.local.sh" ]] && . "$SETUP_DIR/config.local.sh"

# ─── Nhận diện OS ────────────────────────────────────────────────────
# Thứ tự thử: --os; macOS → darwin; Linux → ID rồi từng ID_LIKE trong /etc/os-release; cuối cùng linux.
detect_os() {
  if [[ -n "$FORCE_OS" ]]; then echo "$FORCE_OS"; return; fi
  case "$(uname -s)" in
    Darwin) echo darwin; return ;;
    Linux)
      local rel="${SETUP_OS_RELEASE:-/etc/os-release}" id="" like="" c
      if [[ -f "$rel" ]]; then
        id=$(sed -n 's/^ID=//p' "$rel" | tr -d '"' | head -1)
        like=$(sed -n 's/^ID_LIKE=//p' "$rel" | tr -d '"' | head -1)
      fi
      for c in $id $like; do
        [[ -f "$SETUP_DIR/os/$c.sh" ]] && { echo "$c"; return; }
      done
      echo linux ;;
    *) echo unknown ;;
  esac
}
OS_ID="$(detect_os)"
if [[ -f "$SETUP_DIR/os/$OS_ID.sh" ]]; then
  . "$SETUP_DIR/os/$OS_ID.sh"
else
  OS_FALLBACK="$OS_ID"; OS_ID=linux; . "$SETUP_DIR/os/linux.sh"
fi

# ─── Nạp module ──────────────────────────────────────────────────────
STEPS=()
for f in "$SETUP_DIR"/modules/*.sh; do
  [[ -f "$f" ]] || continue
  . "$f"
  n="${f##*/}"; n="${n%.sh}"; n="${n#*-}"
  if declare -F "step_$n" >/dev/null; then STEPS+=("$n")
  else echo "Module ${f##*/} không định nghĩa hàm step_$n, bỏ qua" >&2; fi
done

if (( LIST == 1 )); then
  echo "OS: $OS_LABEL (setup.d/os/$OS_ID.sh)${OS_FALLBACK:+, dự phòng cho \"$OS_FALLBACK\"}"
  echo "Module: ${STEPS[*]}"
  exit 0
fi

# ─── Chạy ────────────────────────────────────────────────────────────
echo "Antigravity harness setup · $OS_LABEL · $(tilde "$GEM")$( (( DRY == 1 )) && echo ' · CHẠY THỬ')"
[[ -n "${OS_FALLBACK:-}" ]] && warn "chưa có hồ sơ cho \"$OS_FALLBACK\": dùng hồ sơ Linux chung (chỉ in lệnh cài, không tự cài)"
if [[ -n "$ONLY" ]]; then
  for s in $(tr ',' ' ' <<<"$ONLY"); do
    case " ${STEPS[*]} " in *" $s "*) ;; *) fail "không có module \"$s\" (có: ${STEPS[*]})" ;; esac
  done
fi
for s in "${STEPS[@]}"; do
  if [[ -n "$ONLY" ]]; then case ",$ONLY," in *",$s,"*) ;; *) continue ;; esac; fi
  "step_$s"
done

echo
echo "Xong: $nf lỗi, $nw cảnh báo."
(( nf == 0 )) || exit 1
