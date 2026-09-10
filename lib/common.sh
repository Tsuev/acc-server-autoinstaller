#!/usr/bin/env bash
# shellcheck shell=bash

# =============================================================================
# acc-manager — общие функции, константы и логирование.
#
# Этот файл подключается (source) скриптами install.sh и uninstall.sh.
# Он не должен содержать исполняемого кода верхнего уровня, только определения.
# =============================================================================

# -----------------------------------------------------------------------------
# Пути и константы (можно переопределить переменными окружения).
# -----------------------------------------------------------------------------
# shellcheck disable=SC2034
ACC_USER="${ACC_USER:-acc}"
ACC_HOME="${ACC_HOME:-/home/${ACC_USER}}"
SERVER_DIR="${SERVER_DIR:-${ACC_HOME}/acc-server}"
ACCWEB_DIR="${ACCWEB_DIR:-${ACC_HOME}/accweb}"
ACCWEB_CONFIG_DIR="${ACCWEB_CONFIG_DIR:-${ACCWEB_DIR}/config}"
WINE_PREFIX="${WINE_PREFIX:-${ACC_HOME}/.wine}"
STEAMCMD_DIR="${STEAMCMD_DIR:-${ACC_HOME}/steamcmd}"

# Идентификатор Steam-приложения ACC Dedicated Server.
ACC_APP_ID="${ACC_APP_ID:-1430110}"
# Репозиторий ACCWeb на GitHub.
ACCWEB_REPO="${ACCWEB_REPO:-assetto-corsa-web/accweb}"

# Имя systemd-сервиса.
SERVICE_NAME="${SERVICE_NAME:-accweb}"

# Файл состояния и лог-файл.
STATE_FILE="${STATE_FILE:-/etc/acc-manager/state}"
LOG_FILE="${LOG_FILE:-/var/log/acc-manager.log}"

# Порты по умолчанию.
DEFAULT_TCP_PORT="${DEFAULT_TCP_PORT:-9600}"
DEFAULT_UDP_PORT="${DEFAULT_UDP_PORT:-9600}"
DEFAULT_WEB_PORT="${DEFAULT_WEB_PORT:-8080}"

# Минимальные системные требования (переопределяются переменными окружения).
# MIN_DISK_GB — «санитарный» порог: минимальный объём свободного места для старта.
MIN_DISK_GB="${MIN_DISK_GB:-3}"
# MIN_RAM_MB — жёсткий минимум (меньше — отказ), REC_RAM_MB — рекомендуемый объём.
MIN_RAM_MB="${MIN_RAM_MB:-2048}"
REC_RAM_MB="${REC_RAM_MB:-4096}"

# -----------------------------------------------------------------------------
# Цвета (отключаются, если вывод не в терминал).
# -----------------------------------------------------------------------------
if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'
  C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'
  C_BOLD=$'\033[1m'
else
  C_RESET=''
  C_RED=''
  C_GREEN=''
  C_YELLOW=''
  C_BLUE=''
  C_BOLD=''
fi

# -----------------------------------------------------------------------------
# Логирование.
# -----------------------------------------------------------------------------

init_logging() {
  mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
  : >>"$LOG_FILE" 2>/dev/null || true
}

log() {
  printf '%s\n' "$*" >>"$LOG_FILE" 2>/dev/null || true
}

info() {
  printf '%b[INFO]%b %s\n' "$C_BLUE" "$C_RESET" "$*"
  log "[INFO] $*"
}

warn() {
  printf '%b[WARN]%b %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2
  log "[WARN] $*"
}

error() {
  printf '%b[ERROR]%b %s\n' "$C_RED" "$C_RESET" "$*" >&2
  log "[ERROR] $*"
}

die() {
  error "$*"
  exit 1
}

# Обработчик неожиданных ошибок (устанавливается в entrypoint через trap).
_error_trap() {
  local rc=$?
  error "Неожиданная ошибка (код $rc) в ${BASH_SOURCE[1]}:${BASH_LINENO[0]}"
  exit "$rc"
}

# -----------------------------------------------------------------------------
# Системные проверки и помощники.
# -----------------------------------------------------------------------------

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    die "Требуются права root. Запустите: sudo $0"
  fi
}

has_command() {
  command -v "$1" >/dev/null 2>&1
}

# Выполнить команду от имени пользователя ACC_USER.
run_as_acc() {
  runuser -u "$ACC_USER" -- "$@"
}

# Выполнить команду от имени ACC_USER с переменными окружения Wine.
# ВАЖНО: все аргументы "$@" должны быть ИСПОЛНЯЕМЫМИ командами (env/timeout/
# xvfb-run/wineboot/...), а не shell-функциями — иначе `timeout` внутри цепочки
# не сможет их запустить (exec: not found).
run_as_acc_wine() {
  runuser -u "$ACC_USER" -- env \
    "WINEPREFIX=${WINE_PREFIX}" \
    "WINEARCH=win64" \
    "WINEDEBUG=-all" \
    "WINEDLLOVERRIDES=mscoree,mshtml=" \
    "$@"
}

