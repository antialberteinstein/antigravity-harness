---
name: setup-agy-project
description: Phân tích project hiện tại rồi đề xuất và cài skill, subagent (ECC) và MCP ở scope project cho Antigravity (agy, IDE, app), trong plugin ./.agents/plugins/project-kit/, kèm gợi ý plugin marketplace và gợi ý tra cứu web. Chỉ chạy khi người dùng gõ /setup-agy-project.
disable-model-invocation: true
---

# /setup-agy-project

Bản Antigravity của `/setup-project` (Claude Code). Thiết lập cho project trong thư mục
hiện tại: chọn skill, subagent và MCP phù hợp từ catalog, hỏi xác nhận, rồi cài vào **một**
plugin của workspace `./.agents/plugins/project-kit/`. Gỡ cả bộ chỉ cần xoá thư mục đó.

Yêu cầu thêm của người dùng (có thể trống): phần họ gõ sau `/setup-agy-project`.
Ví dụ: `status`, `thêm ml`, `gỡ react`, `cập nhật`, `không gợi ý` (bỏ bước tra cứu web).

Đường dẫn của skill (gõ lệnh slash thì agy không kèm đường dẫn, nên dùng đúng các đường dẫn này):
- catalog: `~/.gemini/config/skills/setup-agy-project/catalog.md`
- script: `~/.gemini/config/skills/setup-agy-project/scripts/agy-project.sh`, gọi là `<script>` bên dưới;
  chạy từ thư mục gốc của project.

Terminal sandbox của agy không đọc được `~/.gemini`: đọc catalog bằng tool đọc file, và chạy
`<script>` ngoài sandbox (agy sẽ hỏi quyền). Không dùng `catalog.md` của `/setup-project` (bản Claude Code).

## Phạm vi được phép
- Chỉ ghi trong `./.agents/plugins/project-kit/` của project. Không sửa `~/.gemini/`,
  `GEMINI.md` / `AGENTS.md` / `CLAUDE.md` của project hay bất kỳ file nào khác.
- Ngoại lệ: plugin marketplace (scope global) chỉ cài khi người dùng đồng ý **đích danh**,
  vì nó áp dụng cho cả máy.
- Không ghi token hay key cố định vào `mcp_config.json`.
- Chỉ cài những gì có trong catalog, hoặc mục ngoài catalog người dùng đã chọn đích danh ở bước 4b.
  Plugin chỉ đề xuất đúng các dòng trong bảng "Plugin Antigravity" của catalog; Antigravity không có
  plugin LSP (`pyright-lsp`, `typescript-lsp`… là của Claude Code).
- Không chạy `sudo`. Thiếu công cụ hệ thống thì báo lệnh cài để người dùng tự chạy.

## Quy trình

### 1. Đọc catalog
Đọc toàn bộ catalog trước khi làm gì khác.

### 2. Khảo sát project
Tìm các dấu hiệu mà catalog liệt kê, bằng cách đọc file chứ không đoán:
`package.json`, `tsconfig.json`, `pyproject.toml`, `requirements*.txt`, `setup.py`,
`CMakeLists.txt`, `Cargo.toml`, `go.mod`, `build.gradle*`, `firebase.json`, `Dockerfile`,
`compose*.yml`, thư mục `tests/`, `migrations/`, `prisma/`. Với dependency, đọc đúng file
khai báo; chỉ tìm import khi không có file khai báo. Bỏ qua `node_modules/`, `.venv/`,
`build/`, `dist/`.

### 3. Đọc hiện trạng
- `bash <script> status`
- `agy plugin list --json | jq -r '.[] | "\(.enabled)\t\(.name)"'` để biết plugin nào đã có
- `agy mcp list` để biết MCP global nào đã có

### 4. Đề xuất và chờ xác nhận
Trình bày **một bảng**, mỗi dòng một thay đổi:

| Thay đổi | Thành phần | Dấu hiệu tìm thấy |
|---|---|---|
| + ECC | `mle-workflow`, `mle-reviewer` | `torch` trong `pyproject.toml` |
| + MCP | `hf` | `transformers` trong `pyproject.toml` |
| + plugin (global) | `firebase` | `firebase.json` |
| − ECC | `react-reviewer` | không còn `react` trong `package.json` |

Sau bảng, liệt kê:
- các thành phần **bỏ qua vì đã có ở scope global** (script cũng tự bỏ qua, nhưng nói trước),
- các **công cụ hệ thống còn thiếu** kèm lệnh cài,
- đúng các lệnh sẽ chạy.

Nếu catalog không có thay đổi nào, nói một câu như vậy rồi vẫn sang bước 4b.

