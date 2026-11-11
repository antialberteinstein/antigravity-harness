---
name: harness-check
description: Kiểm tra harness Antigravity trong ~/.gemini (settings và quyền của agy, hook, plugin, MCP, rule GEMINI.md, skill trùng, repo harness có lệch với GitHub không), báo lỗi và đề xuất cách sửa. Chỉ chạy khi người dùng gõ /harness-check.
disable-model-invocation: true
---

# /harness-check (Antigravity)

Kiểm tra harness rồi báo cáo. Mặc định **chỉ đọc**: không sửa gì nếu người dùng chưa đồng ý từng mục.
Yêu cầu thêm của người dùng (có thể trống), ví dụ `offline`, `sửa luôn`: phần họ gõ sau `/harness-check`.

## 1. Chạy

```bash
bash ~/.gemini/scripts/setup.sh -n            # deps, CLI + đăng nhập, MCP, quyền script, link, settings, validate
bash ~/.gemini/scripts/agy-sync -n            # plugin còn thiếu, plugin cần tắt, ecc-selected có bản ECC mới
agy mcp list
git -C ~/.gemini status --short               # sửa tay chưa commit trong repo harness
git -C ~/.gemini fetch -q && git -C ~/.gemini status -sb | head -1   # chậm hơn GitHub?
```

Người dùng yêu cầu `offline` thì bỏ `agy-sync -n` (nó gọi git ls-remote) và lệnh `fetch`.
Kết quả của các lệnh trên là sự thật duy nhất; không tự suy thêm lỗi mà chúng không báo.

## 2. Báo cáo

- Gom theo mức: dòng `✗` (lỗi) trước, rồi `!` (cảnh báo). Bỏ các dòng `✓`, chỉ nói tổng số.
- Dòng `→` của `setup.sh -n` hay `agy-sync -n` nghĩa là máy đang lệch so với repo (vd. settings.json thiếu quy tắc, plugin chưa cài): liệt kê như việc cần làm.
- Mỗi mục: lỗi là gì, vì sao đáng lo (một câu), cách sửa cụ thể (lệnh).
- Không đọc hay in giá trị secret (token, API key, nội dung `.env`, `~/.gemini/jetski-standalone-oauth-token`).
- Không có lỗi hay cảnh báo: nói một câu là harness ổn.

## 3. Sửa (chỉ khi người dùng đồng ý)

- Lệch cấu hình: chạy `bash ~/.gemini/scripts/setup.sh` (hoặc `--only <module>`) và `agy-sync`, không sửa tay `~/.gemini/antigravity-cli/settings.json` hay `~/.gemini/config/config.json`.
- Muốn đổi cấu hình lâu dài: sửa file trong repo (`agy-settings.json`, `config/hooks.json`, `scripts/setup.d/config.sh`, `GEMINI.md`), chạy test `bash ~/.gemini/scripts/setup.d/test.sh`, rồi mới áp dụng.
- Không xoá file: thứ cần bỏ thì chuyển vào `~/.gemini/backups/` và báo đã chuyển gì.
- Tắt plugin bằng `agy plugin disable <tên>`, không xoá thư mục plugin.

Sửa xong, chạy lại bước 1 và báo kết quả mới.
