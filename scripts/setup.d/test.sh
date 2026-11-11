#!/usr/bin/env bash
# setup.d/test.sh — test offline cho setup.sh, agy-sync, build-ecc-plugin.sh, statusline.sh, notify.sh.
# Chạy: bash ~/.gemini/scripts/setup.d/test.sh
# Dùng HOME giả và lệnh giả (agy, git, uv…), không đọc hay sửa ~/.gemini thật, không cài gì thật.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass=0; failn=0
check() { local name="$1"; shift; if "$@"; then echo "ok   $name"; pass=$((pass+1)); else echo "FAIL $name"; failn=$((failn+1)); fi; }
has()   { grep -qF -- "$2" <<<"$1"; }
hasnt() { ! grep -qF -- "$2" <<<"$1"; }
jqt()   { jq -e "$1" "$2" >/dev/null 2>&1; }   # biểu thức jq đúng trên file
nogrep() { ! grep -qE -- "$1" "$2"; }

# ── Máy giả: HOME riêng, harness đã nằm ở ~/.gemini ─────────────────
H="$TMP/home"; G="$H/.gemini"; B="$TMP/bin"; LOG="$TMP/calls"
mkdir -p "$G/config/plugins" "$G/antigravity-cli" "$H/Downloads" "$B"
cp -R "$REPO/scripts" "$REPO/GEMINI.md" "$REPO/GEMINI.self.md" "$REPO/agy-settings.json" "$G/"
cp -R "$REPO/config/hooks.json" "$G/config/"
rm -f "$G/scripts/setup.d/config.local.sh"
SETUP="$G/scripts/setup.sh"

stub() { printf '#!/bin/bash\necho "%s $*" >> "%s"\n%s\n' "$1" "$LOG" "${2:-exit 0}" > "$B/$1"; chmod +x "$B/$1"; }
for c in git uv brew npx; do stub "$c"; done
ln -s "$(command -v jq)" "$B/jq"
stub gh "[ \"\$1 \$2\" = 'auth status' ] && { [ -f '$H/gh-ok' ] && exit 0 || exit 1; }; [ \"\$1 \$2\" = 'auth login' ] && touch '$H/gh-ok'; exit 0"
# agy giả: mcp add, plugin install/disable ghi file giống agy thật
cat > "$B/agy" <<EOF
#!/bin/bash
echo "agy \$*" >> "$LOG"
G="\$HOME/.gemini"
case "\$1 \$2" in
  "mcp add")
    f="\$G/config/mcp_config.json"; [ -f "\$f" ] || echo '{}' > "\$f"
    jq --arg n "\$3" '.mcpServers[\$n] = {command: "npx"}' "\$f" > "\$f.t" && mv "\$f.t" "\$f" ;;
  "plugin install")
    n="\${3##*/}"; n="\${n%.git}"; mkdir -p "\$G/config/plugins/\$n"; echo "{\"name\":\"\$n\"}" > "\$G/config/plugins/\$n/plugin.json" ;;
  "plugin disable")
    f="\$G/config/config.json"; [ -f "\$f" ] || echo '{}' > "\$f"
    jq --arg n "\$3" '.plugins[\$n].enabled = false' "\$f" > "\$f.t" && mv "\$f.t" "\$f" ;;
esac
exit 0
EOF
chmod +x "$B/agy"
run() { env -i HOME="$H" SHELL=/bin/zsh TERM=dumb PATH="$B:/usr/bin:/bin" SETUP_OS_RELEASE="${SETUP_OS_RELEASE:-}" bash "$SETUP" "$@" 2>&1 </dev/null; }
sync() { env -i HOME="$H" TERM=dumb PATH="$B:/usr/bin:/bin" ${ECC_SRC:+ECC_SRC="$ECC_SRC"} bash "$G/scripts/agy-sync" "$@" 2>&1 </dev/null; }
rel() { printf 'ID=%s\nID_LIKE="%s"\n' "$1" "$2" > "$TMP/os-release"; }

