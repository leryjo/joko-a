FROM node:20-bullseye

ENV DEBIAN_FRONTEND=noninteractive \
    CODE_DIR=/joko-app \
    BASE_DIR=/joko-app/joko-idx \
    CHROME_BINARY=/usr/bin/chromium \
    CHROMEDRIVER_PATH=/usr/bin/chromedriver

WORKDIR /joko-app

USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl unzip jq xvfb xauth procps psmisc ca-certificates gosu \
    nano vim-tiny less fonts-liberation chromium chromium-driver \
    libnss3 libxss1 libasound2 libgbm1 libgtk-3-0 libatk-bridge2.0-0 \
    libdrm2 libxkbcommon0 libxrandr2 libxdamage1 libxcomposite1 libxfixes3 libxi6 \
    python3 make g++ \
    && rm -rf /var/lib/apt/lists/*

COPY package.json package-lock.json* ./
RUN npm install --omit=dev

COPY *.js menu.sh entrypoint.sh ./
RUN chmod +x /joko-app/menu.sh /joko-app/entrypoint.sh \
    && mkdir -p /joko-app/joko-idx/chrome_profiles /joko-app/joko-idx/screenshots /joko-app/joko-idx/snapshots /joko-app/joko-idx/notif_markers \
    && touch /joko-app/joko-idx/email.txt /joko-app/joko-idx/emailshare.txt /joko-app/joko-idx/mapping_profil.txt \
          /joko-app/joko-idx/bot_log.txt /joko-app/joko-idx/login_log.txt /joko-app/joko-idx/loop_log.txt \
          /joko-app/joko-idx/buat_link_log.txt /joko-app/joko-idx/loop_status.json \
    && chown -R node:node /joko-app \
    && chmod -R 775 /joko-app/joko-idx

# Tetap start sebagai root hanya untuk auto-fix permission folder mount,
# setelah itu proses menu/node dijalankan sebagai user node.
USER root
VOLUME ["/joko-app/joko-idx"]
CMD ["./entrypoint.sh"]
