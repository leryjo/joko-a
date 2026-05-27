#!/usr/bin/env bash
set -u

CODE_DIR="${CODE_DIR:-/joko-app}"
BASE_DIR="${BASE_DIR:-/joko-app/joko-idx}"
NODE_BIN="${NODE_BIN:-$(command -v node || echo node)}"
SCREEN_LOGIN="${SCREEN_LOGIN:-1280x720x24}"
SCREEN_LOOP="${SCREEN_LOOP:-1300x800x24}"
SCREEN_BUAT_LINK="${SCREEN_BUAT_LINK:-1280x720x24}"
REFRESH_SECONDS="${REFRESH_SECONDS:-2}"

LOGIN_FILE="$CODE_DIR/login.js"
LOOP_FILE="$CODE_DIR/loop.js"
BUAT_LINK_FILE="$CODE_DIR/buat_link.js"

LOGIN_LOG="$BASE_DIR/login_log.txt"
LOOP_LOG="$BASE_DIR/loop_log.txt"
BUAT_LINK_LOG="$BASE_DIR/buat_link_log.txt"
BOT_LOG="$BASE_DIR/bot_log.txt"
MAPPING_FILE="$BASE_DIR/mapping_profil.txt"
SCREENSHOT_DIR="$BASE_DIR/screenshots"
PROFILES_DIR="$BASE_DIR/chrome_profiles"
LOOP_STATUS_FILE="$BASE_DIR/loop_status.json"
EMAIL_FILE="$BASE_DIR/email.txt"
EMAILSHARE_FILE="$BASE_DIR/emailshare.txt"

mkdir -p "$BASE_DIR" "$SCREENSHOT_DIR" "$PROFILES_DIR"
touch "$LOGIN_LOG" "$LOOP_LOG" "$BUAT_LINK_LOG" "$BOT_LOG" "$MAPPING_FILE" "$LOOP_STATUS_FILE" "$EMAIL_FILE" "$EMAILSHARE_FILE"

C_RESET='\033[0m'
C_BOLD='\033[1m'
C_DIM='\033[2m'
C_RED='\033[1;31m'
C_GREEN='\033[1;32m'
C_YELLOW='\033[1;33m'
C_BLUE='\033[1;34m'
C_MAGENTA='\033[1;35m'
C_CYAN='\033[1;36m'
C_WHITE='\033[1;37m'

LAST_MSG="Menu aktif. Dashboard auto-refresh hanya untuk realtime VPS/proses."
MENU_MODE="dashboard"

now() { date '+%Y-%m-%d %H:%M:%S'; }
log_line() { printf '[%s] %s\n' "$(now)" "$1" >> "$BOT_LOG"; }
pause_any() { printf "\nTekan tombol apa saja untuk kembali..."; read -rsn1 _; }
clear_screen() { printf '\033c'; }

proc_running() {
  local pattern="$1"
  pgrep -af "$pattern" >/dev/null 2>&1
}

count_proc() {
  local pattern="$1"
  pgrep -af "$pattern" 2>/dev/null | wc -l | tr -d ' '
}

kill_keyword() {
  local pattern="$1"
  pkill -f "$pattern" >/dev/null 2>&1 || true
}

kill_chrome_all() {
  kill_keyword chromedriver
  kill_keyword google-chrome
  kill_keyword chrome
  kill_keyword chromium
  kill_keyword chromium-browser
}

kill_xvfb_runs() {
  kill_keyword xvfb-run
  kill_keyword Xvfb
}

ensure_script() {
  local file="$1"
  local name="$2"
  if [ ! -f "$file" ]; then
    LAST_MSG="${name} tidak ditemukan: $file"
    return 1
  fi
  return 0
}

start_login() {
  ensure_script "$LOGIN_FILE" "login.js" || return
  if proc_running "[l]ogin.js"; then LAST_MSG="Login sudah jalan."; return; fi
  printf '[%s] ===== START login =====\n' "$(now)" >> "$LOGIN_LOG"
  nohup xvfb-run -a --server-args="-screen 0 ${SCREEN_LOGIN}" "$NODE_BIN" "$LOGIN_FILE" >> "$LOGIN_LOG" 2>&1 &
  log_line "START login"
  LAST_MSG="Login started."
}