# ── Nhận diện OS ─────────────────────────────────────────────────────
out=$(run --list --os darwin)
check "--os darwin dùng hồ sơ macOS"                 has "$out" "OS: macOS"
check "--list liệt kê đủ module theo thứ tự"         has "$out" "Module: deps tools mcp perms link settings validate sync"
if [[ "$(uname -s)" == Linux ]]; then
  rel fedora "";            out=$(SETUP_OS_RELEASE="$TMP/os-release" run --list)
  check "nhận Fedora từ os-release"                  has "$out" "OS: Fedora"
  rel fedora-asahi-remix "fedora"; out=$(SETUP_OS_RELEASE="$TMP/os-release" run --list)
  check "Fedora Asahi: rơi về ID_LIKE=fedora"        has "$out" "OS: Fedora"
fi
out=$(run --list --os haiku)
check "--os lạ: dự phòng Linux chung + ghi chú"      has "$out" "dự phòng cho \"haiku\""

# ── Chạy thử không ghi gì ────────────────────────────────────────────
snap() { (cd "$H" && find . -type f -o -type l | sort | xargs cat 2>/dev/null | cksum); }
before=$(snap)
: > "$LOG"; out=$(run -n --os fedora --install --include-login --add-path --sync)
after=$(snap)
check "-n: không đổi file nào"                       [ "$before" = "$after" ]
check "-n: không gọi lệnh cài"                        hasnt "$(cat "$LOG")" "tool install"
check "-n: không gọi agy mcp add"                     hasnt "$(cat "$LOG")" "agy mcp add"
check "-n: in lệnh sẽ chạy"                           has "$out" "→ uv tool install huggingface_hub[cli]"
check "-n: báo sẽ cập nhật settings.json"             has "$out" "→ cập nhật ~/.gemini/antigravity-cli/settings.json"

# ── Module deps, tools ───────────────────────────────────────────────
out=$(run --os fedora --only deps)
check "deps: thấy agy"                                has "$out" "✓ agy"
out=$(run --os fedora --only tools)
check "fedora: báo thiếu kaggle"                      has "$out" "thiếu kaggle"
check "gh chưa đăng nhập thì cảnh báo"                has "$out" "gh chưa đăng nhập"
: > "$LOG"; out=$(run --os fedora --only tools --install)
check "--install: kaggle cài bằng uv tool"            has "$(cat "$LOG")" "uv tool install kaggle"
rm "$B/uv"; : > "$LOG"; out=$(run --os fedora --only tools --install)
check "fedora: uv thiếu thì in lệnh dnf, không sudo"  has "$out" "sudo dnf install uv"
check "fedora: không tự chạy sudo"                    hasnt "$(cat "$LOG")" "sudo"
stub uv

# ── MCP ──────────────────────────────────────────────────────────────
: > "$LOG"; out=$(run --os fedora --only mcp)
check "mcp: thêm context7 bằng agy mcp add"           has "$(cat "$LOG")" "agy mcp add context7 -- npx -y @upstash/context7-mcp"
: > "$LOG"; out=$(run --os fedora --only mcp)
check "mcp: chạy lại không thêm trùng"                hasnt "$(cat "$LOG")" "mcp add"

# ── Link ─────────────────────────────────────────────────────────────
mkdir -p "$H/.local/bin" "$H/.claude/scripts"; echo '#!/bin/bash' > "$H/.claude/scripts/show"
ln -s "$H/.claude/scripts/show" "$H/.local/bin/show"
out=$(run --os darwin --only link --add-path)
check "link: tạo symlink agy-sync"                    [ "$(readlink "$H/.local/bin/agy-sync")" = "$G/scripts/agy-sync" ]
check "link: giữ show của harness khác"               [ "$(readlink "$H/.local/bin/show")" = "$H/.claude/scripts/show" ]
check "link: thêm PATH vào ~/.zshrc"                  grep -qF '# antigravity harness' "$H/.zshrc"