# -----------------------------------------------------------------------------
# Ввод данных от пользователя.
# -----------------------------------------------------------------------------

ask() {
  local prompt="$1" var_name="$2" answer
  while true; do
    read -r -p "${prompt}: " answer
    if [[ -n "$answer" ]]; then
      break
    fi
    warn "Значение не может быть пустым."
  done
  printf -v "$var_name" '%s' "$answer"
}

ask_secret() {
  local prompt="$1" var_name="$2" answer
  while true; do
    read -r -s -p "${prompt}: " answer
    printf '\n'
    if [[ -n "$answer" ]]; then
      break
    fi
    warn "Значение не может быть пустым."
  done
  printf -v "$var_name" '%s' "$answer"
}

ask_default() {
  local prompt="$1" default="$2" var_name="$3" answer
  read -r -p "${prompt} [${default}]: " answer
  printf -v "$var_name" '%s' "${answer:-$default}"
}

# -----------------------------------------------------------------------------
# Генерация паролей и работа со строками.
# -----------------------------------------------------------------------------

generate_password() {
  local len="${1:-24}" result
  result="$(head -c "$len" /dev/urandom | base64 | tr -dc 'A-Za-z0-9')"
  result="${result:0:len}"
  printf '%s\n' "$result"
}

# Экранировать строку для YAML в одинарных кавычках (удвоение одинарных кавычек).
yaml_sq_escape() {
  local s="$1"
  s="${s//\'/\'\'}"
  printf '%s' "$s"
}

# Подставить плейсхолдеры __KEY__ в файл-шаблон и записать результат.
# Использование: render_template <template> <output> "KEY=value" ["KEY2=value2" ...]
render_template() {
  local template="$1" out="$2" content pair key value
  shift 2
  content="$(<"$template")"
  for pair in "$@"; do
    key="${pair%%=*}"
    value="${pair#*=}"
    content="${content//__${key}__/${value}}"
  done
  printf '%s\n' "$content" >"$out"
}

# -----------------------------------------------------------------------------
# JSON в кодировке UTF-16LE с BOM (формат конфигурации ACC Dedicated Server).
# -----------------------------------------------------------------------------

# Записать JSON-строку (UTF-8) в файл в кодировке UTF-16LE с BOM.
json_write_utf16le() {
  local file="$1" json="$2"
  {
    printf '\xff\xfe'
    printf '%s' "$json" | iconv -f UTF-8 -t UTF-16LE
  } >"$file"
}

# Скопировать UTF-8 файл в UTF-16LE (с BOM).
json_copy_utf16le() {
  local src="$1" dst="$2"
  {
    printf '\xff\xfe'
    iconv -f UTF-8 -t UTF-16LE "$src"
  } >"$dst"
}

# Прочитать UTF-16LE файл и вывести содержимое в UTF-8.
json_read_utf8() {
  iconv -f UTF-16 -t UTF-8 "$1"
}

# Проверить, что файл содержит валидный JSON (поддерживает UTF-16LE и UTF-8).
json_validate() {
  local file="$1"
  if iconv -f UTF-16 -t UTF-8 "$file" 2>/dev/null | jq -e . >/dev/null 2>&1; then
    return 0
  fi
  jq -e . <"$file" >/dev/null 2>&1
}

# -----------------------------------------------------------------------------
# Состояние установки.
# -----------------------------------------------------------------------------

save_state() {
  mkdir -p "$(dirname "$STATE_FILE")"
  {
    printf 'ACC_USER=%s\n' "$ACC_USER"
    printf 'ACC_HOME=%s\n' "$ACC_HOME"
    printf 'SERVER_DIR=%s\n' "$SERVER_DIR"
    printf 'ACCWEB_DIR=%s\n' "$ACCWEB_DIR"
    printf 'WINE_PREFIX=%s\n' "$WINE_PREFIX"
    printf 'STEAMCMD_DIR=%s\n' "$STEAMCMD_DIR"
    printf 'SERVICE_NAME=%s\n' "$SERVICE_NAME"
    printf 'TCP_PORT=%s\n' "${TCP_PORT:-$DEFAULT_TCP_PORT}"
    printf 'UDP_PORT=%s\n' "${UDP_PORT:-$DEFAULT_UDP_PORT}"
    printf 'WEB_PORT=%s\n' "${WEB_PORT:-$DEFAULT_WEB_PORT}"
  } >"$STATE_FILE"
  chmod 600 "$STATE_FILE"
}

load_state() {
  if [[ -f "$STATE_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$STATE_FILE"
  fi
}
