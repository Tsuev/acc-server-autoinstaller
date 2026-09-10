#!/usr/bin/env bash
# shellcheck shell=bash

# =============================================================================
# acc-manager — настройка Wine prefix.
# =============================================================================

setup_wine_prefix() {
  mkdir -p "$ACC_HOME"
  chown "$ACC_USER":"$ACC_USER" "$ACC_HOME" 2>/dev/null || true

  if [[ -d "$WINE_PREFIX/drive_c" ]]; then
    info "Wine prefix уже существует (${WINE_PREFIX})."
    return 0
  fi

  info "Инициализация Wine prefix (${WINE_PREFIX})... Это может занять пару минут."
  if ! timeout 300 run_as_acc_wine wineboot >/dev/null 2>&1; then
    die "Не удалось инициализировать Wine prefix. Проверьте логи: ${LOG_FILE}"
  fi

  if [[ ! -d "$WINE_PREFIX/drive_c" ]]; then
    die "Wine prefix не был создан (${WINE_PREFIX}/drive_c отсутствует)."
  fi

  info "Wine prefix инициализирован (OK)."
}