### 4b. Gợi ý thêm ngoài catalog (tra cứu web)
Chạy ngay sau bảng của bước 4, trong cùng một lần trả lời. Áp dụng cả khi gọi kèm tham số
nhóm (vd. `thêm ml`): khi đó chỉ gợi ý trong phạm vi nhóm đó. Bỏ qua nếu tham số có
`không gợi ý`, hoặc yêu cầu chỉ là `status` hay `gỡ …`.

1. **Xác định nhu cầu** từ bước 2: ngôn ngữ, framework, dịch vụ bên ngoài, loại việc lặp lại.
   Bỏ nhu cầu mà catalog, thứ đã cài, hoặc Superpowers đã phủ.
2. **Tìm kiếm web** cho từng nhu cầu, vd. `<dịch vụ> official MCP server`,
   `<framework> agent skill SKILL.md`, `<dịch vụ> Antigravity plugin`. Ưu tiên: marketplace
   `antigravity-plugins-official`; repo do chính nhà cung cấp dịch vụ phát hành; tài liệu
   chính thức; repo cộng đồng được bảo trì tốt.
3. **Xác minh bằng cách mở trang nguồn**, không dựa vào đoạn trích kết quả tìm kiếm. Chỉ giữ mục
   có commit trong 6 tháng gần đây, có giấy phép, có cách cài rõ ràng, không phải mirror,
   không trùng thứ đã cài hay mục "Không bao giờ đề xuất". MCP chỉ dùng được loại stdio hoặc
   Streamable HTTP (agy không hỗ trợ SSE kiểu cũ). Dịch vụ có CLI tốt thì gợi ý CLI thay cho MCP.
4. **Trình bày hai phần** ngay dưới bảng của bước 4:

   **Tối giản (khuyên dùng)**: tối đa 3 mục.

   | Loại | Tên | Vì sao (dấu hiệu trong project) | Nguồn | Lệnh cài |
   |---|---|---|---|---|
   | MCP | `…` | `…` trong `pyproject.toml` | [repo](…) | `agy-project.sh mcp-add …` |

   **Mở rộng theo chức năng**: mỗi chức năng 1–2 lựa chọn, nói rõ khác nhau ở đâu.

   Với mỗi mục, ghi rõ nếu nó chạy lệnh trên máy (MCP stdio), cần token, hay gửi dữ liệu ra
   ngoài. Không bịa tên hay lệnh: không tìm thấy lệnh cài thì ghi "xem README".

Sau đó **dừng lại và chờ người dùng** đồng ý với bảng (có thể bỏ bớt dòng) và chọn đích danh
mục ngoài catalog. Chỉ làm những gì được đồng ý.

### 5. Thực hiện
Chạy từ thư mục gốc của project.

ECC, gộp trong một lệnh:
```bash
bash <script> -n add --skills a,b --agents c,d   # chạy thử trước
bash <script> add --skills a,b --agents c,d
bash <script> remove --skills x --agents y       # khi gỡ
```
Với yêu cầu `cập nhật`: đọc `status`, rồi chạy `add` lại đúng danh sách đó.

MCP, mỗi MCP một lệnh, đúng lệnh trong catalog:
```bash
bash <script> mcp-add <tên> <url>                  # HTTP
bash <script> mcp-add <tên> -- <lệnh> [đối số…]    # stdio
bash <script> remove --mcp <tên>                   # gỡ
```

Plugin marketplace (global), chỉ mục người dùng đồng ý đích danh:
`agy plugin install <tên>@antigravity-plugins-official`.

Mục ngoài catalog đã chọn ở bước 4b:
- MCP: `bash <script> mcp-add …`. Cần token thì để người dùng tự điền sau, không ghi cố định.
- Skill lẻ: clone tạm repo nguồn, chép đúng thư mục skill vào
  `./.agents/plugins/project-kit/skills/<tên>/`, kèm file `SOURCE` ghi URL repo, commit và giấy phép.

Lệnh nào lỗi thì dừng, báo nguyên văn lỗi, không thử cách khác.

### 6. Kiểm tra và báo cáo
- Chạy `bash <script> status` và `agy plugin validate ./.agents/plugins/project-kit`.
- Báo ngắn gọn đã thêm, gỡ những gì, tách riêng mục từ catalog và mục ngoài catalog.
- Nhắc người dùng mở phiên agy mới (hoặc `/skills reload`) để nạp; MCP mới sẽ hỏi quyền lần đầu dùng.
- Nếu project có git và `.agents/` chưa được commit, hỏi người dùng muốn commit cấu hình này
  (để cả nhóm dùng chung) hay bỏ qua. Không tự sửa `.gitignore`.
