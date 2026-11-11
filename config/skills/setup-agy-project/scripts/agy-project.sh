#!/usr/bin/env bash
# agy-project.sh — thêm/gỡ skill, subagent của ECC và MCP cho project hiện tại, trong một plugin
# của workspace: ./.agents/plugins/project-kit/ (Antigravity IDE, app và agy đều nạp).
# Dùng bởi skill /setup-agy-project, nhưng chạy tay cũng được.
#
#   agy-project.sh [-n] add    --skills a,b --agents c,d    thêm từ ECC (clone tạm, chép, xoá clone)
#   agy-project.sh [-n] remove --skills a,b --agents c,d --mcp x,y
#   agy-project.sh [-n] mcp-add <tên> <url>                 MCP qua HTTP
#   agy-project.sh [-n] mcp-add <tên> -- <lệnh> [đối số…]   MCP chạy lệnh trên máy (stdio)
#   agy-project.sh status                                   in những gì đã cài
#
# -n: chạy thử. Bỏ qua skill/agent đã có ở scope global (~/.gemini/config) để không nạp hai lần.
# Agent ECC được chuyển sang định dạng subagent của Antigravity (scripts/lib/convert-agent.awk của harness).
# Ghim phiên bản ECC: ECC_REF=<tag|branch|sha>. Dùng ECC có sẵn: ECC_SRC=<thư mục>. Cần: git, jq.
set -euo pipefail

REPO="https://github.com/affaan-m/ECC"
GEM="${GEMINI_HOME:-$HOME/.gemini}"
CONVERT="$GEM/scripts/lib/convert-agent.awk"
KIT="$PWD/.agents/plugins/project-kit"
STATE="$KIT/ecc-state.json"
MCP="$KIT/mcp_config.json"

DRY=0; [[ "${1:-}" == "-n" ]] && { DRY=1; shift; }
MODE="${1:-}"; shift || true

die() { echo "Lỗi: $*" >&2; exit 1; }
split() { tr ',' '\n' <<<"$1" | sed '/^$/d'; }
valid() { [[ "$1" =~ ^[a-z0-9][a-z0-9_-]*$ ]] || die "tên không hợp lệ: $1"; }
command -v jq >/dev/null || die "thiếu jq"
here="$(pwd -P)"; home="$(cd "$HOME" && pwd -P)"; gem="$(cd "$GEM" 2>/dev/null && pwd -P || echo "$GEM")"
case "$here/" in   # so đường dẫn thật: trên macOS /var, /tmp là symlink tới /private/…
  "$home/"|"$gem/"*) die "đang đứng ở \$HOME hoặc ~/.gemini; hãy cd vào thư mục project" ;;
esac

state() { [[ -f "$STATE" ]] && cat "$STATE" || echo '{"skills":[],"agents":[]}'; }
save_state() { # jq-filter
  (( DRY == 1 )) && return 0
  state | jq "$1" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
}
ensure_kit() { # tạo plugin.json nếu chưa có
  (( DRY == 1 )) && return 0
  mkdir -p "$KIT"
  [[ -f "$KIT/plugin.json" ]] || jq -n '{name: "project-kit", displayName: "Project kit", version: "1.0.0",
    description: "Skill, subagent và MCP riêng của project này, do /setup-agy-project cài"}' > "$KIT/plugin.json"
}

enabled_plugin() { # thư mục plugin → 0 nếu đang bật (không có mục trong config.json = bật)
  ! jq -e --arg n "$(basename "$1")" '.plugins[$n].enabled == false' "$GEM/config/config.json" >/dev/null 2>&1
}
global_owner() { # skills|agents tên → in nơi đã có ở scope global, hoặc không in gì
  local kind="$1" n="$2" d
  if [[ "$kind" == skills ]]; then
    [[ -f "$GEM/config/skills/$n/SKILL.md" ]] && { echo "config/skills"; return; }
    for d in "$GEM"/config/plugins/*/; do
      [[ -f "$d/skills/$n/SKILL.md" ]] && enabled_plugin "$d" && { echo "plugin $(basename "$d")"; return; }
    done
  else
    for d in "$GEM"/config/plugins/*/; do
      [[ -f "$d/agents/$n.md" ]] && enabled_plugin "$d" && { echo "plugin $(basename "$d")"; return; }
    done
  fi
  return 0
}

