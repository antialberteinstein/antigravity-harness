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
notignored() { ! git -C "$REPO" check-ignore -q "$1"; }   # mỗi lần một file: -q chỉ nhận một đường dẫn

# ── Máy giả: HOME riêng, harness đã nằm ở ~/.gemini ─────────────────
H="$TMP/home"; G="$H/.gemini"; B="$TMP/bin"; LOG="$TMP/calls"
mkdir -p "$G/config/plugins" "$G/antigravity-cli" "$H/Downloads" "$B"
cp -R "$REPO/scripts" "$REPO/GEMINI.md" "$REPO/agy-settings.json" "$G/"
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
  "plugin list")
    cat "\$G/plist.json" 2>/dev/null || echo '[]' ;;
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
  "permissions": { "allow": ["command(make test)"], "deny": ["command(rm -rf)", "read_file(.env)"] } }
JSON
out=$(run --os darwin --only settings)
check "settings: giữ model và trustedWorkspaces"      jqt '.model == "Gemini 3.8 Flash (Medium)" and .trustedWorkspaces == ["/private/proj"]' "$S"
check "settings: giá trị harness thắng"               jqt '.colorScheme == "tokyo night" and .statusLine.command == "bash ~/.gemini/statusline.sh"' "$S"
check "settings: giữ quy tắc allow của người dùng"     jqt '.permissions.allow == ["command(make test)", "mcp(context7/*)"]' "$S"
check "settings: thêm quy tắc ask của harness"         jqt '.permissions.ask | index("command(git push)")' "$S"
check "settings: deny không bị lặp"                    jqt '[.permissions.deny[] | select(. == "command(rm -rf)")] | length == 1' "$S"
check "settings: thay @HOME@ bằng HOME"                jqt ".permissions.deny | index(\"read_file($H/.ssh)\")" "$S"
check "settings: không có quy tắc đường dẫn tương đối (sandbox từ chối)" \
  jqt '[.permissions[][] | select(test("^(read_file|write_file)\\([^/@]"))] | length == 0' "$S"
check "settings: gỡ quy tắc trong REMOVE_PERMISSIONS"  jqt '.permissions.deny | index("read_file(.env)") | not' "$S"
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
cp "$S" "$TMP/s.json"; jq --arg h "$H" '.trustedWorkspaces = [$h, "\($h)/work/proj"]' "$TMP/s.json" > "$S"
out=$(run --os fedora --only validate)
check "validate: cảnh báo tin cả thư mục HOME"        has "$out" "trustedWorkspaces có cả thư mục HOME"
check "validate: không cảnh báo project con của HOME" hasnt "$out" "trustedWorkspaces có cả thư mục HOME ($H/work"
cp "$TMP/s.json" "$S"
out=$(run --os fedora --only validate)
check "validate: báo thiếu statusline.sh"             has "$out" "thiếu ~/.gemini/statusline.sh"
check "validate: thấy notify.sh của hook"             has "$out" "✓ ~/.gemini/scripts/notify.sh"
check "validate: GEMINI.md trong giới hạn"            has "$out" "✓ GEMINI.md"
check "validate: cảnh báo hooks.json kiểu Claude"     has "$out" "kiểu Claude Code (agy không chạy đúng): claude-style"
check "validate: bỏ qua plugin đã tắt"                hasnt "$out" "off-style"
mkdir -p "$G/config/skills/foo" "$G/config/skills/solo"; touch "$G/config/skills/foo/SKILL.md" "$G/config/skills/solo/SKILL.md"
echo '[{"name":"bar","enabled":true,"skills":["foo"]},{"name":"off","enabled":false,"skills":["solo"]}]' > "$G/plist.json"
out=$(run --os fedora --only validate)
check "validate: skill lẻ trùng plugin đang bật"      has "$out" "skill foo ở ~/.gemini/config/skills trùng với plugin bar"
check "validate: bỏ qua plugin đã tắt khi xét trùng"  hasnt "$out" "skill solo"
rm -rf "$G/config/skills" "$G/plist.json"
cp "$G/GEMINI.md" "$TMP/gemini.md"; printf '\n@[x](missing-rules.md)\n' >> "$G/GEMINI.md"
out=$(run --os fedora --only validate)
check "validate: include của GEMINI.md bị thiếu"      has "$out" "include tới file không có: missing-rules.md"
cp "$TMP/gemini.md" "$G/GEMINI.md"
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

