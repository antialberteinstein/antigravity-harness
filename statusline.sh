#!/usr/bin/env bash
# ~/.gemini/statusline.sh — statusline kiểu lualine cho Antigravity CLI (agy).
#
#  PLAN  main*  ~/src/kessie           quota 23%  ctx ▰▰▰▱▱▱ 42%  Gemini 3.8 Flash (Medium)
#  └─ A ┘└─ B ─┘└──── C ────┘           └── X ───┘ └──── Y ─────┘ └────────── Z ──────────┘
#
# agy đưa JSON trạng thái phiên vào stdin (antigravity.google/docs/cli/statusline).
# A = chế độ Vim nếu bật, không thì chế độ agent (PLAN, AUTO, EDITS), mặc định Antigravity.
# X = phần quota đã dùng của nhóm quota còn ít nhất. Chạy được với bash 3.2 (macOS).
# Tuỳ chỉnh bằng biến môi trường:
#   AGY_SL_THEME   tokyonight (mặc định, khớp colorScheme "tokyo night") | catppuccin | gruvbox
#   AGY_SL_NERD=0  không dùng glyph Nerd Font (khi terminal không có font)

input=$(cat)
command -v jq >/dev/null 2>&1 || { echo "Antigravity"; exit 0; }

# ─── Bảng màu ────────────────────────────────────────────────────────
case "${AGY_SL_THEME:-tokyonight}" in
  catppuccin)
    BG=1e1e2e S0=313244 S1=45475a TX=cdd6f4 BLUE=89b4fa GREEN=a6e3a1
    PURPLE=cba6f7 YELLOW=f9e2af ORANGE=fab387 RED=f38ba8 ;;
  gruvbox)
    BG=282828 S0=3c3836 S1=504945 TX=ebdbb2 BLUE=83a598 GREEN=b8bb26
    PURPLE=d3869b YELLOW=fabd2f ORANGE=fe8019 RED=fb4934 ;;
  *) # tokyo night
    BG=1a1b26 S0=292e42 S1=3b4261 TX=c0caf5 BLUE=7aa2f7 GREEN=9ece6a
    PURPLE=bb9af7 YELLOW=e0af68 ORANGE=ff9e64 RED=f7768e ;;
esac

if [[ "${AGY_SL_NERD:-1}" == 0 ]]; then
  SEP_L=""; SEP_R=""; I_GIT=""; I_DIR=""; I_MODEL=""; I_CTX="ctx"; I_LIM="quota"
else
  # viết bằng byte UTF-8 vì bash 3.2 không hiểu \u trong $'...'
  SEP_L=$(printf '\xee\x82\xb0'); SEP_R=$(printf '\xee\x82\xb2')
  I_GIT="$(printf '\xee\x82\xa0') "; I_DIR="$(printf '\xef\x81\xbb') "
  I_MODEL="$(printf '\xf3\xb0\x9a\xa9') "
  I_CTX=$(printf '\xef\x8b\x9b'); I_LIM="$(printf '\xef\x80\x97') quota"
fi

# ─── Màu ANSI truecolor ──────────────────────────────────────────────
rgb() { printf '%d;%d;%d' "0x${1:0:2}" "0x${1:2:2}" "0x${1:4:2}"; }
fg()  { printf '\033[38;2;%sm' "$(rgb "$1")"; }
bg()  { printf '\033[48;2;%sm' "$(rgb "$1")"; }
R=$'\033[0m'; B=$'\033[1m'