# ── Trộn settings.json ───────────────────────────────────────────────
S="$G/antigravity-cli/settings.json"
cat > "$S" <<JSON
{ "colorScheme": "dark", "model": "Gemini 3.8 Flash (Medium)", "trustedWorkspaces": ["/private/proj"],
  "permissions": { "allow": ["command(make test)"], "deny": ["command(rm -rf)"] } }
JSON
out=$(run --os darwin --only settings)
check "settings: giữ model và trustedWorkspaces"      jqt '.model == "Gemini 3.8 Flash (Medium)" and .trustedWorkspaces == ["/private/proj"]' "$S"
check "settings: giá trị harness thắng"               jqt '.colorScheme == "tokyo night" and .statusLine.command == "bash ~/.gemini/statusline.sh"' "$S"
check "settings: giữ quy tắc allow của người dùng"     jqt '.permissions.allow == ["command(make test)"]' "$S"
check "settings: thêm quy tắc ask của harness"         jqt '.permissions.ask | index("command(git push)")' "$S"
check "settings: deny không bị lặp"                    jqt '[.permissions.deny[] | select(. == "command(rm -rf)")] | length == 1' "$S"
check "settings: thay @HOME@ bằng HOME"                jqt ".permissions.deny | index(\"read_file($H/.ssh)\")" "$S"
check "settings: sao lưu bản cũ"                       ls "$S".bak-* >/dev/null 2>&1
out=$(run --os darwin --only settings)
check "settings: chạy lại thì đã khớp"                 has "$out" "đã khớp"
echo '{ broken' > "$S"; out=$(run --os darwin --only settings); rc=$?
check "settings: JSON hỏng thì báo lỗi"                [ "$rc" -ne 0 ]
check "settings: JSON hỏng thì không đụng vào"         [ "$(cat "$S")" = '{ broken' ]
rm -f "$S" "$S".bak-*; out=$(run --os darwin --only settings)
check "settings: chưa có file thì tạo mới"             jqt '.agentMode == "auto"' "$S"

# ── Validate ─────────────────────────────────────────────────────────
mkdir -p "$G/config/plugins/claude-style" "$G/config/plugins/off-style"
echo '{"hooks":{"PreToolUse":[]}}' > "$G/config/plugins/claude-style/hooks.json"
echo '{"hooks":{"Stop":[]}}' > "$G/config/plugins/off-style/hooks.json"
echo '{"plugins":{"off-style":{"enabled":false}}}' > "$G/config/config.json"
out=$(run --os fedora --only validate)
check "validate: báo thiếu statusline.sh"             has "$out" "thiếu ~/.gemini/statusline.sh"
check "validate: thấy notify.sh của hook"             has "$out" "✓ ~/.gemini/scripts/notify.sh"
check "validate: GEMINI.md trong giới hạn"            has "$out" "✓ GEMINI.md"
check "validate: cảnh báo hooks.json kiểu Claude"     has "$out" "kiểu Claude Code (agy không chạy đúng): claude-style"
check "validate: bỏ qua plugin đã tắt"                hasnt "$out" "off-style"
mv "$G/GEMINI.self.md" "$TMP/self.md"; out=$(run --os fedora --only validate)
check "validate: include của GEMINI.md bị thiếu"      has "$out" "include tới file không có: GEMINI.self.md"
mv "$TMP/self.md" "$G/GEMINI.self.md"
rm -rf "$G/config/plugins/claude-style" "$G/config/plugins/off-style" "$G/config/config.json"
out=$(run --os fedora --only nosuch); rc=$?
check "--only module không tồn tại thì lỗi"           [ "$rc" -ne 0 ]