start_loop() {
  ensure_script "$LOOP_FILE" "loop.js" || return
  if proc_running "[l]oop.js"; then LAST_MSG="Loop sudah jalan."; return; fi
  printf '[%s] ===== START loop =====\n' "$(now)" >> "$LOOP_LOG"
  nohup xvfb-run -a --server-args="-screen 0 ${SCREEN_LOOP}" "$NODE_BIN" "$LOOP_FILE" >> "$LOOP_LOG" 2>&1 &
  log_line "START loop"
  LAST_MSG="Loop started."
}

start_buat_link() {
  ensure_script "$BUAT_LINK_FILE" "buat_link.js" || return
  if proc_running "[b]uat_link.js"; then LAST_MSG="Buat link sudah jalan."; return; fi
  printf '[%s] ===== START buat_link =====\n' "$(now)" >> "$BUAT_LINK_LOG"
  nohup xvfb-run -a --server-args="-screen 0 ${SCREEN_BUAT_LINK}" "$NODE_BIN" "$BUAT_LINK_FILE" >> "$BUAT_LINK_LOG" 2>&1 &
  log_line "START buat_link"
  LAST_MSG="Buat link started."
}

stop_login() {
  kill_keyword "[l]ogin.js"
  kill_chrome_all
  kill_xvfb_runs
  printf '[%s] ===== STOP login =====\n' "$(now)" >> "$LOGIN_LOG"
  log_line "STOP login + CLOSE chrome"
  LAST_MSG="Login stopped + Chrome closed."
}

stop_loop() {
  kill_keyword "[l]oop.js"
  kill_chrome_all
  kill_xvfb_runs
  printf '[%s] ===== STOP loop =====\n' "$(now)" >> "$LOOP_LOG"
  log_line "STOP loop + CLOSE chrome"
  LAST_MSG="Loop stopped + Chrome closed."
}

stop_buat_link() {
  kill_keyword "[b]uat_link.js"
  kill_chrome_all
  kill_xvfb_runs
  printf '[%s] ===== STOP buat_link =====\n' "$(now)" >> "$BUAT_LINK_LOG"
  log_line "STOP buat_link + CLOSE chrome"
  LAST_MSG="Buat link stopped + Chrome closed."
}

stop_all() {
  kill_keyword "[l]ogin.js"
  kill_keyword "[l]oop.js"
  kill_keyword "[b]uat_link.js"
  kill_chrome_all
  kill_xvfb_runs
  printf '[%s] ===== STOP ALL =====\n' "$(now)" >> "$LOGIN_LOG"
  printf '[%s] ===== STOP ALL =====\n' "$(now)" >> "$LOOP_LOG"
  printf '[%s] ===== STOP ALL =====\n' "$(now)" >> "$BUAT_LINK_LOG"
  log_line "STOP ALL + CLOSE chrome"
  LAST_MSG="Stop ALL selesai."
}

kill_all() {
  stop_all
  LAST_MSG="Kill ALL proses selesai."
  log_line "KILL ALL proses"
}

clear_ram_cache() {
  sync || true
  if [ -w /proc/sys/vm/drop_caches ]; then
    echo 3 > /proc/sys/vm/drop_caches && LAST_MSG="Clear RAM cache sukses." || LAST_MSG="Clear RAM cache gagal."
  else
    LAST_MSG="Gagal clear RAM cache: butuh --privileged/root."
  fi
  log_line "CLEAR RAM requested"
}

reset_mapping() {
  : > "$MAPPING_FILE"
  log_line "RESET mapping_profil.txt"
  LAST_MSG="mapping_profil.txt direset."
}

