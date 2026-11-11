#!/usr/bin/env bash
# build-ecc-plugin.sh — dựng plugin cục bộ `ecc-selected` trong ~/.gemini/config/plugins/ từ phần ECC đã chọn.
#
# Clone ECC vào thư mục tạm, chép skill đã chọn, chuyển agent sang định dạng subagent của Antigravity,
# rồi thay nguyên thư mục plugin (plugin này do script sinh ra, không sửa tay).
# Không lấy hook của ECC: chúng viết cho Claude Code (tên tool, biến CLAUDE_PLUGIN_ROOT, node dispatcher).
#
# Dùng:  build-ecc-plugin.sh        dựng
#        build-ecc-plugin.sh -n     chạy thử, không ghi gì
# Ghim phiên bản:  ECC_REF=<tag|branch|sha> build-ecc-plugin.sh
# Dùng bản ECC có sẵn trên máy (không clone):  ECC_SRC=/đường/dẫn/ECC build-ecc-plugin.sh
#
# Cần: git, jq. Chạy được với bash 3.2.
set -euo pipefail

# ─── Danh sách đã chọn (giống claude-harness) ───────────────────────
SKILLS=(
  # ngôn ngữ
  typescript-patterns python-patterns cpp-coding-standards error-handling
  # bảo mật
  security-review agent-security-hardening
  # ML / MLOps
  pytorch-patterns mle-workflow docker-patterns deployment-patterns
  # LLM / agentic
  agent-harness-construction cost-aware-llm-pipeline prompt-caching-strategy
  mcp-server-patterns regex-vs-llm-structured-text
  # công cụ test (có thể trùng một phần với TDD của Superpowers)
  cpp-testing python-testing
)

AGENTS=(
  typescript-reviewer python-reviewer cpp-reviewer
  build-error-resolver cpp-build-resolver pytorch-build-resolver
  mle-reviewer rag-pipeline-reviewer
  security-reviewer silent-failure-hunter type-design-analyzer
  fastapi-reviewer performance-optimizer
)

REPO="https://github.com/affaan-m/ECC"
NAME="ecc-selected"
# ────────────────────────────────────────────────────────────────────

DRY=0
[[ "${1:-}" == "-n" ]] && DRY=1
GEM="${GEMINI_HOME:-$HOME/.gemini}"
DEST="$GEM/config/plugins/$NAME"

say() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
die() { echo "Lỗi: $*" >&2; exit 1; }

for c in git jq; do
  command -v "$c" >/dev/null || die "thiếu '$c' (macOS: brew install $c · Fedora: sudo dnf install $c)"
done

TMP="$(mktemp -d -t ecc-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

if [[ -n "${ECC_SRC:-}" ]]; then
  SRC="$ECC_SRC"
  SHA="$(git -C "$SRC" rev-parse HEAD 2>/dev/null || echo local)"
else
  say "Clone ECC"
  SRC="$TMP/ECC"
  if [[ -n "${ECC_REF:-}" ]]; then
    git clone -q "$REPO" "$SRC"
    git -C "$SRC" checkout -q "$ECC_REF"
  else
    git clone -q --depth 1 "$REPO" "$SRC"
  fi
  SHA="$(git -C "$SRC" rev-parse HEAD)"
fi
echo "commit $SHA"

missing=0
for a in "${AGENTS[@]}"; do
  [[ -f "$SRC/agents/$a.md" ]] || { echo "Không có agent: $a" >&2; missing=1; }
done
for s in "${SKILLS[@]}"; do
  [[ -f "$SRC/skills/$s/SKILL.md" ]] || { echo "Không có skill: $s" >&2; missing=1; }
done
(( missing == 0 )) || die "ECC đã đổi tên hoặc xoá thành phần ở trên; sửa danh sách rồi chạy lại"

