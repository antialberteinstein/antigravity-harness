#!/usr/bin/env bash
# ~/.gemini/scripts/notify.sh — hook Stop (config/hooks.json): báo khi agent làm xong, trên macOS và Linux.
#
# agy đã có thông báo riêng (`"notifications": true` trong settings.json: chuông + thông báo desktop
# khi cần duyệt và khi xong lượt), nên mặc định hook này bỏ qua phiên agy và chỉ báo cho
# Antigravity IDE và app. Hook nhận JSON trên stdin và phải in JSON ra stdout: in {} để agent dừng bình thường.
#
#   AGY_NOTIFY_CLI=1     báo cả cho phiên agy
#   AGY_NOTIFY_SOUND=0   tắt âm thanh
#   AGY_NOTIFY_LOG=1     ghi mỗi lần hook chạy vào ~/.gemini/notify.log
# Chạy được với bash 3.2. Không bao giờ chặn agent.

input=$(cat)
echo '{}'

reason=""; transcript=""; proj=""; err=""
if command -v jq >/dev/null 2>&1; then
  reason=$(jq -r '.terminationReason // empty' <<<"$input" 2>/dev/null)
  transcript=$(jq -r '.transcriptPath // empty' <<<"$input" 2>/dev/null)
  err=$(jq -r '.error // empty' <<<"$input" 2>/dev/null)
  d=$(jq -r '.workspacePaths[0] // .cwd // empty' <<<"$input" 2>/dev/null); [[ -n "$d" ]] && proj=$(basename "$d")
fi

case "$transcript" in
  */antigravity-cli/*) product=cli; app="Antigravity CLI" ;;
  */antigravity-ide/*) product=ide; app="Antigravity IDE" ;;
  *)                   product=app; app="Antigravity" ;;
esac

skip=""
[[ "$reason" == USER_CANCELED ]] && skip="huỷ bởi người dùng"
[[ "$product" == cli && "${AGY_NOTIFY_CLI:-0}" != 1 ]] && skip="agy tự báo"

if [[ "$reason" == ERROR ]]; then msg="Dừng vì lỗi${err:+: $err}"; else msg="Đã làm xong"; fi
title="$app${proj:+ · $proj}"

if [[ "${AGY_NOTIFY_LOG:-0}" == 1 ]]; then
  printf '%s  reason=%s  product=%s  skip=%s  msg=%s\n' "$(date '+%F %T')" "${reason:-?}" \
    "$product" "${skip:--}" "$msg" >> "$HOME/.gemini/notify.log" 2>/dev/null
fi
[[ -n "$skip" ]] && exit 0

sound="${AGY_NOTIFY_SOUND:-1}"
case "$(uname -s)" in
  Darwin)
    if command -v terminal-notifier >/dev/null 2>&1; then
      args=(-title "$title" -message "$msg" -group "antigravity")
      [[ "$sound" == 1 ]] && args+=(-sound Glass)
      terminal-notifier "${args[@]}" >/dev/null 2>&1
    else
      osascript -e 'on run argv' \
                -e 'display notification (item 1 of argv) with title (item 2 of argv)' \
                -e 'end run' "$msg" "$title" >/dev/null 2>&1
      [[ "$sound" == 1 ]] && { afplay /System/Library/Sounds/Glass.aiff >/dev/null 2>&1 & }
    fi
    ;;
  Linux)
    command -v notify-send >/dev/null 2>&1 && notify-send -a "Antigravity" -i dialog-information "$title" "$msg" >/dev/null 2>&1
    if [[ "$sound" == 1 ]]; then
      oga=/usr/share/sounds/freedesktop/stereo/message.oga
      if command -v canberra-gtk-play >/dev/null 2>&1; then
        { canberra-gtk-play -i message-new-instant >/dev/null 2>&1 & }
      elif [[ -f "$oga" ]] && command -v pw-play >/dev/null 2>&1; then
        { pw-play "$oga" >/dev/null 2>&1 & }
      elif [[ -f "$oga" ]] && command -v paplay >/dev/null 2>&1; then
        { paplay "$oga" >/dev/null 2>&1 & }
      fi
    fi
    ;;
esac
exit 0
