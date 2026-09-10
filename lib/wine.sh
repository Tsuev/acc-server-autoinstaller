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

  if ! has_command xvfb-run; then
    die "xvfb-run не найден. Установите пакеты: apt-get install -y xvfb xauth"
  fi

  info "Инициализация Wine prefix (${WINE_PREFIX})... Это может занять пару минут."

  local wine_log
  wine_log="$(mktemp)"

  # Wine требует X-дисплей даже для wineboot, поэтому запускаем под Xvfb.
  # `timeout` стоит ВНУТРИ цепочки (перед xvfb-run) и оборачивает исполняемую
  # команду — оборачивать им shell-функцию run_as_acc_wine нельзя.
  # WINEDLLOVERRIDES (см. run_as_acc_wine) отключает запросы установки Mono/Gecko.
  if ! run_as_acc_wine timeout 600 \
    xvfb-run -a -s "-screen 0 1024x768x24" wineboot --init >"$wine_log" 2>&1; then
    warn "Вывод Wine (последние строки):"
    tail -n 30 "$wine_log" >&2 || true
    log "[wineboot] $(tail -n 30 "$wine_log")"
    rm -f "$wine_log"
    die "Не удалось инициализировать Wine prefix. Смотрите вывод Wine выше и ${LOG_FILE}."
  fi

  log "[wineboot] $(tail -n 30 "$wine_log")"
  rm -f "$wine_log"

  if [[ ! -d "$WINE_PREFIX/drive_c" ]]; then
    die "Wine prefix не был создан (${WINE_PREFIX}/drive_c отсутствует)."
  fi

  info "Wine prefix инициализирован (OK)."
}
