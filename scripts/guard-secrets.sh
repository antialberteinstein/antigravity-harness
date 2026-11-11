#!/usr/bin/env bash
# ~/.gemini/scripts/guard-secrets.sh — hook PreToolUse (config/hooks.json): chặn tool file đọc hay sửa .env.
#
# Vì sao là hook mà không phải quy tắc quyền: read_file(.env) là đường dẫn tương đối, và terminal sandbox
# của agy từ chối mọi lệnh khi có quy tắc như vậy ("non-absolute file path"). Quyền cũng không có glob.
# Hook chạy cho cả Antigravity IDE, app và agy.
#
# Chặn: .env, .env.<gì cũng được> ở mọi thư mục. Cho qua: .env.example, .env.sample, .env.template.
# Không phải .env thì không in gì: agy đi tiếp luồng quyền bình thường (in {} thì agy coi là từ chối).
# Chạy được với bash 3.2.

input=$(cat)
command -v jq >/dev/null 2>&1 || exit 0
paths=$(jq -r '.toolCall.args // {} | to_entries[] | select(.key | test("path|file"; "i")) | .value | strings' \
          <<<"$input" 2>/dev/null) || exit 0

while IFS= read -r p; do
  b="${p##*/}"
  case "$b" in
    .env.example|.env.sample|.env.template) ;;
    .env|.env.*)
      jq -nc --arg f "$b" '{decision: "deny",
        reason: "\($f) có thể chứa secret nên harness chặn tool file đọc hay sửa nó. Nếu cần biết biến nào có, hỏi người dùng hoặc đọc .env.example."}'
      exit 0 ;;
  esac
done <<<"$paths"
exit 0
