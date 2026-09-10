#!/usr/bin/env bash
# shellcheck shell=bash

# =============================================================================
# acc-manager — создание и запуск systemd-сервиса ACCWeb.
# =============================================================================

create_service() {
  render_template "$TEMPLATE_DIR/accweb.service.tpl" "/etc/systemd/system/${SERVICE_NAME}.service" \
    "ACC_USER=$ACC_USER" \
    "ACCWEB_DIR=$ACCWEB_DIR" \
    "WINE_PREFIX=$WINE_PREFIX"

  systemctl daemon-reload
  systemctl enable "$SERVICE_NAME" >/dev/null 2>&1
  info "systemd-сервис ${SERVICE_NAME} создан и включён в автозагрузку."
}

start_service() {
  if systemctl is-active --quiet "$SERVICE_NAME"; then
    systemctl restart "$SERVICE_NAME"
  else
    systemctl start "$SERVICE_NAME"
  fi
  info "Сервис ${SERVICE_NAME} запущен."
}

stop_and_remove_service() {
  local svc="${SERVICE_NAME:-accweb}"

  if systemctl list-unit-files --type=service 2>/dev/null | grep -q "^${svc}\.service"; then
    systemctl stop "$svc" 2>/dev/null || true
    systemctl disable "$svc" 2>/dev/null || true
    rm -f "/etc/systemd/system/${svc}.service"
    systemctl daemon-reload
    info "systemd-сервис ${svc} остановлен и удалён."
  else
    info "systemd-сервис ${svc} не найден."
  fi
}