reset_chrome_profiles() {
  stop_all
  rm -rf "$PROFILES_DIR"/* 2>/dev/null || true
  mkdir -p "$PROFILES_DIR"
  log_line "RESET chrome_profiles"
  LAST_MSG="Chrome profiles dihapus dan dibuat ulang."
}

cleanup_root_png() {
  find "$CODE_DIR" -maxdepth 1 -type f -name '*.png' -delete 2>/dev/null || true
  log_line "CLEANUP root png"
  LAST_MSG="PNG di root project dibersihkan."
}

cleanup_logs_json_lock() {
  find "$BASE_DIR" -maxdepth 2 -type f \( -name '*.log' -o -name '*.json' -o -name '*.lock' \) \
    ! -name 'loop_status.json' -delete 2>/dev/null || true
  touch "$BOT_LOG" "$LOGIN_LOG" "$LOOP_LOG" "$BUAT_LINK_LOG" "$LOOP_STATUS_FILE"
  log_line "CLEANUP log/json/lock"
  LAST_MSG="File log/json/lock dibersihkan."
}

delete_chrome_profiles() {
  rm -rf "$PROFILES_DIR" 2>/dev/null || true
  mkdir -p "$PROFILES_DIR"
  log_line "DELETE chrome profiles"
  LAST_MSG="Chrome profiles dihapus."
}

human_uptime() {
  awk '{print int($1)}' /proc/uptime 2>/dev/null | awk '{d=int($1/86400); h=int(($1%86400)/3600); m=int(($1%3600)/60); s=$1%60; if (d>0) printf "%dd %02dh %02dm %02ds", d,h,m,s; else printf "%02dh %02dm %02ds", h,m,s}'
}

sys_snapshot() {
  # Tanpa psutil. Ambil data langsung dari /proc dan df, cocok untuk Docker/IDX minimal.
  local cpu mem_pct mem_used mem_total disk_pct disk_used disk_total load1 load5 load15

  cpu=$(awk '''BEGIN{FS=" "} NR==1{idle1=$5; total1=0; for(i=2;i<=NF;i++) total1+=$i; system("sleep 0.15"); getline < "/proc/stat"; idle2=$5; total2=0; for(i=2;i<=NF;i++) total2+=$i; dt=total2-total1; di=idle2-idle1; if(dt>0) printf "%.1f", (100*(dt-di)/dt); else print "0.0"}''' /proc/stat 2>/dev/null || echo "-")

  mem_total=$(awk '''/MemTotal:/ {printf "%d", $2/1024}''' /proc/meminfo 2>/dev/null || echo "-")
  mem_avail=$(awk '''/MemAvailable:/ {printf "%d", $2/1024}''' /proc/meminfo 2>/dev/null || echo "0")
  if [ "$mem_total" != "-" ] && [ "$mem_total" -gt 0 ] 2>/dev/null; then
    mem_used=$((mem_total-mem_avail))
    mem_pct=$(awk -v u="$mem_used" -v t="$mem_total" '''BEGIN{printf "%.1f", (u*100/t)}''')
  else
    mem_used="-"; mem_pct="-"
  fi

  disk_pct=$(df -P / 2>/dev/null | awk '''NR==2{gsub("%", "", $5); print $5}''' || echo "-")
  disk_used=$(df -P -BG / 2>/dev/null | awk '''NR==2{gsub("G", "", $3); print $3}''' || echo "-")
  disk_total=$(df -P -BG / 2>/dev/null | awk '''NR==2{gsub("G", "", $2); print $2}''' || echo "-")
  read -r load1 load5 load15 _ < /proc/loadavg 2>/dev/null || { load1="-"; load5="-"; load15="-"; }

  printf '{"cpu":"%s","mem_pct":"%s","mem_used_mb":"%s","mem_total_mb":"%s","disk_pct":"%s","disk_used_gb":"%s","disk_total_gb":"%s","load1":"%s","load5":"%s","load15":"%s"}\n' \
    "$cpu" "$mem_pct" "$mem_used" "$mem_total" "$disk_pct" "$disk_used" "$disk_total" "$load1" "$load5" "$load15"
}

count_lines() {
  local file="$1"
  [ -f "$file" ] || { echo 0; return; }
  grep -cve '^\s*$' "$file" 2>/dev/null || echo 0
}

list_joko_files() {
  find "$BASE_DIR" -maxdepth 1 -type f -regextype posix-extended -regex '.*/joko[0-9]+\.txt' 2>/dev/null | sort -V
}

ensure_joko_files() {
  local count="${1:-1}"
  local i
  if [ "$count" -lt 1 ] 2>/dev/null; then count=1; fi
  for ((i=1;i<=count;i++)); do
    touch "$BASE_DIR/joko${i}.txt"
  done
}

joko_file_stats() {
  python3 - "$BASE_DIR" <<'PY'
import os, re, sys, json
base = sys.argv[1]
out = []
for name in sorted(os.listdir(base)):
    m = re.fullmatch(r'joko(\d+)\.txt', name)
    if not m:
        continue
    path = os.path.join(base, name)
    try:
        with open(path, 'r', encoding='utf-8', errors='ignore') as f:
            lines = [ln.strip() for ln in f if ln.strip()]
    except Exception:
        lines = []
    out.append({
        'name': name,
        'index': int(m.group(1)),
        'count': len(lines),
        'path': path,
    })
print(json.dumps(out))
PY
}