case "$MODE" in
  status)
    [[ -d "$KIT" ]] || { echo "Project chưa có .agents/plugins/project-kit."; exit 0; }
    state | jq -r '"ECC commit: \(.commit // "-")\nskills: \(.skills | join(", "))\nagents: \(.agents | join(", "))"'
    echo "mcp: $( [[ -f "$MCP" ]] && jq -r '.mcpServers // {} | keys | join(", ")' "$MCP")"
    exit 0 ;;

  remove)
    SKILLS=""; AGENTS=""; MCPS=""
    while (( $# )); do
      case "$1" in
        --skills) SKILLS="${2:-}"; shift 2 ;;
        --agents) AGENTS="${2:-}"; shift 2 ;;
        --mcp) MCPS="${2:-}"; shift 2 ;;
        *) die "tham số lạ: $1" ;;
      esac
    done
    for s in $(split "$SKILLS"); do
      valid "$s"; echo "  - skill $s"; (( DRY == 1 )) || rm -rf "$KIT/skills/$s"
      save_state "(.skills -= [\"$s\"])"
    done
    for a in $(split "$AGENTS"); do
      valid "$a"; echo "  - agent $a"; (( DRY == 1 )) || rm -f "$KIT/agents/$a.md"
      save_state "(.agents -= [\"$a\"])"
    done
    for m in $(split "$MCPS"); do
      valid "$m"; echo "  - mcp $m"
      if (( DRY == 0 )) && [[ -f "$MCP" ]]; then
        jq --arg n "$m" 'del(.mcpServers[$n])' "$MCP" > "$MCP.tmp" && mv "$MCP.tmp" "$MCP"
      fi
    done
    exit 0 ;;

  mcp-add)
    name="${1:-}"; shift || true
    valid "$name"
    if [[ "${1:-}" == "--" ]]; then
      shift; (( $# )) || die "thiếu lệnh sau --"
      entry=$(jq -n --arg c "$1" '$ARGS.positional as $a | {command: $c, args: $a[1:]}' --args "$@")
    elif [[ "${1:-}" =~ ^https?:// ]]; then
      entry=$(jq -n --arg u "$1" '{url: $u}')
    else
      die "dùng: mcp-add <tên> <url> hoặc mcp-add <tên> -- <lệnh> [đối số…]"
    fi
    if [[ -f "$MCP" ]] && jq -e --arg n "$name" '.mcpServers[$n]' "$MCP" >/dev/null; then
      echo "  = mcp $name (đã có, bỏ qua)"; exit 0
    fi
    echo "  + mcp $name $(jq -c . <<<"$entry")"
    (( DRY == 1 )) && { echo "Chạy thử: chưa ghi gì."; exit 0; }
    ensure_kit
    [[ -f "$MCP" ]] || echo '{"mcpServers":{}}' > "$MCP"
    jq --arg n "$name" --argjson e "$entry" '.mcpServers[$n] = $e' "$MCP" > "$MCP.tmp" && mv "$MCP.tmp" "$MCP"
    echo "Xong. agy đặt tên tool của MCP này là project-kit_$name; lần đầu dùng sẽ hỏi quyền."
    exit 0 ;;

  add) ;;
  *) echo "Dùng: agy-project.sh [-n] add|remove|mcp-add|status …  (xem đầu file)" >&2; exit 2 ;;
esac

# ─── add ────────────────────────────────────────────────────────────
SKILLS=""; AGENTS=""
while (( $# )); do
  case "$1" in
    --skills) SKILLS="${2:-}"; shift 2 ;;
    --agents) AGENTS="${2:-}"; shift 2 ;;
    *) die "tham số lạ: $1" ;;
  esac
done
[[ -n "$SKILLS$AGENTS" ]] || die "không có gì để thêm"
for x in $(split "$SKILLS") $(split "$AGENTS"); do valid "$x"; done
[[ -f "$CONVERT" ]] || die "không thấy $CONVERT (cần antigravity-harness)"
# Terminal sandbox của agy chặn đọc ~/.gemini: khi đó không biết gì đã có ở global và sẽ cài trùng
ls "$GEM/config/plugins" >/dev/null 2>&1 \
  || die "không đọc được $GEM/config/plugins (đang chạy trong sandbox?): chạy lại ngoài sandbox"

TMP="$(mktemp -d -t ecc-XXXXXX)"; trap 'rm -rf "$TMP"' EXIT
if [[ -n "${ECC_SRC:-}" ]]; then
  SRC="$ECC_SRC"; SHA="$(git -C "$SRC" rev-parse HEAD 2>/dev/null || echo local)"
else
  command -v git >/dev/null || die "thiếu git"
  SRC="$TMP/ECC"
  if [[ -n "${ECC_REF:-}" ]]; then
    git clone -q "$REPO" "$SRC" && git -C "$SRC" checkout -q "$ECC_REF"
  else
    git clone -q --depth 1 "$REPO" "$SRC"
  fi
  SHA="$(git -C "$SRC" rev-parse HEAD)"
fi
echo "ECC $SHA"

bad=0
for s in $(split "$SKILLS"); do [[ -f "$SRC/skills/$s/SKILL.md" ]] || { echo "Không có skill: $s" >&2; bad=1; }; done
for a in $(split "$AGENTS"); do [[ -f "$SRC/agents/$a.md" ]] || { echo "Không có agent: $a" >&2; bad=1; }; done
(( bad == 0 )) || die "sửa tên rồi chạy lại; không ghi gì cả"

ensure_kit
for s in $(split "$SKILLS"); do
  own=$(global_owner skills "$s")
  if [[ -n "$own" ]]; then echo "  = skill $s (đã có ở $own, bỏ qua)"; continue; fi
  echo "  + skill $s"
  (( DRY == 1 )) && continue
  mkdir -p "$KIT/skills"; rm -rf "$KIT/skills/$s"; cp -R "$SRC/skills/$s" "$KIT/skills/$s"
  save_state "(.skills |= (. + [\"$s\"] | unique))"
done
for a in $(split "$AGENTS"); do
  own=$(global_owner agents "$a")
  if [[ -n "$own" ]]; then echo "  = agent $a (đã có ở $own, bỏ qua)"; continue; fi
  echo "  + agent $a"
  (( DRY == 1 )) && continue
  mkdir -p "$KIT/agents"
  dropped=$(awk -f "$CONVERT" "$SRC/agents/$a.md" 2>&1 >"$KIT/agents/$a.md" | tr '\n' ' ')
  [[ -n "$dropped" ]] && echo "    bỏ tool không có trong Antigravity: $dropped"
  save_state "(.agents |= (. + [\"$a\"] | unique))"
done

if (( DRY == 0 )); then
  save_state ".commit = \"$SHA\" | .source = \"$REPO\""
  cp "$SRC/LICENSE" "$KIT/ECC-LICENSE"   # điều kiện của giấy phép MIT
  echo "Xong. Mở phiên agy mới (hoặc /skills reload) để nạp."
else
  echo "Chạy thử: chưa ghi gì."
fi