# ─── Dữ liệu ─────────────────────────────────────────────────────────
j() { jq -r "$1 // empty" <<<"$input" 2>/dev/null; }
model=$(j '.model.display_name'); [[ -n "$model" ]] || model=$(j '.model.id'); [[ -n "$model" ]] || model=Antigravity
dir=$(j '.workspace.current_dir'); [[ -n "$dir" ]] || dir=$(j '.cwd'); [[ -n "$dir" ]] || dir="$PWD"
vim_mode=$(j '.vim.mode')
cycle=$(j '.cycle_mode')
ctx=$(j '.context_window.used_percentage | floor')
# quota: nhóm còn ít nhất quyết định; bỏ qua nhóm bị tắt
lim=$(j '[.quota // {} | .[] | select((.disabled // false) | not) | .remaining_fraction | numbers]
         | if length > 0 then ((1 - min) * 100 | floor) else empty end')
width=$(j '.terminal_width'); [[ -n "$width" ]] || width="${COLUMNS:-0}"

t='~'; short="${dir/#$HOME/$t}"   # qua biến: bash 5 in "\~" nếu viết thẳng \~
# thu gọn đường dẫn dài: ~/a/b/c/d → ~/…/c/d
IFS=/ read -r -a parts <<<"$short"
if (( ${#parts[@]} > 4 )); then short="${parts[0]}/…/${parts[${#parts[@]}-2]}/${parts[${#parts[@]}-1]}"; fi

branch=""
if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$dir" symbolic-ref --short -q HEAD 2>/dev/null || git -C "$dir" rev-parse --short HEAD 2>/dev/null)
  [[ -n "$(git -C "$dir" status --porcelain --untracked-files=no 2>/dev/null | head -1)" ]] && branch="$branch*"
fi

level_color() { # % → màu
  if (( $1 >= 90 )); then echo "$RED"; elif (( $1 >= 70 )); then echo "$YELLOW"; else echo "$GREEN"; fi
}
bar() { # % → ▰▰▰▱▱▱
  local n=$(( ($1 * 6 + 50) / 100 )) out="" i
  (( n > 6 )) && n=6
  for (( i = 0; i < 6; i++ )); do (( i < n )) && out+="▰" || out+="▱"; done
  printf '%s' "$out"
}

# ─── Dựng segment ────────────────────────────────────────────────────
LEFT=""; prev=""
seg_l() { # bg fg text [bold]
  if [[ -n "$prev" ]]; then LEFT+="$(bg "$1")$(fg "$prev")${SEP_L}"; fi
  LEFT+="$(bg "$1")$(fg "$2")${4:+$B} $3 ${R}"
  prev="$1"
}
end_l() { [[ -n "$prev" ]] && LEFT+="$(fg "$prev")${SEP_L}${R}"; }

RIGHT=""; rprev=""
seg_r() { # bg fg text [bold]
  if [[ -n "$rprev" ]]; then RIGHT+="$(bg "$rprev")$(fg "$1")${SEP_R}"; else RIGHT+="$(fg "$1")${SEP_R}"; fi
  RIGHT+="$(bg "$1")$(fg "$2")${4:+$B} $3 ${R}"
  rprev="$1"
}

case "$vim_mode" in
  NORMAL)  seg_l "$BLUE"   "$BG" "NORMAL" b ;;
  INSERT)  seg_l "$GREEN"  "$BG" "INSERT" b ;;
  VISUAL*) seg_l "$PURPLE" "$BG" "$vim_mode" b ;;
  *)
    case "$cycle" in
      plan)         seg_l "$BLUE"   "$BG" "PLAN" b ;;
      auto)         seg_l "$ORANGE" "$BG" "AUTO" b ;;
      accept-edits) seg_l "$GREEN"  "$BG" "EDITS" b ;;
      *)            seg_l "$PURPLE" "$BG" "Antigravity" b ;;
    esac ;;
esac
[[ -n "$branch" ]] && seg_l "$S1" "$TX" "${I_GIT}${branch}"
seg_l "$S0" "$TX" "${I_DIR}${short}"
end_l

[[ -n "$lim" ]] && seg_r "$S0" "$(level_color "$lim")" "${I_LIM} ${lim}%"
[[ -n "$ctx" ]] && seg_r "$S1" "$(level_color "$ctx")" "${I_CTX} $(bar "$ctx") ${ctx}%"
seg_r "$PURPLE" "$BG" "${I_MODEL}${model}" b

# ─── Căn phải như lualine (terminal_width do agy đưa vào) ────────────
visible() { sed $'s/\033\\[[0-9;]*m//g' <<<"$1"; }
lw=$(visible "$LEFT"); rw=$(visible "$RIGHT")
gap=$(( width - ${#lw} - ${#rw} - 4 ))   # chừa lề để không bị xuống dòng
if (( width == 0 )); then
  printf '%s  %s\n' "$LEFT" "$RIGHT"
elif (( gap >= 1 )); then
  printf '%s%*s%s\n' "$LEFT" "$gap" "" "$RIGHT"
else
  printf '%s\n' "$LEFT"            # terminal hẹp: bỏ phần bên phải
fi