read_loop_status_summary() {
  python3 - "$LOOP_STATUS_FILE" <<'PY'
import json, sys, os
path = sys.argv[1]
summary = {
    'workers_total': 0,
    'workers_running': 0,
    'workers_error': 0,
    'workers_stopped': 0,
    'workers_other': 0,
    'top': []
}
try:
    with open(path, 'r', encoding='utf-8', errors='ignore') as f:
        data = json.load(f)
except Exception:
    data = {}
if isinstance(data, dict):
    items = []
    for k, v in data.items():
        if isinstance(v, dict):
            items.append((k, v))
    summary['workers_total'] = len(items)
    for name, st in items:
        state = str(st.get('state','')).upper()
        if state == 'RUNNING': summary['workers_running'] += 1
        elif 'ERROR' in state or state == 'CRASH': summary['workers_error'] += 1
        elif state in ('STOPPED','STOP'): summary['workers_stopped'] += 1
        else: summary['workers_other'] += 1
    items.sort(key=lambda kv: str(kv[1].get('last_update','')), reverse=True)
    for name, st in items[:5]:
        summary['top'].append({
            'name': name,
            'state': st.get('state','-'),
            'round': st.get('round_num','-'),
            'idx': st.get('link_idx','-'),
            'total': st.get('link_total','-'),
            'link': st.get('current_link','')[:80],
            'err': st.get('last_error','')[:80],
            'last_update': st.get('last_update','-'),
        })
print(json.dumps(summary))
PY
}

