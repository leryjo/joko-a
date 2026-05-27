#!/usr/bin/env bash
set -e
CODE_DIR="${CODE_DIR:-/joko-app}"
BASE_DIR="${BASE_DIR:-/joko-app/joko-idx}"
export CODE_DIR BASE_DIR

echo "=================================================="
echo " JOKO-IDX NODEJS TERMINAL "
echo " CODE_DIR : $CODE_DIR"
echo " BASE_DIR : $BASE_DIR"
echo " FILE RUN : login.js / loop.js / buat_link.js"
echo " MODE     : Docker + Node.js, AUTO ROOT FOLDER FIX"
echo "=================================================="

# AUTO BUAT FOLDER + FILE KERJA
mkdir -p "$BASE_DIR" || true
mkdir -p "$BASE_DIR/chrome_profiles" "$BASE_DIR/screenshots" "$BASE_DIR/snapshots" "$BASE_DIR/notif_markers" || true

touch "$BASE_DIR/email.txt" "$BASE_DIR/emailshare.txt" "$BASE_DIR/mapping_profil.txt" || true
touch "$BASE_DIR/bot_log.txt" "$BASE_DIR/login_log.txt" "$BASE_DIR/loop_log.txt" "$BASE_DIR/buat_link_log.txt" "$BASE_DIR/loop_status.json" || true
touch "$BASE_DIR/joko1.txt" "$BASE_DIR/hasil.txt" "$BASE_DIR/akun_bermasalah.txt" || true

# Paksa permission longgar supaya Firebase IDX bind mount tidak EACCES
chmod -R 777 "$BASE_DIR" 2>/dev/null || true
rm -f /tmp/.X99-lock || true

exec "$CODE_DIR/menu.sh"
