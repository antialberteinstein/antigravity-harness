# setup.d/config.sh — danh sách các thứ setup.sh và agy-sync lo. Sửa ở đây, không cần đụng vào module.
# Ghi đè cho riêng một máy: tạo setup.d/config.local.sh (nạp sau file này).

# CLI cho agent dùng thay MCP. Mỗi dòng: lệnh | gói cài bằng `uv tool` (trống = cài bằng gói hệ điều hành)
TOOLS="gh|
uv|
hf|huggingface_hub[cli]
kaggle|kaggle"

# CLI cần kiểm tra đăng nhập (mỗi cái có xử lý riêng trong module tools)
AUTH_TOOLS="gh hf kaggle"

# MCP dùng chung (~/.gemini/config/mcp_config.json). Mỗi dòng: tên | lệnh khởi chạy.
USER_MCP="context7|npx -y @upstash/context7-mcp"

# Script trong ~/.gemini/scripts/ cần có lệnh gõ được ở mọi nơi (symlink vào ~/.local/bin).
# Lệnh đã có sẵn (vd. `show` của claude-harness) thì giữ nguyên, không ghi đè.
LINKS="agy-sync show"

# Plugin agy-sync cài vào ~/.gemini/config/plugins/. Mỗi dòng: tên thư mục | URL git | tuỳ chọn
#   skills-root  plugin để skill ở thư mục gốc (kiểu Claude Code "skills": "./"), agy chỉ đọc skills/;
#                agy-sync thêm skills.json trỏ vào thư mục gốc để agy thấy các skill đó
PLUGINS="superpowers|https://github.com/obra/superpowers|
andrej-karpathy-skills|https://github.com/multica-ai/andrej-karpathy-skills|
kessie-skills|https://github.com/antialberteinstein/kessie-skills|skills-root"

# Plugin cần tắt (không gỡ). `ecc` là bản ECC đầy đủ import từ Claude Code; harness dùng ecc-selected thay thế.
DISABLE_PLUGINS="ecc"

# Quy tắc quyền cần gỡ khỏi ~/.gemini/antigravity-cli/settings.json (mỗi dòng một quy tắc).
# Bước trộn settings chỉ cộng thêm quy tắc, nên quy tắc harness từng ghi mà nay bỏ đi phải nêu ở đây.
#   read_file(.env…): đường dẫn tương đối làm terminal sandbox báo "non-absolute file path"
#                     và mọi lệnh trong sandbox đều thất bại. .env được chặn bằng hook guard-secrets.
REMOVE_PERMISSIONS="read_file(.env)
read_file(.env.local)"
