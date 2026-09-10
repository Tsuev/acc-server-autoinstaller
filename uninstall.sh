#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# acc-manager — полное удаление ACC Dedicated Server + ACCWeb.
#
# Использование: sudo ./uninstall.sh
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=lib/firewall.sh
source "${SCRIPT_DIR}/lib/firewall.sh"
# shellcheck source=lib/systemd.sh
source "${SCRIPT_DIR}/lib/systemd.sh"

trap _error_trap ERR

confirm_uninstall() {
  cat <<'EOF'

ВНИМАНИЕ! Будет полностью удалена установка ACC Dedicated Server:
  - ACCWeb и его systemd-сервис
  - Dedicated Server (файлы сервера)
  - Wine prefix
  - SteamCMD (по желанию)
  - пользователь acc и его домашняя директория
  - правила UFW, созданные установщиком

EOF
  local answer
  read -r -p "Введите 'yes' для подтверждения удаления: " answer
  if [[ "$answer" != "yes" ]]; then
    info "Удаление отменено."
    exit 0
  fi
}

remove_steamcmd_optional() {
  local answer
  read -r -p "Удалить SteamCMD? [Y/n]: " answer
  case "$answer" in
    n | N | no | NO | No | нет | Нет | НЕТ | н | Н)
      if [[ -d "$STEAMCMD_DIR" ]]; then
        mkdir -p /opt
        mv "$STEAMCMD_DIR" "/opt/steamcmd" 2>/dev/null \
          && info "SteamCMD сохранён в /opt/steamcmd." \
          || warn "Не удалось переместить SteamCMD в /opt/steamcmd."
      fi
      ;;
    *)
      rm -rf "$STEAMCMD_DIR"
      info "SteamCMD удалён."
      ;;
  esac
}

remove_dirs() {
  local dir
  for dir in "$ACCWEB_DIR" "$SERVER_DIR" "$WINE_PREFIX"; do
    if [[ -n "$dir" && -d "$dir" ]]; then
      rm -rf "$dir"
      info "Удалено: $dir"
    fi
  done
}

remove_user() {
  if id "$ACC_USER" >/dev/null 2>&1; then
    pkill -u "$ACC_USER" 2>/dev/null || true
    sleep 1
    userdel -r "$ACC_USER" 2>/dev/null || userdel "$ACC_USER"
    info "Пользователь ${ACC_USER} и его домашняя директория удалены."
  else
    info "Пользователь ${ACC_USER} не найден."
  fi
}

main() {
  init_logging
  require_root
  load_state

  # Значения по умолчанию на случай отсутствия state-файла.
  ACC_USER="${ACC_USER:-acc}"
  ACC_HOME="${ACC_HOME:-/home/${ACC_USER}}"
  SERVER_DIR="${SERVER_DIR:-${ACC_HOME}/acc-server}"
  ACCWEB_DIR="${ACCWEB_DIR:-${ACC_HOME}/accweb}"
  WINE_PREFIX="${WINE_PREFIX:-${ACC_HOME}/.wine}"
  STEAMCMD_DIR="${STEAMCMD_DIR:-${ACC_HOME}/steamcmd}"
  SERVICE_NAME="${SERVICE_NAME:-accweb}"
  TCP_PORT="${TCP_PORT:-9600}"
  UDP_PORT="${UDP_PORT:-9600}"
  WEB_PORT="${WEB_PORT:-8080}"

  confirm_uninstall

  # Остановить и удалить systemd-сервис.
  stop_and_remove_service

  # Удалить правила UFW.
  remove_firewall_rules

  # Удалить каталоги установки.
  remove_dirs

  # SteamCMD (по желанию).
  remove_steamcmd_optional

  # Удалить пользователя и его домашнюю директорию.
  remove_user

  # Удалить файл состояния.
  rm -f "$STATE_FILE"

  info "Удаление завершено. Система очищена."
}

main "$@"
