#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="${CONTAINER_NAME:-onlyoffice-documentserver}"
HOST_FONT_DIR="${HOST_FONT_DIR:-/data/onlyoffice/fonts}"
CONTAINER_FONT_DIR="${CONTAINER_FONT_DIR:-/usr/share/fonts/truetype/custom}"

mkdir -p "${HOST_FONT_DIR}"

if ! command -v docker >/dev/null 2>&1; then
  echo "[ERROR] docker command not found."
  exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -qx "${CONTAINER_NAME}"; then
  echo "[ERROR] container not running: ${CONTAINER_NAME}"
  echo "[INFO] Please start ONLYOFFICE DocumentServer first."
  exit 1
fi

echo "[INFO] Font directory on host: ${HOST_FONT_DIR}"
echo "[INFO] Please put required fonts into this directory before running this script:"
echo "       simsun.ttc, simhei.ttf, simkai.ttf, simfang.ttf, fangzheng_xiaobiaosong.ttf, times*.ttf"

FONT_COUNT=$(find "${HOST_FONT_DIR}" -type f \( -iname '*.ttf' -o -iname '*.ttc' -o -iname '*.otf' \) | wc -l | tr -d ' ')
if [ "${FONT_COUNT}" = "0" ]; then
  echo "[WARN] No font files found in ${HOST_FONT_DIR}."
  echo "[WARN] Mount directory exists, but fonts are not ready."
fi

echo "[INFO] Refresh font cache in container: ${CONTAINER_NAME}"
docker exec "${CONTAINER_NAME}" bash -lc "mkdir -p '${CONTAINER_FONT_DIR}' && fc-cache -fv"

echo "[INFO] Chinese fonts currently visible in container:"
docker exec "${CONTAINER_NAME}" bash -lc "fc-list :lang=zh | head -n 50 || true"

echo "[INFO] Restart ONLYOFFICE services."
docker exec "${CONTAINER_NAME}" bash -lc "supervisorctl restart all || true"

echo "[INFO] Restart container to ensure all services reload fonts."
docker restart "${CONTAINER_NAME}"

echo "[OK] Font cache refreshed and DocumentServer restarted."