show_dashboard() {
  local snapshot cpu mem_pct mem_used mem_total disk_pct disk_used disk_total load1 load5 load15
  snapshot="$(sys_snapshot)"
  cpu="$(printf '%s' "$snapshot" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("cpu","-"))')"
  mem_pct="$(printf '%s' "$snapshot" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("mem_pct","-"))')"
  mem_used="$(printf '%s' "$snapshot" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("mem_used_mb","-"))')"
  mem_total="$(printf '%s' "$snapshot" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("mem_total_mb","-"))')"
  disk_pct="$(printf '%s' "$snapshot" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("disk_pct","-"))')"
  disk_used="$(printf '%s' "$snapshot" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("disk_used_gb","-"))')"
  disk_total="$(printf '%s' "$snapshot" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("disk_total_gb","-"))')"
  load1="$(printf '%s' "$snapshot" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("load1","-"))')"
  load5="$(printf '%s' "$snapshot" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("load5","-"))')"
  load15="$(printf '%s' "$snapshot" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("load15","-"))')"

  local login_status loop_status buat_status chrome_count xvfb_count shot_count
  if proc_running "[l]ogin.js"; then login_status="${C_GREEN}RUNNING${C_RESET}"; elif grep -q "\[DONE\] semua akun selesai\|LOGIN FINISH" "$LOGIN_LOG" 2>/dev/null; then login_status="${C_GREEN}DONE${C_RESET}"; else login_status="${C_RED}STOP${C_RESET}"; fi
  if proc_running "[l]oop.js"; then loop_status="${C_GREEN}RUNNING${C_RESET}"; elif grep -q "START loop" "$LOOP_LOG" 2>/dev/null; then loop_status="${C_YELLOW}IDLE/STOP${C_RESET}"; else loop_status="${C_RED}STOP${C_RESET}"; fi
  if proc_running "[b]uat_link.js"; then buat_status="${C_GREEN}RUNNING${C_RESET}"; elif grep -q "PROSES SELESAI\|Semua akun selesai" "$BUAT_LINK_LOG" 2>/dev/null; then buat_status="${C_GREEN}DONE${C_RESET}"; else buat_status="${C_RED}STOP${C_RESET}"; fi
  chrome_count="$(count_proc 'google-chrome|chromedriver|chromium')"
  xvfb_count="$(count_proc 'xvfb-run|Xvfb')"
  shot_count="$(find "$SCREENSHOT_DIR" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')"

  local loop_json workers_total workers_running workers_error workers_stopped workers_other
  loop_json="$(read_loop_status_summary)"
  workers_total="$(printf '%s' "$loop_json" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("workers_total",0))')"
  workers_running="$(printf '%s' "$loop_json" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("workers_running",0))')"
  workers_error="$(printf '%s' "$loop_json" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("workers_error",0))')"
  workers_stopped="$(printf '%s' "$loop_json" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("workers_stopped",0))')"
  workers_other="$(printf '%s' "$loop_json" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("workers_other",0))')"

  clear_screen
  printf "%b" "${C_BOLD}${C_CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${C_RESET}\n"
  printf "%b" "${C_BOLD}${C_CYAN}║                      JOKO-IDX TERMINAL PRO MENU                              ║${C_RESET}\n"
  printf "%b" "${C_BOLD}${C_CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${C_RESET}\n"
  printf "%b\n" "${C_DIM}Auto-refresh hanya dashboard realtime • ${REFRESH_SECONDS}s • waktu: $(now)${C_RESET}"
  printf "%b\n\n" "${C_WHITE}Base:${C_RESET} $BASE_DIR   ${C_WHITE}Code:${C_RESET} $CODE_DIR"

  printf "%b\n" "${C_BOLD}${C_BLUE}[ STATUS PROSES ]${C_RESET}"
  printf "  Login      : %b\n" "$login_status"
  printf "  Loop       : %b\n" "$loop_status"
  printf "  Buat Link  : %b\n" "$buat_status"
  printf "  Chrome Proc: %s\n" "$chrome_count"
  printf "  Xvfb Proc  : %s\n" "$xvfb_count"
  printf "  Screenshots: %s\n\n" "$shot_count"

  printf "%b\n" "${C_BOLD}${C_BLUE}[ VPS LIVE ]${C_RESET}"
  printf "  CPU        : %s%%\n" "$cpu"
  printf "  RAM        : %s%%  (%s MB / %s MB)\n" "$mem_pct" "$mem_used" "$mem_total"
  printf "  Disk /     : %s%%  (%s GB / %s GB)\n" "$disk_pct" "$disk_used" "$disk_total"
  printf "  Load Avg   : %s  %s  %s\n" "$load1" "$load5" "$load15"
  printf "  Uptime     : %s\n\n" "$(human_uptime)"

  printf "%b\n" "${C_BOLD}${C_BLUE}[ WORKER LIVE ]${C_RESET}"
  printf "  Total      : %s\n" "$workers_total"
  printf "  Running    : %s\n" "$workers_running"
  printf "  Error/Crash: %s\n" "$workers_error"
  printf "  Stopped    : %s\n" "$workers_stopped"
  printf "  Other      : %s\n\n" "$workers_other"

  printf "%b\n" "${C_BOLD}${C_BLUE}[ SHORTCUT MENU ]${C_RESET}"
  printf "%b\n" "${C_CYAN}╔══════════════════╦══════════════════╦══════════════════╦══════════════════╗${C_RESET}"
  printf "║ ${C_GREEN}1${C_RESET} Start Login   ║ ${C_RED}2${C_RESET} Stop Login    ║ ${C_GREEN}3${C_RESET} Start Loop    ║ ${C_RED}4${C_RESET} Stop Loop     ║\n"
  printf "║ ${C_GREEN}5${C_RESET} Start BuatLn  ║ ${C_RED}6${C_RESET} Stop BuatLn   ║ ${C_RED}7${C_RESET} Stop ALL      ║ ${C_RED}8${C_RESET} Kill ALL      ║\n"
  printf "╠══════════════════╬══════════════════╬══════════════════╬══════════════════╣\n"
  printf "║ ${C_YELLOW}E${C_RESET} Edit Email    ║ ${C_YELLOW}J${C_RESET} Edit JokoTxt  ║ ${C_CYAN}L${C_RESET} List Link     ║ ${C_CYAN}T${C_RESET} Total Link    ║\n"
  printf "║ ${C_YELLOW}c${C_RESET} Clear RAM     ║ ${C_YELLOW}m${C_RESET} Reset Mapping ║ ${C_YELLOW}r${C_RESET} Reset Profile ║ ${C_YELLOW}p${C_RESET} Del Profile   ║\n"
  printf "║ ${C_YELLOW}g${C_RESET} Cleanup PNG   ║ ${C_YELLOW}l${C_RESET} Cleanup Logs  ║ ${C_CYAN}v${C_RESET} View Logs     ║ ${C_CYAN}s${C_RESET} View Screen   ║\n"
  printf "║ ${C_CYAN}h${C_RESET} Help          ║ ${C_WHITE}q${C_RESET} Quit Menu     ║                  ║                  ║\n"
  printf "%b\n\n" "${C_CYAN}╚══════════════════╩══════════════════╩══════════════════╩══════════════════╝${C_RESET}"

  printf "%b\n" "${C_BOLD}${C_BLUE}[ WORKER DETAIL TERBARU ]${C_RESET}"
  printf '%s' "$loop_json" | python3 - <<'PY'
import sys, json
try:
    data = json.load(sys.stdin)
except Exception:
    data = {}
items = data.get('top', []) if isinstance(data, dict) else []
if not items:
    print('  Belum ada data worker di loop_status.json')
else:
    for row in items:
        name = row.get('name','-')
        state = row.get('state','-')
        rnd = row.get('round','-')
        idx = row.get('idx','-')
        total = row.get('total','-')
        link = row.get('link','') or '-'
        err = row.get('err','')
        last = row.get('last_update','-')
        print(f'  {name} | {state} | round={rnd} | link={idx}/{total}')
        print(f'    current: {link}')
        if err:
            print(f'    err    : {err}')
        print(f'    update : {last}')
PY
  printf "\n%b\n" "${C_BOLD}${C_MAGENTA}[ INFO ]${C_RESET} ${LAST_MSG}"
}

