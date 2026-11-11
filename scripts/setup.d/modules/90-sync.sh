# modules/90-sync.sh — gọi agy-sync (cài plugin + ECC chọn lọc). Chỉ chạy khi có --sync.
step_sync() {
  (( SYNC == 1 )) || return 0
  say "agy-sync"
  if (( nf > 0 )); then note "bỏ qua vì còn lỗi ở trên"; return; fi
  [[ -x "$SCRIPTS/agy-sync" ]] || { fail "không có $(tilde "$SCRIPTS/agy-sync")"; return; }
  if (( DRY == 1 )); then act bash "$SCRIPTS/agy-sync" -n; else act bash "$SCRIPTS/agy-sync"; fi
}
