# convert-agent.awk — chuyển agent Claude Code (ECC) sang subagent Antigravity.
# Dùng:  awk -f convert-agent.awk agent.md > out.md   (tool không đổi được in ra stderr)
# Theo skill migrate-agent-settings có sẵn trong agy, đã kiểm chứng bằng subagent thật:
#   tools: Read/Glob/Grep → read_file, Edit/MultiEdit → edit_file, Write → write_file,
#          Bash → run_command + manage_task, WebSearch/WebFetch → search_web; thiếu tools = mọi tool
#   bỏ model, color; thêm subagent: true, mainAgent: false
function add(t) { if (!(t in seen)) { seen[t] = 1; out = out (out == "" ? "" : ", ") t } }
function map(t) {
  gsub(/[][" '\t]/, "", t)
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