show_help() {
  clear_screen
  cat <<'TXT'
JOKO TERMINAL PRO - SHORTCUT

╔══════════════════╦══════════════════╦══════════════════╦══════════════════╗
║ 1  Start Login   ║ 2  Stop Login    ║ 3  Start Loop    ║ 4  Stop Loop     ║
║ 5  Start BuatLn  ║ 6  Stop BuatLn   ║ 7  Stop ALL      ║ 8  Kill ALL      ║
╠══════════════════╬══════════════════╬══════════════════╬══════════════════╣
║ E  Edit Email    ║ J  Edit JokoTxt  ║ L  List Link     ║ T  Total Link    ║
║ c  Clear RAM     ║ m  Reset Mapping ║ r  Reset Profile ║ p  Del Profile   ║
║ g  Cleanup PNG   ║ l  Cleanup Logs  ║ v  View Logs     ║ s  View Screen   ║
║ h  Help          ║ q  Quit Menu     ║                  ║                  ║
╚══════════════════╩══════════════════╩══════════════════╩══════════════════╝

Dashboard saja yang auto-refresh.
Halaman edit / list / total tidak auto-refresh.
TXT
  pause_any
}

view_logs() {
  clear_screen
  echo "===== BOT LOG ====="; tail -n 25 "$BOT_LOG" 2>/dev/null || true
  echo
  echo "===== LOGIN LOG ====="; tail -n 20 "$LOGIN_LOG" 2>/dev/null || true
  echo
  echo "===== LOOP LOG ====="; tail -n 20 "$LOOP_LOG" 2>/dev/null || true
  echo
  echo "===== BUAT LINK LOG ====="; tail -n 20 "$BUAT_LINK_LOG" 2>/dev/null || true
  echo
  pause_any
}

view_screens() {
  clear_screen
  echo "===== SCREENSHOTS ====="
  ls -lah "$SCREENSHOT_DIR" 2>/dev/null || true
  echo
  pause_any
}

prompt_multiline_to_file() {
  local file="$1"
  local title="$2"
  local tmp
  tmp="$(mktemp)"
  clear_screen
  echo "===== $title ====="
  echo "File: $file"
  echo
  echo "Masukkan isi baru."
  echo "Akhiri dengan ketik satu baris: EOF"
  echo "Kosongkan semua lalu EOF kalau mau file kosong."
  echo
  while IFS= read -r line; do
    [ "$line" = "EOF" ] && break
    printf '%s\n' "$line" >> "$tmp"
  done
  cp "$tmp" "$file"
  rm -f "$tmp"
  LAST_MSG="Berhasil update $(basename "$file")"
  log_line "EDIT $(basename "$file")"
}

append_lines_to_file() {
  local file="$1"
  local title="$2"
  clear_screen
  echo "===== $title ====="
  echo "File: $file"
  echo
  echo "Masukkan baris yang mau ditambahkan."
  echo "Akhiri dengan ketik satu baris: EOF"
  echo
  while IFS= read -r line; do
    [ "$line" = "EOF" ] && break
    printf '%s\n' "$line" >> "$file"
  done
  LAST_MSG="Berhasil tambah isi ke $(basename "$file")"
  log_line "APPEND $(basename "$file")"
}

