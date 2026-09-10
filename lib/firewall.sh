#!/usr/bin/env bash
# shellcheck shell=bash

# =============================================================================
# acc-manager — настройка межсетевого экрана (UFW).
# =============================================================================

configure_firewall() {
  local tcp="$1" udp="$2" web="$3"

  if ! has_command ufw; then
    warn "ufw не найден — настройка фаервола пропущена."
    return 0
  fi

  info "Открытие портов в UFW: TCP ${tcp}, UDP ${udp}, панель ${web}/tcp..."
  ufw allow "${tcp}/tcp" >/dev/null
  ufw allow "${udp}/udp" >/dev/null
  ufw allow "${web}/tcp" >/dev/null

  if ufw status | grep -q 'Status: active'; then
    info "Порты открыты в UFW (OK)."
  else
    warn "UFW отключён. Правила добавлены, но вступят в силу после включения: 'ufw enable'."
  fi
}

remove_firewall_rules() {
  local tcp="${TCP_PORT:-9600}" udp="${UDP_PORT:-9600}" web="${WEB_PORT:-8080}"

  if ! has_command ufw; then
    return 0
  fi

  ufw delete allow "${tcp}/tcp" >/dev/null 2>&1 || true
  ufw delete allow "${udp}/udp" >/dev/null 2>&1 || true
  ufw delete allow "${web}/tcp" >/dev/null 2>&1 || true
  info "Правила UFW, созданные установщиком, удалены (если существовали)."
}
