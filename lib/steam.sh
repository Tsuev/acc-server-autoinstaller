#!/usr/bin/env bash
# shellcheck shell=bash

# =============================================================================
# acc-manager — авторизация Steam и загрузка ACC Dedicated Server.
# =============================================================================

steam_download_server() {
  local steam_user="$1" steam_pass="$2" steam_guard="$3"
  local login_args logfile cmd

  mkdir -p "$STEAMCMD_DIR" "$SERVER_DIR"
  chown -R "$ACC_USER":"$ACC_USER" "$STEAMCMD_DIR" "$SERVER_DIR"

  # Первый запуск SteamCMD (принятие лицензии, если потребуется).
  runuser -u "$ACC_USER" -- bash -c \
    "\"${STEAMCMD_DIR}/steamcmd.sh\" +quit <<< 'yes' >/dev/null 2>&1" || true

  login_args=(+login "$steam_user" "$steam_pass")
  [[ -n "$steam_guard" ]] && login_args+=("$steam_guard")

  cmd=(
    "$STEAMCMD_DIR/steamcmd.sh"
    +@sSteamCmdForcePlatformType windows
    +force_install_dir "$SERVER_DIR"
    "${login_args[@]}"
    +app_update "$ACC_APP_ID" validate
    +quit
  )

  info "Загрузка ACC Dedicated Server (app id ${ACC_APP_ID}) через SteamCMD..."
  info "Это может занять длительное время в зависимости от скорости сети."

  logfile="$(mktemp)"
  if ! runuser -u "$ACC_USER" -- "${cmd[@]}" </dev/null >"$logfile" 2>&1; then
    warn "Последние строки вывода SteamCMD:"
    tail -n 30 "$logfile" >&2 || true
    rm -f "$logfile"
    die "SteamCMD завершился с ошибкой. Проверьте Steam Login/Password/Steam Guard и попробуйте снова."
  fi
  rm -f "$logfile"

  if [[ ! -f "$SERVER_DIR/accServer.exe" ]]; then
    die "После загрузки не найден accServer.exe в ${SERVER_DIR}. Установка Dedicated Server не удалась."
  fi

  info "ACC Dedicated Server установлен в ${SERVER_DIR} (OK)."
}