view_file_with_numbers() {
  local file="$1"
  clear_screen
  echo "===== $(basename "$file") ====="
  if [ -s "$file" ]; then
    nl -ba "$file"
  else
    echo "(kosong)"
  fi
  echo
  pause_any
}

remove_line_from_file() {
  local file="$1"
  clear_screen
  echo "===== HAPUS BARIS $(basename "$file") ====="
  if [ ! -s "$file" ]; then
    echo "File kosong."
    echo
    pause_any
    return
  fi
  nl -ba "$file"
  echo
  read -rp "Masukkan nomor baris yang mau dihapus: " line_no
  if [[ ! "$line_no" =~ ^[0-9]+$ ]]; then
    LAST_MSG="Nomor baris tidak valid."
    return
  fi
  awk -v n="$line_no" 'NR != n' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
  LAST_MSG="Baris $line_no dihapus dari $(basename "$file")"
  log_line "DELETE line $line_no from $(basename "$file")"
}

replace_line_in_file() {
  local file="$1"
  clear_screen
  echo "===== GANTI BARIS $(basename "$file") ====="
  if [ ! -s "$file" ]; then
    echo "File kosong."
    echo
    pause_any
    return
  fi
  nl -ba "$file"
  echo
  read -rp "Masukkan nomor baris yang mau diganti: " line_no
  if [[ ! "$line_no" =~ ^[0-9]+$ ]]; then
    LAST_MSG="Nomor baris tidak valid."
    return
  fi
  read -rp "Isi baru: " new_line
  awk -v n="$line_no" -v s="$new_line" 'NR==n {$0=s} {print}' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
  LAST_MSG="Baris $line_no diganti di $(basename "$file")"
  log_line "REPLACE line $line_no in $(basename "$file")"
}

clear_file_contents() {
  local file="$1"
  read -rp "Yakin kosongkan $(basename "$file") ? (y/N): " ans
  case "$ans" in
    y|Y) : > "$file"; LAST_MSG="$(basename "$file") dikosongkan."; log_line "CLEAR $(basename "$file")" ;;
    *) LAST_MSG="Batal kosongkan $(basename "$file")" ;;
  esac
}

edit_generic_file_menu() {
  local file="$1"
  local title="$2"
  while true; do
    clear_screen
    echo "===== $title ====="
    echo "File : $file"
    echo "Baris: $(count_lines "$file")"
    echo
    echo "1) Lihat isi"
    echo "2) Ganti semua isi file"
    echo "3) Tambah baris"
    echo "4) Ganti satu baris"
    echo "5) Hapus satu baris"
    echo "6) Kosongkan file"
    echo "q) Kembali"
    echo
    read -rsn1 key
    echo
    case "$key" in
      1) view_file_with_numbers "$file" ;;
      2) prompt_multiline_to_file "$file" "$title" ;;
      3) append_lines_to_file "$file" "$title" ;;
      4) replace_line_in_file "$file" ;;
      5) remove_line_from_file "$file" ;;
      6) clear_file_contents "$file" ;;
      q|Q) break ;;
      *) LAST_MSG="Shortcut tidak dikenal di menu edit $(basename "$file")" ;;
    esac
  done
}

edit_email_menu() {
  edit_generic_file_menu "$EMAIL_FILE" "EDIT email.txt"
}

show_joko_file_table() {
  local json
  json="$(joko_file_stats)"
  printf '%s' "$json" | python3 - <<'PY'
import sys, json
try:
    rows = json.load(sys.stdin)
except Exception:
    rows = []
if not rows:
    print('Belum ada file joko*.txt')
else:
    print('No  File       Total Link')
    print('--  ---------  ----------')
    for i, row in enumerate(rows, 1):
        print(f'{i:<3} {row["name"]:<10} {row["count"]}')
PY
}