# ── agy-sync ─────────────────────────────────────────────────────────
mkdir -p "$G/config/plugins/ecc"
before=$(snap); : > "$LOG"; out=$(sync -n --skip-ecc)
check "agy-sync -n: không đổi file nào"               [ "$before" = "$(snap)" ]
check "agy-sync -n: không gọi agy"                    hasnt "$(cat "$LOG")" "agy plugin"
check "agy-sync -n: in lệnh cài superpowers"          has "$out" "→ agy plugin install https://github.com/obra/superpowers"
: > "$LOG"; out=$(sync --skip-ecc); rc=$?
check "agy-sync: chạy thành công"                     [ "$rc" -eq 0 ]
check "agy-sync: cài 3 plugin"                        [ "$(grep -c 'agy plugin install' "$LOG")" -eq 3 ]
check "agy-sync: thêm skills.json cho kessie-skills"  jqt '.entries[0].path == "."' "$G/config/plugins/kessie-skills/skills.json"
check "agy-sync: không thêm skills.json cho plugin khác" [ ! -f "$G/config/plugins/superpowers/skills.json" ]
check "agy-sync: tắt ecc"                             jqt '.plugins.ecc.enabled == false' "$G/config/config.json"
: > "$LOG"; out=$(sync --skip-ecc)
check "agy-sync: chạy lại không cài gì"               hasnt "$(cat "$LOG")" "agy plugin"
check "agy-sync: chạy lại báo đã đồng bộ"             has "$out" "không có gì để cài"
: > "$LOG"; out=$(sync --skip-ecc --update)
check "agy-sync --update: cài lại từ git"             [ "$(grep -c 'agy plugin install' "$LOG")" -eq 3 ]

# ── build-ecc-plugin.sh với ECC giả ──────────────────────────────────
E="$TMP/ECC"; mkdir -p "$E/agents" "$E/skills"; echo "MIT" > "$E/LICENSE"
for s in $(sed -n '/^SKILLS=(/,/^)/p' "$REPO/scripts/build-ecc-plugin.sh" | grep -v '^ *#' | grep -oE '[a-z][a-z0-9-]+' | grep -v SKILLS); do
  mkdir -p "$E/skills/$s"; printf -- '---\nname: %s\ndescription: d\n---\n' "$s" > "$E/skills/$s/SKILL.md"
done
for a in $(sed -n '/^AGENTS=(/,/^)/p' "$REPO/scripts/build-ecc-plugin.sh" | grep -oE '[a-z][a-z0-9-]+' | grep -v AGENTS); do
  printf -- '---\nname: %s\ndescription: d\ntools: Read, Grep, Glob, Bash\nmodel: sonnet\n---\nbody\n' "$a" > "$E/agents/$a.md"
done
printf -- '---\nname: python-reviewer\ndescription: d\nmodel: sonnet\ntools: ["Read", "Write", "Task"]\ncolor: red\n---\nbody\n' > "$E/agents/python-reviewer.md"
printf -- '---\nname: cpp-reviewer\ndescription: d\n---\nbody\n' > "$E/agents/cpp-reviewer.md"
ECC_SRC="$E"; out=$(sync); unset ECC_SRC
P="$G/config/plugins/ecc-selected"
check "ecc: dựng plugin ecc-selected"                 jqt '.name == "ecc-selected"' "$P/plugin.json"
check "ecc: chép đủ 17 skill"                         [ "$(ls "$P/skills" | wc -l | tr -d ' ')" -eq 17 ]
check "ecc: chép đủ 13 agent"                         [ "$(ls "$P/agents" | wc -l | tr -d ' ')" -eq 13 ]
check "ecc: đổi tool sang tên của Antigravity"        grep -qxF 'tools: [read_file, run_command, manage_task]' "$P/agents/security-reviewer.md"
check "ecc: agent là subagent"                        grep -qxF 'subagent: true' "$P/agents/security-reviewer.md"
check "ecc: bỏ model và color"                        nogrep "^(model|color):" "$P/agents/python-reviewer.md"
check "ecc: tools dạng mảng JSON"                     grep -qxF 'tools: [read_file, write_file]' "$P/agents/python-reviewer.md"
check "ecc: báo tool không đổi được"                  has "$out" "python-reviewer: bỏ tool không có trong Antigravity: Task"
check "ecc: thiếu tools thì được mọi tool"            grep -qF 'tools: [read_file, edit_file, write_file, run_command, manage_task, search_web]' "$P/agents/cpp-reviewer.md"
check "ecc: giữ thân agent"                           [ "$(tail -1 "$P/agents/cpp-reviewer.md")" = "body" ]
check "ecc: ghi LICENSE và SOURCE"                    [ -f "$P/LICENSE" -a -f "$P/SOURCE" ]
rm "$E/agents/mle-reviewer.md"
out=$(env -i HOME="$H" PATH="$B:/usr/bin:/bin" ECC_SRC="$E" bash "$G/scripts/build-ecc-plugin.sh" 2>&1); rc=$?
check "ecc: thiếu agent thì dừng"                     [ "$rc" -ne 0 ]
check "ecc: thiếu agent thì giữ plugin cũ"            [ -f "$P/agents/mle-reviewer.md" ]

