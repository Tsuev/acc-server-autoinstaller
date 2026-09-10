#!/usr/bin/env bash
# shellcheck shell=bash

# =============================================================================
# acc-manager — создание системного пользователя.
# =============================================================================

ensure_user() {
  if id "$ACC_USER" >/dev/null 2>&1; then
    info "Пользователь ${ACC_USER} уже существует."
    return 0
  fi

  info "Создание пользователя ${ACC_USER}..."
  useradd -m -d "$ACC_HOME" -s /bin/bash "$ACC_USER"
  info "Пользователь ${ACC_USER} создан (домашний каталог: ${ACC_HOME})."
}
