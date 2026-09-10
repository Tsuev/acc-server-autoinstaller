#!/usr/bin/env bash
# shellcheck shell=bash

# =============================================================================
# acc-manager — проверки системы (ОС, архитектура, диск, память, права).
# =============================================================================

# Версии Ubuntu, поддерживаемые полностью.
# shellcheck disable=SC2034
UBUNTU_SUPPORTED_VERSIONS="22.04 24.04"
# Версии, на которых установка разрешена после явного подтверждения (не тестировались).
# shellcheck disable=SC2034
UBUNTU_CONFIRM_VERSIONS="26.04"

# Проверка ОС в три уровня:
#   22.04 / 24.04 → OK;
#   26.04         → warning + запрос подтверждения;
#   иные          → отказ.
check_os() {
  local os_id os_version
  if [[ ! -f /etc/os-release ]]; then
    die "Не удалось определить операционную систему (/etc/os-release отсутствует)."
  fi
  # shellcheck source=/dev/null
  source /etc/os-release
  os_id="${ID:-}"
  os_version="${VERSION_ID:-}"

  if [[ "$os_id" != "ubuntu" ]]; then
    die "Поддерживается только Ubuntu. Обнаружено: ${os_id:-неизвестно}."
  fi

  if [[ " $UBUNTU_SUPPORTED_VERSIONS " == *" $os_version "* ]]; then
    info "ОС: ${PRETTY_NAME:-Ubuntu ${os_version}} (OK)"
    return 0
  fi

  if [[ " $UBUNTU_CONFIRM_VERSIONS " == *" $os_version "* ]]; then
    warn "ОС: ${PRETTY_NAME:-Ubuntu ${os_version}} — эта версия ещё не тестировалась с установщиком."
    warn "Установка возможна, но без гарантий: возможны отличия в пакетах wine/systemd."
    if ! confirm "Продолжить установку на Ubuntu ${os_version} на свой риск?"; then
      die "Установка отменена пользователем: непроверенная версия ОС (${os_version})."
    fi
    warn "Продолжаем на Ubuntu ${os_version} (непроверенная версия, без гарантий)."
    return 0
  fi

  die "Поддерживаются только Ubuntu 22.04 LTS и 24.04 LTS. Обнаружено: ${os_version:-неизвестно}."
}

check_arch() {
  local arch
  arch="$(uname -m)"
  case "$arch" in
    x86_64 | amd64)
      info "Архитектура: x86_64 (OK)"
      ;;
    *)
      die "Поддерживается только архитектура x86_64 (amd64). Обнаружено: $arch."
      ;;
  esac
}

check_disk() {
  local target avail_kb avail_gb
  target="$ACC_HOME"
  # Поднимаемся вверх, пока не найдём существующий каталог (для df).
  while [[ -n "$target" && ! -d "$target" ]]; do
    target="$(dirname "$target")"
  done
  [[ -n "$target" && -d "$target" ]] || target="/"

  avail_kb="$(df -k --output=avail "$target" | tail -n1 | tr -d '[:space:]')"
  avail_gb=$((avail_kb / 1024 / 1024))

  if ((avail_kb < MIN_DISK_GB * 1024 * 1024)); then
    die "Недостаточно места на диске: ${avail_gb} GB. Требуется минимум ${MIN_DISK_GB} GB."
  fi

  info "Свободное место: ${avail_gb} GB (OK)"
}

# Проверка RAM в три уровня:
#   < MIN_RAM_MB            → отказ (установка отменяется);
#   MIN_RAM_MB .. REC_RAM_MB → установка разрешена, но с предупреждением;
#   >= REC_RAM_MB           → OK.
check_ram() {
  local total_mb
  total_mb="$(awk '/MemTotal/ {print int($2 / 1024)}' /proc/meminfo)"

  if ((total_mb < MIN_RAM_MB)); then
    die "RAM ${total_mb} MB < ${MIN_RAM_MB} MB (2 GB) — установка отменена: недостаточно оперативной памяти."
  fi

  if ((total_mb < REC_RAM_MB)); then
    warn "RAM ${total_mb} MB (диапазон 2–4 GB) — установка разрешена, но объём ниже рекомендуемых ${REC_RAM_MB} MB: сервер может работать нестабильно."
  else
    info "RAM: ${total_mb} MB (>= ${REC_RAM_MB} MB, OK)"
  fi
}
