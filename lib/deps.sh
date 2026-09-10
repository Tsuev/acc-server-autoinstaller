#!/usr/bin/env bash
# shellcheck shell=bash

# =============================================================================
# acc-manager — установка системных зависимостей и SteamCMD.
# =============================================================================

install_steamcmd() {
  if [[ -x "$STEAMCMD_DIR/steamcmd.sh" ]]; then
    info "SteamCMD уже установлен (${STEAMCMD_DIR})."
    return 0
  fi

  info "Установка SteamCMD..."
  mkdir -p "$STEAMCMD_DIR"
  local tmp
  tmp="$(mktemp -d)"
  curl -fsSL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" \
    -o "$tmp/steamcmd.tar.gz"
  tar -xzf "$tmp/steamcmd.tar.gz" -C "$STEAMCMD_DIR"
  rm -rf "$tmp"
  info "SteamCMD установлен в ${STEAMCMD_DIR}."
}

install_dependencies() {
  export DEBIAN_FRONTEND=noninteractive

  info "Обновление списка пакетов..."
  apt-get update -y

  # Включаем universe (там находятся wine и прочие пакеты).
  if ! has_command add-apt-repository; then
    apt-get install -y software-properties-common
  fi
  add-apt-repository -y universe >/dev/null 2>&1 || true
  apt-get update -y

  info "Установка пакетов: wine, winbind, xvfb, unzip, curl, wget, jq, ufw..."
  apt-get install -y wine winbind xvfb unzip curl wget jq ufw

  # iconv входит в libc-bin; убедимся, что он присутствует.
  if ! has_command iconv; then
    apt-get install -y libc-bin
  fi

  install_steamcmd
}