# ── /setup-agy-project: agy-project.sh với ECC giả ───────────────────
AP="$REPO/config/skills/setup-agy-project/scripts/agy-project.sh"
mkdir -p "$E/skills/fastapi-patterns"; printf -- '---\nname: fastapi-patterns\ndescription: d\n---\n' > "$E/skills/fastapi-patterns/SKILL.md"
printf -- '---\nname: database-reviewer\ndescription: d\ntools: Read, Grep, Bash\nmodel: sonnet\n---\nbody\n' > "$E/agents/database-reviewer.md"
PJ="$H/work/proj"; mkdir -p "$PJ"; K="$PJ/.agents/plugins/project-kit"
ap() { (cd "${APDIR:-$PJ}" && env -i HOME="$H" PATH="$B:/usr/bin:/bin" ECC_SRC="$E" bash "$AP" "$@" 2>&1); }
out=$(ap -n add --skills fastapi-patterns --agents database-reviewer)
check "agy-project -n: không ghi gì"                 [ ! -e "$PJ/.agents" ]
check "agy-project -n: in thứ sẽ thêm"               has "$out" "+ skill fastapi-patterns"
out=$(ap add --skills fastapi-patterns,python-testing --agents database-reviewer,security-reviewer)
check "agy-project: chép skill vào project-kit"      [ -f "$K/skills/fastapi-patterns/SKILL.md" ]
check "agy-project: bỏ qua skill đã có ở global"     has "$out" "= skill python-testing (đã có ở plugin ecc-selected"
check "agy-project: bỏ qua agent đã có ở global"     has "$out" "= agent security-reviewer (đã có ở plugin ecc-selected"
check "agy-project: không chép skill đã có"          [ ! -e "$K/skills/python-testing" ]
check "agy-project: agent thành subagent của agy"     grep -qxF 'tools: [read_file, run_command, manage_task]' "$K/agents/database-reviewer.md"
check "agy-project: tạo plugin.json"                 jqt '.name == "project-kit"' "$K/plugin.json"
check "agy-project: ghi trạng thái"                  jqt '.skills == ["fastapi-patterns"] and .agents == ["database-reviewer"]' "$K/ecc-state.json"
check "agy-project: chép giấy phép ECC"              [ -f "$K/ECC-LICENSE" ]
APDIR="$H/work/other"; mkdir -p "$APDIR"; out=$(ap add --skills no-such-skill); rc=$?
check "agy-project: tên sai thì dừng, không ghi gì"   [ "$rc" -ne 0 -a ! -e "$APDIR/.agents" ]
out=$(ap add --skills 'Bad;name'); rc=$?; unset APDIR
check "agy-project: từ chối tên không hợp lệ"        [ "$rc" -ne 0 ]
out=$(ap mcp-add hf https://huggingface.co/mcp)
check "agy-project: mcp-add HTTP"                    jqt '.mcpServers.hf == {"url": "https://huggingface.co/mcp"}' "$K/mcp_config.json"
out=$(ap mcp-add colab -- uvx git+https://github.com/googlecolab/colab-mcp)
check "agy-project: mcp-add stdio"                   jqt '.mcpServers.colab == {"command": "uvx", "args": ["git+https://github.com/googlecolab/colab-mcp"]}' "$K/mcp_config.json"
out=$(ap mcp-add hf https://example.com/mcp)
check "agy-project: mcp đã có thì bỏ qua"            jqt '.mcpServers.hf.url == "https://huggingface.co/mcp"' "$K/mcp_config.json"
out=$(ap status)
check "agy-project: status liệt kê đủ"               has "$out" "mcp: colab, hf"
out=$(ap remove --skills fastapi-patterns --mcp hf)
check "agy-project: gỡ skill"                        [ ! -e "$K/skills/fastapi-patterns" ]
check "agy-project: gỡ mcp"                          jqt '.mcpServers | has("hf") | not' "$K/mcp_config.json"
check "agy-project: gỡ khỏi trạng thái"              jqt '.skills == []' "$K/ecc-state.json"
chmod 000 "$G/config/plugins"; out=$(ap add --skills fastapi-patterns); rc=$?; chmod 755 "$G/config/plugins"
check "agy-project: không đọc được ~/.gemini/config thì dừng (vd. sandbox)" [ "$rc" -ne 0 ]
check "agy-project: báo rõ lý do sandbox"            has "$out" "sandbox"
out=$(cd "$H" && env -i HOME="$H" PATH="$B:/usr/bin:/bin" bash "$AP" status 2>&1); rc=$?
check "agy-project: từ chối chạy ở \$HOME"            [ "$rc" -ne 0 ]
SA="$REPO/config/skills/setup-agy-project/SKILL.md"
fm="$(awk 'NR==1&&/^---$/{f=1;next} f&&/^---$/{exit} f' "$SA")"
check "setup-agy-project: name khớp thư mục"         grep -qx "name: setup-agy-project" <<<"$fm"
check "setup-agy-project: chỉ chạy khi người dùng gõ" grep -qx "disable-model-invocation: true" <<<"$fm"
for f in "$SA" "$AP" "$REPO/config/skills/setup-agy-project/catalog.md" "$REPO/scripts/lib/convert-agent.awk"; do
  check "không bị .gitignore bỏ qua: ${f#$REPO/}"     notignored "$f"
done

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
out=$(cd / && HOME=/home/u AGY_SL_NERD=0 bash "$SL" <<<'{"cwd":"/home/u/proj"}' | sed $'s/\033\\[[0-9;]*m//g')
check "statusline: rút gọn HOME thành ~"              has "$out" " ~/proj "
out=$(cd / && AGY_SL_NERD=0 bash "$SL" <<<'{"vim":{"mode":"INSERT"},"cycle_mode":"plan"}' | sed $'s/\033\\[[0-9;]*m//g')
check "statusline: chế độ Vim ưu tiên hơn"            has "$out" "INSERT"
out=$(cd / && AGY_SL_NERD=0 bash "$SL" <<<'{"cwd":"/"}' | sed $'s/\033\\[[0-9;]*m//g')
check "statusline: chế độ mặc định hiện Antigravity"  has "$out" " Antigravity "
out=$(env -i PATH=/bin /bin/bash "$SL" <<<"{}")
check "statusline: không có jq vẫn in"                [ "$out" = "Antigravity" ]

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

# ── guard-secrets.sh (hook PreToolUse) ───────────────────────────────
GS="$REPO/scripts/guard-secrets.sh"
gs() { printf '{"toolCall":{"name":"%s","args":{"%s":"%s"}}}' "$1" "$2" "$3" | env -i PATH="/usr/bin:/bin" bash "$GS"; }
out=$(gs read_file Path /w/proj/.env)
check "guard: chặn đọc .env"                         jq -e '.decision == "deny"' <<<"$out"
out=$(gs write_file Path /w/proj/config/.env.production)
check "guard: chặn ghi .env.production"              jq -e '.decision == "deny"' <<<"$out"
out=$(gs edit_file TargetFile .env.local)
check "guard: nhận khoá tham số khác (TargetFile)"   jq -e '.decision == "deny"' <<<"$out"
out=$(gs read_file Path /w/proj/.env.example)
check "guard: cho đọc .env.example"                  [ -z "$out" ]
out=$(gs read_file Path /w/proj/src/env.ts)
check "guard: file thường thì im lặng (luồng quyền bình thường)" [ -z "$out" ]
out=$(gs read_file Path /w/proj/.envrc)
check "guard: .envrc không bị nhầm là .env"          [ -z "$out" ]
out=$(printf 'không phải json' | env -i PATH="/usr/bin:/bin" bash "$GS"); rc=$?
check "guard: input hỏng thì im lặng, exit 0"        [ -z "$out" -a "$rc" -eq 0 ]
check "hooks.json gắn guard-secrets vào PreToolUse"  jqt '.["harness-guard-secrets"].PreToolUse[0].hooks[0].command | test("guard-secrets.sh")' "$REPO/config/hooks.json"

# ── Skill /harness-check của harness ─────────────────────────────────
HC="$REPO/config/skills/harness-check/SKILL.md"
fm="$(awk 'NR==1&&/^---$/{f=1;next} f&&/^---$/{exit} f' "$HC" 2>/dev/null)"
check "harness-check: name khớp thư mục"             grep -qx "name: harness-check" <<<"$fm"
check "harness-check: chỉ chạy khi người dùng gõ"    grep -qx "disable-model-invocation: true" <<<"$fm"
check "harness-check: không bị .gitignore bỏ qua"    notignored "$HC"
check "harness-check: gọi setup.sh -n và agy-sync -n" grep -qF 'agy-sync -n' "$HC"

echo "---"; echo "$pass passed, $failn failed"
[ "$failn" -eq 0 ]