# ── statusline.sh ────────────────────────────────────────────────────
SL="$REPO/statusline.sh"
payload='{"cwd":"/","workspace":{"current_dir":"/"},"model":{"display_name":"Gemini 3.8 Flash (Medium)"},
  "context_window":{"used_percentage":42.7},"quota":{"gemini-weekly":{"remaining_fraction":0.77},"other":{"remaining_fraction":0.1,"disabled":true}},
  "cycle_mode":"plan","terminal_width":200}'
out=$(cd / && AGY_SL_NERD=0 bash "$SL" <<<"$payload" | sed $'s/\033\\[[0-9;]*m//g')
check "statusline: hiện model"                        has "$out" "Gemini 3.8 Flash (Medium)"
check "statusline: hiện chế độ plan"                  has "$out" "PLAN"
check "statusline: ctx 42%"                           has "$out" "▰▰▰▱▱▱ 42%"
check "statusline: quota bỏ nhóm bị tắt"              has "$out" "quota 23%"
out=$(cd / && AGY_SL_NERD=0 bash "$SL" <<<'{"vim":{"mode":"INSERT"},"cycle_mode":"plan"}' | sed $'s/\033\\[[0-9;]*m//g')
check "statusline: chế độ Vim ưu tiên hơn"            has "$out" "INSERT"
out=$(env -i PATH=/bin /bin/bash "$SL" <<<"{}")
check "statusline: không có jq vẫn in"                [ "$out" = "agy" ]

# ── notify.sh ────────────────────────────────────────────────────────
NT="$REPO/scripts/notify.sh"
nrun() { env -i HOME="$H" PATH="$B:/usr/bin:/bin" AGY_NOTIFY_LOG=1 AGY_NOTIFY_SOUND=0 bash "$NT" <<<"$1"; }
for c in osascript terminal-notifier notify-send afplay; do stub "$c"; done   # không bật thông báo thật
: > "$G/notify.log"; : > "$LOG"
out=$(nrun '{"terminationReason":"NO_TOOL_CALL","transcriptPath":"/x/.gemini/antigravity-cli/brain/1/t.jsonl","workspacePaths":["/w/proj"]}')
check "notify: luôn in {} để agent dừng"              [ "$out" = "{}" ]
check "notify: bỏ qua phiên agy"                      grep -qF 'product=cli  skip=agy tự báo' "$G/notify.log"
check "notify: phiên agy không gửi thông báo"         [ ! -s "$LOG" ]
out=$(nrun '{"terminationReason":"USER_CANCELED","transcriptPath":"/x/.gemini/antigravity-ide/brain/1/t.jsonl"}')
check "notify: bỏ qua khi người dùng huỷ"             grep -qF 'skip=huỷ bởi người dùng' "$G/notify.log"
out=$(nrun '{"terminationReason":"NO_TOOL_CALL","transcriptPath":"/x/.gemini/antigravity-ide/brain/1/t.jsonl","workspacePaths":["/w/proj"]}')
check "notify: IDE thì gửi thông báo"                 grep -qE '(terminal-notifier|osascript|notify-send).*Antigravity IDE · proj' "$LOG"
out=$(nrun 'không phải json')
check "notify: input hỏng vẫn in {}"                  [ "$out" = "{}" ]

echo "---"; echo "$pass passed, $failn failed"
[ "$failn" -eq 0 ]
