#!/usr/bin/env bash
# ~/.gemini/scripts/guard-rm.sh — hook PreToolUse (config/hooks.json): chặn lệnh shell xoá đệ quy.
#
# Vì sao là hook: quy tắc quyền khớp theo tiền tố, nên deny command(rm -rf) chỉ chặn đúng chuỗi
# "rm -rf"; rm -fr, rm -r -f, rm -Rf, /bin/rm -rf, rm -r đều lọt (đã thử với agy -p).
#
# Chặn: rm (mọi đường dẫn: /bin/rm, \rm…) có cờ -r/-R ở bất kỳ vị trí, thứ tự nào, hay --recursive;
#       find … -delete. Xét mọi đoạn của chuỗi lệnh (; && || | $( ), cả trong bash -c "…", xargs, -exec.
# Cho qua: rm từng file, git rm -r (khôi phục được từ git).
# Cố ý chặn thừa: chữ "rm -r" nằm trong chuỗi trích dẫn (vd. echo "rm -rf") cũng bị chặn.
# Không chặn được mọi cách xoá (python shutil.rmtree, perl…): đây là lưới an toàn, không phải sandbox.
# Không chặn thì không in gì: agy đi tiếp luồng quyền bình thường (in {} thì agy coi là từ chối).
# Chạy được với bash 3.2.

input=$(cat)
command -v jq >/dev/null 2>&1 || exit 0
cmd=$(jq -r '.toolCall.args // {} | to_entries[] | select(.key | test("command"; "i")) | .value | strings' \
        <<<"$input" 2>/dev/null) || exit 0
[[ -n "$cmd" ]] || exit 0

hit=$(awk '
  { s = s " " $0 " ; " }
  END {
    gsub(/["\047`\\]/, " ", s)              # bỏ dấu nháy, backtick, gạch chéo ngược: bash -c "rm -rf x", \rm
    gsub(/\$\(|[;&|(){}]/, " ; ", s)        # ranh giới giữa các lệnh
    n = split(s, t, /[ \t]+/)
    for (i = 1; i <= n; i++) {
      b = t[i]; sub(/.*\//, "", b)
      if (b == "rm" && t[i-1] != "git") {
        for (j = i + 1; j <= n && t[j] != ";" && t[j] != "--"; j++)
          if (t[j] ~ /^-[A-Za-z]*[rR]/ || t[j] ~ /^--r/) { print "rm đệ quy"; exit }
      }
      if (b == "find") {
        for (j = i + 1; j <= n && t[j] != ";"; j++)
          if (t[j] == "-delete") { print "find -delete"; exit }
      }
    }
  }' <<<"$cmd")

[[ -n "$hit" ]] || exit 0
jq -nc --arg h "$hit" '{decision: "deny",
  reason: "Harness chặn lệnh xoá đệ quy (\($h)). Nếu thật sự cần xoá thư mục, dừng lại và nhờ người dùng tự chạy lệnh."}'
exit 0