pick_joko_file() {
  local files=()
  while IFS= read -r f; do
    [ -n "$f" ] && files+=("$f")
  done < <(list_joko_files)

  if [ "${#files[@]}" -eq 0 ]; then
    clear_screen
    echo "Belum ada file joko*.txt di $BASE_DIR"
    echo
    read -rp "Buat berapa file awal? (contoh 3): " wanted
    if [[ "$wanted" =~ ^[0-9]+$ ]]; then
      ensure_joko_files "$wanted"
    else
      ensure_joko_files 1
    fi
    mapfile -t files < <(list_joko_files)
  fi

  while true; do
    clear_screen
    echo "===== PILIH FILE JOKO ====="
    show_joko_file_table
    echo
    echo "n) Buat file joko baru"
    echo "q) Kembali"
    echo
    read -rp "Pilih nomor file: " choice
    case "$choice" in
      q|Q) return 1 ;;
      n|N)
        local next_idx=1
        if [ "${#files[@]}" -gt 0 ]; then
          next_idx=$(( ${#files[@]} + 1 ))
        fi
        touch "$BASE_DIR/joko${next_idx}.txt"
        LAST_MSG="Berhasil buat joko${next_idx}.txt"
        mapfile -t files < <(list_joko_files)
        ;;
      *)
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#files[@]}" ]; then
          printf '%s\n' "${files[$((choice-1))]}"
          return 0
        fi
        LAST_MSG="Pilihan file tidak valid."
        ;;
    esac
  done
}

edit_joko_menu() {
  local selected
  selected="$(pick_joko_file)" || return
  edit_generic_file_menu "$selected" "EDIT $(basename "$selected")"
}

list_links_menu() {
  clear_screen
  echo "===== LIST LINK DARI JOKO TXT ====="
  python3 - "$BASE_DIR" <<'PY'
import os, re, sys
base = sys.argv[1]
found = False
for name in sorted(os.listdir(base)):
    if not re.fullmatch(r'joko\d+\.txt', name):
        continue
    found = True
    path = os.path.join(base, name)
    print(f'--- {name} ---')
    try:
        with open(path, 'r', encoding='utf-8', errors='ignore') as f:
            rows = [ln.rstrip('\n') for ln in f]
    except Exception as e:
        print(f'  [gagal baca: {e}]')
        print()
        continue
    nonempty = [ln for ln in rows if ln.strip()]
    if not nonempty:
        print('  (kosong)')
    else:
        for i, ln in enumerate(nonempty, 1):
            print(f'  {i}. {ln}')
    print()
if not found:
    print('Belum ada file joko*.txt')
PY
  pause_any
}

total_links_menu() {
  clear_screen
  echo "===== TOTAL LINK ====="
  python3 - "$BASE_DIR" <<'PY'
import os, re, sys
base = sys.argv[1]
grand = 0
rows = []
for name in sorted(os.listdir(base)):
    if not re.fullmatch(r'joko\d+\.txt', name):
        continue
    path = os.path.join(base, name)
    try:
        with open(path, 'r', encoding='utf-8', errors='ignore') as f:
            count = sum(1 for ln in f if ln.strip())
    except Exception:
        count = 0
    grand += count
    rows.append((name, count))
if not rows:
    print('Belum ada file joko*.txt')
else:
    print('File       Total Link')
    print('---------  ----------')
    for name, count in rows:
        print(f'{name:<10} {count}')
    print('---------------------')
    print(f'TOTAL SEMUA: {grand}')
PY
  echo
  echo "Info mapping loop.js:"
  echo "- CLONES_PER_FILE default = 10"
  echo "- clone joko1-joko10  -> baca joko1.txt"
  echo "- clone joko11-joko20 -> baca joko2.txt"
  echo "- clone joko21-joko30 -> baca joko3.txt"
  echo
  pause_any
}

handle_key() {
  case "$1" in
    1) start_login ;;
    2) stop_login ;;
    3) start_loop ;;
    4) stop_loop ;;
    5) start_buat_link ;;
    6) stop_buat_link ;;
    7) stop_all ;;
    8) kill_all ;;
    e|E) edit_email_menu ;;
    j|J) edit_joko_menu ;;
    L) list_links_menu ;;
    t|T) total_links_menu ;;
    c|C) clear_ram_cache ;;
    m|M) reset_mapping ;;
    r|R) reset_chrome_profiles ;;
    p|P) delete_chrome_profiles ;;
    g|G) cleanup_root_png ;;
    l) cleanup_logs_json_lock ;;
    v|V) view_logs ;;
    s|S) view_screens ;;
    h|H) show_help ;;
    q|Q) clear_screen; exit 0 ;;
    *) LAST_MSG="Shortcut tidak dikenal: $1" ;;
  esac
}

trap 'clear_screen; exit 0' INT TERM

while true; do
  show_dashboard
  if read -rsn1 -t "$REFRESH_SECONDS" key; then
    handle_key "$key"
  fi
done
