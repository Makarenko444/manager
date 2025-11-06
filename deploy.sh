#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${SERVER_HOST:-}" || -z "${SERVER_USER:-}" || -z "${SERVER_PATH:-}" ]]; then
  echo "SERVER_HOST, SERVER_USER и SERVER_PATH должны быть заданы" >&2
  exit 1
fi

echo "Создаю директорию ${SERVER_PATH} на сервере..."
ssh "${SERVER_USER}@${SERVER_HOST}" "mkdir -p '${SERVER_PATH}' && chmod 755 '${SERVER_PATH}'"

echo "Синхронизирую файлы..."
rsync -avz --delete \
  index.html styles.css Dockerfile docker-compose.yml \
  "${SERVER_USER}@${SERVER_HOST}:${SERVER_PATH}/"

echo "Готово. Проверьте сайт по адресу, настроенному на ${SERVER_PATH}."
