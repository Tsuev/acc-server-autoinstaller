#!/usr/bin/env bash
# shellcheck shell=bash

# =============================================================================
# acc-manager — настройка Wine prefix.
# =============================================================================

# Убедиться, что имя хоста резолвится. Иначе Wine при инициализации prefix
# может «зависнуть» на обратном резолве имени (частая причина на VPS).
ensure_hostname_resolvable() {
  local host
  host="$(hostname)"
  if getent hosts "$host" >/dev/null 2>&1; then
    return 0
  fi
  warn "Имя хоста '${host}' не резолвится — Wine может зависнуть. Добавляю запись в /etc/hosts."
  printf '127.0.1.1\t%s\n' "$host" >>/etc/hosts
}

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

  ensure_hostname_resolvable

  info "Инициализация Wine prefix (${WINE_PREFIX})."
  info "Первый запуск занимает 1–3 минуты — ниже вывод wineboot в реальном времени:"

  local wine_log wine_pid tail_pid rc=0
  wine_log="$(mktemp)"

  # ВАЖНО: вывод пишем в ФАЙЛ, а НЕ в пайп (| tee). wineserver держит stdout-pipe
  # открытым даже после выхода wineboot, из-за чего пайп никогда не получает EOF
  # и установка «зависает» навсегда. Для «живого» вывода параллельно читаем файл
  # через `tail -f` и останавливаем его после завершения wineboot.
  # Wine требует X-дисплей даже для wineboot, поэтому запускаем под Xvfb.
  # `timeout` стоит ВНУТРИ цепочки (перед xvfb-run) и оборачивает исполняемую
  # команду — оборачивать им shell-функцию run_as_acc_wine нельзя.
  # WINEDLLOVERRIDES (см. run_as_acc_wine) отключает запросы установки Mono/Gecko.
  run_as_acc_wine timeout 180 \
    xvfb-run -a -s "-screen 0 1024x768x24" wineboot --init >"$wine_log" 2>&1 &
  wine_pid=$!

  tail -n +1 -f "$wine_log" 2>/dev/null &
  tail_pid=$!

  wait "$wine_pid" || rc=$?

  kill "$tail_pid" 2>/dev/null || true
  wait "$tail_pid" 2>/dev/null || true

  log "[wineboot] $(tail -n 30 "$wine_log")"
  rm -f "$wine_log"

  if ((rc != 0)); then
    die "Не удалось инициализировать Wine prefix (см. вывод выше и ${LOG_FILE})."
  fi

  if [[ ! -d "$WINE_PREFIX/drive_c" ]]; then
    die "Wine prefix не был создан (${WINE_PREFIX}/drive_c отсутствует)."
  fi

  info "Wine prefix инициализирован (OK)."
}
