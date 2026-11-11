# Catalog cho /setup-agy-project

Bảng đề xuất chính (bước 4) chỉ lấy từ file này. Mỗi mục có **dấu hiệu**: chỉ đề xuất
khi tìm thấy dấu hiệu đó trong project, và nêu dấu hiệu đó trong bảng đề xuất. Gợi ý
tìm trên web (bước 4b) trình bày riêng và chỉ cài khi người dùng chọn đích danh.

Mọi thứ ở scope project được cài vào **một** plugin của workspace:
`./.agents/plugins/project-kit/` (skill, subagent, `mcp_config.json`), bằng
`scripts/agy-project.sh`.

## Plugin Antigravity (marketplace `antigravity-plugins-official`, scope **global**)

agy chỉ cài plugin marketplace vào `~/.gemini/config/plugins/`, dùng cho mọi project.
Vì vậy chỉ **gợi ý** khi có dấu hiệu và plugin chưa có trong `agy plugin list`; nói rõ là
cài cho cả máy, và chỉ chạy lệnh khi người dùng đồng ý.

| Plugin | Dấu hiệu | Lệnh |
|---|---|---|
| `android-cli-plugin` | `build.gradle*`, `settings.gradle*`, `AndroidManifest.xml` | `agy plugin install android-cli-plugin@antigravity-plugins-official` |
| `firebase` | `firebase.json`, `.firebaserc`, `firebase` / `firebase-admin` trong dependency | `agy plugin install firebase@antigravity-plugins-official` |
| `chrome-devtools-plugin` | project có UI web (React/Vue/Svelte, `index.html`, Tailwind) | `agy plugin install chrome-devtools-plugin@antigravity-plugins-official` |
| `modern-web-guidance-plugin` | như trên | `agy plugin install modern-web-guidance-plugin@antigravity-plugins-official` |

Không có plugin LSP như bên Claude Code: Antigravity không có loại plugin này.

## MCP (scope project, ghi vào `project-kit/mcp_config.json`)

| MCP | Dấu hiệu | Lệnh thêm | Cần có trên máy |
|---|---|---|---|
| `hf` (Hugging Face Hub) | `transformers`, `datasets`, `huggingface_hub`, `unsloth`, `peft`, `trl` trong dependency | `agy-project.sh mcp-add hf https://huggingface.co/mcp` | — |
| `colab` (Google Colab) | `*.ipynb` có code huấn luyện, hoặc người dùng nói đang dùng Colab | `agy-project.sh mcp-add colab -- uvx git+https://github.com/googlecolab/colab-mcp` | `uvx` (cài `uv`) |
| `playwright` | `playwright` / `@playwright/test` **đã có** trong dependency | `agy-project.sh mcp-add playwright -- npx @playwright/mcp@latest` | `npx` (Node) |

- agy đặt tên tool của MCP trong plugin là `project-kit_<tên>` và hỏi quyền lần đầu dùng.
  Không thêm quy tắc `mcp(...)` vào settings thay người dùng.
- `hf` không cần token cho bộ tool cơ bản. Muốn dùng tool cần đăng nhập thì thay URL bằng
  `https://huggingface.co/mcp?login`. Không bao giờ ghi token cố định vào `mcp_config.json`.
- `colab` điều khiển notebook đang mở trên trình duyệt, chạy code bằng tài khoản Google
  của người dùng. Nêu rõ điều này trong bảng đề xuất.
- UI web mà chưa dùng Playwright: **không** đề xuất `playwright`. agy có sẵn subagent
  duyệt web (`/browser`), và `chrome-devtools-plugin` lo phần gỡ lỗi trình duyệt.
- `context7` thuộc scope global (do `setup.sh` của harness cài). Không thêm ở scope project.

## Thành phần ECC (cài bằng `scripts/agy-project.sh add`)

Script tự bỏ qua thứ đã có ở scope global (vd. plugin `ecc-selected` của harness đã có
`python-testing`, `pytorch-patterns`, `security-reviewer`…), và chuyển agent sang
subagent của Antigravity.

### ml — PyTorch, huấn luyện, fine-tune
Dấu hiệu: `torch`, `transformers`, `unsloth`, `peft`, `lightning` trong dependency hoặc import; `*.ipynb` huấn luyện.
- skills: `pytorch-patterns`, `mle-workflow`
- agents: `pytorch-build-resolver`, `mle-reviewer`

### rag — truy hồi, embedding, vector store
Dấu hiệu: `langchain`, `llama_index`, `chromadb`, `faiss`, `qdrant`, `pgvector`, thư mục embedding/index.
- agents: `rag-pipeline-reviewer`
- skills: `iterative-retrieval`

### llm-app — gọi API LLM, agent
Dấu hiệu: `anthropic`, `openai`, `google-genai`, `@google/genai`, `@anthropic-ai/sdk`, `mcp`, `@modelcontextprotocol/sdk`.
- skills: `cost-aware-llm-pipeline`, `prompt-caching-strategy`, `agent-harness-construction`, `mcp-server-patterns`, `agent-security-hardening`

### fastapi
Dấu hiệu: `fastapi` trong dependency.
- skills: `fastapi-patterns`
- agents: `fastapi-reviewer`

### python-test
Dấu hiệu: `pytest` trong dependency hoặc thư mục `tests/` Python.
- skills: `python-testing`

### cpp
Dấu hiệu: `CMakeLists.txt`, `*.c`, `*.cpp`, `*.h`, `compile_commands.json`.
- skills: `cpp-coding-standards`, `cpp-testing`
- agents: `cpp-build-resolver`, `cpp-reviewer`

### react
Dấu hiệu: `react` trong `package.json`.
- skills: `react-patterns`, `react-testing`, `frontend-patterns`, `accessibility`
- agents: `react-reviewer`

### android — Kotlin, Android
Dấu hiệu: như `android-cli-plugin`, hoặc file `*.kt`.
- skills: `android-clean-architecture`, `kotlin-patterns`, `kotlin-testing`
- agents: `kotlin-reviewer`

### database
Dấu hiệu: `prisma/`, `alembic/`, `migrations/`, `psycopg`, `pg`, `sqlalchemy`, file `*.sql`.
- skills: `postgres-patterns`, `database-migrations`
- agents: `database-reviewer`

### container
Dấu hiệu: `Dockerfile`, `docker-compose*.yml`, `compose*.yml`.
- skills: `docker-patterns`, `deployment-patterns`

## Không bao giờ đề xuất
- Plugin `ecc` (bản ECC đầy đủ, harness đã tắt), profile của trình cài ECC, rule `common`, hook của ECC (viết cho Claude Code).
- MCP filesystem, fetch, memory, sequential-thinking (agy đã có sẵn), GitHub MCP
  (dùng `gh`), Kaggle MCP bản cộng đồng (dùng CLI `kaggle`), MCP trình duyệt khi
  project chưa dùng Playwright.
- `tdd-workflow`, `verification-loop`, `planner`, `tdd-guide`, `code-reviewer`, `orch-*`
  (trùng Superpowers).
- Bất cứ thứ gì ngoài catalog này trong bảng đề xuất chính. Thứ khác chỉ xuất hiện ở
  phần gợi ý tra cứu web (bước 4b), và chỉ cài khi người dùng chọn đích danh.
