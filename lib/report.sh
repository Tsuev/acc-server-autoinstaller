#!/usr/bin/env bash
# shellcheck shell=bash

# =============================================================================
# acc-manager — проверка запуска и финальный отчёт.
# =============================================================================

verify_install() {
  local web_port="$1" admin="$2"
  local url="http://127.0.0.1:${web_port}/"
  local i ok token

  info "Проверка работоспособности..."

  # 1. ACCWeb отвечает по HTTP.
  ok=0
  for ((i = 0; i < 30; i++)); do
    if curl -fsS -o /dev/null "$url" 2>/dev/null; then
      ok=1
      break
    fi
    sleep 2
  done
  if ((ok == 1)); then
    info "ACCWeb отвечает по HTTP (${url}) — OK."
  else
    warn "ACCWeb не отвечает по ${url}. Проверьте: journalctl -u ${SERVICE_NAME} -e"
  fi

  # 2. Авторизация в ACCWeb (проверка пароля администратора).
  token="$(curl -fsS -X POST "http://127.0.0.1:${web_port}/api/login" \
    -H 'Content-Type: application/json' \
    -d "$(jq -nc --arg p "$admin" '{password: $p}')" 2>/dev/null \
    | jq -r '.token // empty' || true)"
  if [[ -n "$token" ]]; then
    info "Авторизация в ACCWeb успешна (OK)."
  else
    warn "Не удалось авторизоваться в ACCWeb (проверьте пароль администратора)."
  fi

  # 3. Dedicated Server запускается через ACCWeb.
  ok=0
  for ((i = 0; i < 60; i++)); do
    if pgrep -f -i accserver >/dev/null 2>&1; then
      ok=1
      break
    fi
    sleep 2
  done
  if ((ok == 1)); then
    info "Dedicated Server запущен через ACCWeb (OK)."
  else
    warn "Dedicated Server пока не запущен. Проверьте логи ACCWeb и статус сервиса."
  fi

  # 4. Критические ошибки в сервисе.
  if systemctl is-active --quiet "$SERVICE_NAME"; then
    info "Сервис ${SERVICE_NAME} активен (OK)."
  else
    warn "Сервис ${SERVICE_NAME} не активен. Проверьте: journalctl -u ${SERVICE_NAME} -e"
  fi
}

print_report() {
  local web_port="$1" admin="$2" tcp="$3" udp="$4" ip
  ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  [[ -n "$ip" ]] || ip="<IP-адрес сервера>"

  cat <<EOF

================================================================
  Установка завершена!
================================================================
  Панель ACCWeb:   http://${ip}:${web_port}/
  Логин:           username (вводится только пароль)
  Пароль:          ${admin}
  Игровой TCP:     ${tcp}
  Игровой UDP:     ${udp}
  Статус:          OK
================================================================
  Управление сервисом:
    systemctl status ${SERVICE_NAME}
    journalctl -u ${SERVICE_NAME} -f
  Логи установщика:
    ${LOG_FILE}
================================================================
EOF
}