# Agent Claude Code → subagent Antigravity (theo skill migrate-agent-settings có sẵn trong agy):
#   tools: Read/Glob/Grep → read_file, Edit/MultiEdit → edit_file, Write → write_file,
#          Bash → run_command + manage_task, WebSearch/WebFetch → search_web; thiếu tools = mọi tool
#   bỏ model, color; thêm subagent: true, mainAgent: false
convert_agent() { # file nguồn → in ra stdout; tool không đổi được thì in tên lên stderr
  awk '
    function add(t) { if (!(t in seen)) { seen[t] = 1; out = out (out == "" ? "" : ", ") t } }
    function map(t) {
      gsub(/[][" '\''\t]/, "", t)
      if (t == "") return
      if (t == "Read" || t == "Glob" || t == "Grep") add("read_file")
      else if (t == "Edit" || t == "MultiEdit") add("edit_file")
      else if (t == "Write") add("write_file")
      else if (t == "Bash") { add("run_command"); add("manage_task") }
      else if (t == "WebSearch" || t == "WebFetch") add("search_web")
      else print t > "/dev/stderr"
    }
    NR == 1 && /^---[ \t]*$/ { fm = 1; print; next }
    fm == 1 && /^---[ \t]*$/ {
      if (!has_tools) out = "read_file, edit_file, write_file, run_command, manage_task, search_web"
      print "tools: [" out "]"
      print "subagent: true"
      print "mainAgent: false"
      print; fm = 2; next
    }
    fm == 1 && in_list && /^[ \t]+-/ { sub(/^[ \t]+-[ \t]*/, ""); map($0); next }
    fm == 1 { in_list = 0 }
    fm == 1 && /^tools:/ {
      has_tools = 1; v = $0; sub(/^tools:[ \t]*/, "", v)
      if (v == "") { in_list = 1; next }
      n = split(v, parts, ","); for (i = 1; i <= n; i++) map(parts[i]); next
    }
    fm == 1 && /^(model|color):/ { next }
    { print }
  ' "$1"
}

say "Dựng plugin $NAME (${#SKILLS[@]} skill, ${#AGENTS[@]} agent)"
STAGE="$TMP/$NAME"
mkdir -p "$STAGE/skills" "$STAGE/agents"
for s in "${SKILLS[@]}"; do cp -R "$SRC/skills/$s" "$STAGE/skills/$s"; done
for a in "${AGENTS[@]}"; do
  dropped=$(convert_agent "$SRC/agents/$a.md" 2>&1 >"$STAGE/agents/$a.md" | tr '\n' ' ')
  [[ -n "$dropped" ]] && echo "  $a: bỏ tool không có trong Antigravity: $dropped"
done
cp "$SRC/LICENSE" "$STAGE/LICENSE"   # điều kiện của giấy phép MIT
jq -n --arg sha "$SHA" '{
    name: "ecc-selected",
    displayName: "ECC (selected)",
    version: "1.0.0",
    description: "Skill và subagent chọn lọc từ ECC (Affaan Mustafa, MIT), do build-ecc-plugin.sh sinh ra từ commit \($sha[0:7])",
    author: {name: "Affaan Mustafa"},
    repository: "https://github.com/affaan-m/ECC",
    license: "MIT"
  }' > "$STAGE/plugin.json"
{
  echo "source: $REPO"
  echo "commit: $SHA"
  echo "built: $(date +%Y-%m-%dT%H:%M:%S%z)"
  echo "agents: ${AGENTS[*]}"
  echo "skills: ${SKILLS[*]}"
} > "$STAGE/SOURCE"

if command -v agy >/dev/null; then
  agy plugin validate "$STAGE" 2>&1 | grep -E '✗|Error|error|✔' || true
fi

if (( DRY == 1 )); then
  say "Chạy thử xong, chưa ghi gì vào $DEST"
  exit 0
fi
mkdir -p "$(dirname "$DEST")"
rm -rf "$DEST"
mv "$STAGE" "$DEST"
say "Xong: $DEST (ECC ${SHA:0:7}). Mở phiên agy mới rồi chạy /skills và /agents để kiểm tra."
