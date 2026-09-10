#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# acc-manager — установщик Assetto Corsa Competizione Dedicated Server.
#
# Использование: sudo ./install.sh
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
TEMPLATE_DIR="${SCRIPT_DIR}/templates"

# shellcheck source=lib/common.sh
source "${LIB_DIR}/common.sh"
# shellcheck source=lib/checks.sh
source "${LIB_DIR}/checks.sh"
# shellcheck source=lib/deps.sh
source "${LIB_DIR}/deps.sh"
# shellcheck source=lib/user.sh
source "${LIB_DIR}/user.sh"
# shellcheck source=lib/wine.sh
source "${LIB_DIR}/wine.sh"
# shellcheck source=lib/steam.sh
source "${LIB_DIR}/steam.sh"
# shellcheck source=lib/accweb.sh
source "${LIB_DIR}/accweb.sh"
# shellcheck source=lib/config.sh
source "${LIB_DIR}/config.sh"
# shellcheck source=lib/firewall.sh
source "${LIB_DIR}/firewall.sh"
# shellcheck source=lib/systemd.sh
source "${LIB_DIR}/systemd.sh"
# shellcheck source=lib/report.sh
source "${LIB_DIR}/report.sh"

trap _error_trap ERR

banner() {
  cat <<'EOF'
============================================================
  acc-manager — установка ACC Dedicated Server + ACCWeb
============================================================
EOF
}

# Сбор параметров установки (переопределяются переменными окружения).
gather_config() {
  SERVER_NAME="${SERVER_NAME:-}"
  [[ -n "$SERVER_NAME" ]] || ask_default "Имя сервера" "ACC Dedicated Server" SERVER_NAME

  TCP_PORT="${TCP_PORT:-}"
  [[ -n "$TCP_PORT" ]] || ask_default "Игровой TCP-порт" "$DEFAULT_TCP_PORT" TCP_PORT

  UDP_PORT="${UDP_PORT:-}"
  [[ -n "$UDP_PORT" ]] || ask_default "Игровой UDP-порт" "$DEFAULT_UDP_PORT" UDP_PORT

  WEB_PORT="${WEB_PORT:-}"
  [[ -n "$WEB_PORT" ]] || ask_default "Порт панели ACCWeb" "$DEFAULT_WEB_PORT" WEB_PORT

  ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"
  [[ -n "$ADMIN_PASSWORD" ]] || ask_secret "Пароль администратора ACCWeb" ADMIN_PASSWORD

  local p
  for p in "$TCP_PORT" "$UDP_PORT" "$WEB_PORT"; do
    if [[ ! "$p" =~ ^[0-9]+$ ]] || ((p < 1 || p > 65535)); then
      die "Некорректный порт: $p"
    fi
  done

  MOD_PASSWORD="$(generate_password 24)"
  RO_PASSWORD="$(generate_password 24)"
}

# Сбор учётных данных Steam (Steam Guard запрашивается непосредственно перед входом).
gather_steam_creds() {
  STEAM_USER="${STEAM_USER:-}"
  [[ -n "$STEAM_USER" ]] || ask "Steam Login (имя пользователя)" STEAM_USER

  STEAM_PASS="${STEAM_PASS:-}"
  [[ -n "$STEAM_PASS" ]] || ask_secret "Steam Password" STEAM_PASS

  STEAM_GUARD="${STEAM_GUARD:-}"
  if [[ -z "$STEAM_GUARD" ]]; then
    local has_guard
    read -r -p "Включён ли Steam Guard (двухфакторная защита)? [y/N]: " has_guard
    case "${has_guard,,}" in
      y | yes | д | да)
        ask_secret "Steam Guard код" STEAM_GUARD
        ;;
    esac
  fi
}

main() {
  init_logging
  require_root
  banner

  # 1. Проверки системы.
  check_os
  check_arch
  check_disk
  check_ram

  # Сбор параметров.
  gather_config

  # Сохраняем состояние как можно раньше — чтобы uninstall мог очистить систему
  # даже в случае прерывания установки.
  save_state

  # 2. Установка зависимостей.
  install_dependencies

  # 3. Создание пользователя.
  ensure_user

  # 4. Настройка Wine.
  setup_wine_prefix

  # 5. Авторизация Steam.
  gather_steam_creds

  # 6. Загрузка Dedicated Server.
  steam_download_server "$STEAM_USER" "$STEAM_PASS" "$STEAM_GUARD"

  # 7. Загрузка ACCWeb.
  download_accweb

  # 8. Настройка ACCWeb.
  configure_accweb "$WEB_PORT" "$ADMIN_PASSWORD" "$MOD_PASSWORD" "$RO_PASSWORD"

  # 9-11. Настройка Dedicated Server (configuration.json / settings.json).
  configure_dedicated_server "$SERVER_NAME" "$ADMIN_PASSWORD" "$TCP_PORT" "$UDP_PORT"

  # 12. Межсетевой экран.
  configure_firewall "$TCP_PORT" "$UDP_PORT" "$WEB_PORT"

  # 13. systemd-сервис.
  create_service
  start_service

  # 14. Проверка запуска.
  verify_install "$WEB_PORT" "$ADMIN_PASSWORD"

  # 15. Финальный отчёт.
  print_report "$WEB_PORT" "$ADMIN_PASSWORD" "$TCP_PORT" "$UDP_PORT"
}

main "$@"
