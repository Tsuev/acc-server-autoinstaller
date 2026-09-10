#!/usr/bin/env bash
# shellcheck shell=bash

# =============================================================================
# acc-manager — проверки системы (ОС, архитектура, диск, память, права).
# =============================================================================

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

  case "$os_version" in
    22.04 | 24.04) ;;
    *)
      die "Поддерживаются только Ubuntu 22.04 LTS и 24.04 LTS. Обнаружено: ${os_version:-неизвестно}."
      ;;
  esac

  info "ОС: ${PRETTY_NAME:-Ubuntu ${os_version}} (OK)"
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

check_ram() {
  local total_mb
  total_mb="$(awk '/MemTotal/ {print int($2 / 1024)}' /proc/meminfo)"

  if ((total_mb < MIN_RAM_MB)); then
    die "Недостаточно RAM: ${total_mb} MB. Требуется минимум ${MIN_RAM_MB} MB."
  fi

  if ((total_mb < 4096)); then
    warn "RAM ${total_mb} MB — ниже рекомендуемых 4096 MB, сервер может работать нестабильно."
  else
    info "RAM: ${total_mb} MB (OK)"
  fi
}
