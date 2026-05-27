JOKO-IDX - Docker + Node.js ROOT PERMISSION FIX

Fix terbaru:
- Mengatasi error EACCES permission denied saat login.js membuat chrome_profiles/jokoX.
- Container berjalan sebagai root di dalam Docker agar folder bind mount Firebase IDX bisa ditulis.
- Terminal Firebase IDX tetap non-root; root hanya di dalam container Docker.
- Folder data tetap: ./joko-idx -> /joko-app/joko-idx

RUN ULANG DARI AWAL:

docker rm -f joko-idx 2>/dev/null || true
rm -rf joko-idx/chrome_profiles
mkdir -p joko-idx
chmod -R 777 joko-idx

docker build --no-cache -t joko-idx .
docker run -it --name joko-idx -v $(pwd)/joko-idx:/joko-app/joko-idx joko-idx

Isi akun:
- Dari menu tekan E, atau edit file joko-idx/email.txt
- Format: email@gmail.com|password

Menu:
1 = Start Login
3 = Start Loop
5 = Start Buat Link
v = View Logs
q = Quit

Kalau mau jalan lagi:
docker start -ai joko-idx

UPDATE DASHBOARD FIX:
- Status dashboard sekarang cek proses Node.js: login.js / loop.js / buat_link.js, bukan .py.
- Kalau login.js selesai, status tampil DONE, bukan STOP merah.
- CPU/RAM/Disk tidak butuh psutil lagi, dibaca langsung dari /proc dan df.
