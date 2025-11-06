#!/usr/bin/env bash
set -euo pipefail

REQUIRED_VARS=(SERVER_HOST SERVER_USER SERVER_PATH SERVER_DOMAIN)
MISSING_VARS=()
for var in "${REQUIRED_VARS[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    MISSING_VARS+=("${var}")
  fi
done
if [[ ${#MISSING_VARS[@]} -gt 0 ]]; then
  echo "Не заданы переменные окружения: ${MISSING_VARS[*]}" >&2
  exit 1
fi

TEMPLATE_FILE="config/nginx/site.conf.template"
if [[ ! -f "${TEMPLATE_FILE}" ]]; then
  echo "Не найден шаблон nginx: ${TEMPLATE_FILE}" >&2
  exit 1
fi

if ! command -v envsubst >/dev/null 2>&1; then
  echo "Установите пакет gettext (команда envsubst недоступна)" >&2
  exit 1
fi

TMP_CONFIG="$(mktemp)"
trap 'rm -f "${TMP_CONFIG}"' EXIT

export SERVER_DOMAIN SERVER_PATH
envsubst '${SERVER_DOMAIN} ${SERVER_PATH}' < "${TEMPLATE_FILE}" > "${TMP_CONFIG}"

REMOTE_TMP="/tmp/${SERVER_DOMAIN}.conf"
REMOTE_FINAL="/etc/nginx/sites-available/${SERVER_DOMAIN}.conf"

printf '\nНастраиваю Nginx для %s на %s...\n' "${SERVER_DOMAIN}" "${SERVER_HOST}"

scp "${TMP_CONFIG}" "${SERVER_USER}@${SERVER_HOST}:${REMOTE_TMP}"

ssh "${SERVER_USER}@${SERVER_HOST}" \
  SERVER_DOMAIN="${SERVER_DOMAIN}" \
  SERVER_PATH="${SERVER_PATH}" \
  SERVER_USER="${SERVER_USER}" \
  REMOTE_TMP="${REMOTE_TMP}" \
  REMOTE_FINAL="${REMOTE_FINAL}" \
  'bash -s' <<'REMOTE'
set -euo pipefail

install_nginx() {
  if command -v nginx >/dev/null 2>&1; then
    return 0
  fi

  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y nginx
  elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y epel-release >/dev/null 2>&1 || true
    sudo yum install -y nginx
  else
    echo "Не удалось установить nginx: неизвестный пакетный менеджер" >&2
    exit 1
  fi
}

install_nginx

sudo install -d -m 755 "${SERVER_PATH}"
if id "${SERVER_USER}" >/dev/null 2>&1; then
  sudo chown -R "${SERVER_USER}:${SERVER_USER}" "${SERVER_PATH}"
fi

sudo mv "${REMOTE_TMP}" "${REMOTE_FINAL}"
sudo ln -sf "${REMOTE_FINAL}" "/etc/nginx/sites-enabled/${SERVER_DOMAIN}.conf"

if sudo nginx -t; then
  sudo systemctl enable nginx >/dev/null 2>&1 || true
  sudo systemctl reload nginx
else
  echo "nginx -t завершился с ошибкой" >&2
  exit 1
fi
REMOTE

printf 'Готово. Проверьте, что домен %s обслуживается Nginx.\n' "${SERVER_DOMAIN}"
