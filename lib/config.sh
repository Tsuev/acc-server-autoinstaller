#!/usr/bin/env bash
# shellcheck shell=bash

# =============================================================================
# acc-manager — конфигурация ACC Dedicated Server (UTF-16LE JSON).
# =============================================================================

# Linux compatibility patch: гарантировать наличие параметра
# "ignorePrematureDisconnects": 0 в settings.json (без дубликатов).
ensure_ignore_premature_disconnects() {
  local file="$1" decoded patched
  [[ -f "$file" ]] || return 0

  decoded="$(json_read_utf8 "$file")"
  patched="$(printf '%s' "$decoded" | jq -c 'if has("ignorePrematureDisconnects") then . else . + {"ignorePrematureDisconnects": 0} end')"

  if [[ "$patched" != "$decoded" ]]; then
    json_write_utf16le "$file" "$patched"
    info "Добавлен параметр ignorePrematureDisconnects: 0 в $(basename "$file")."
  fi
}

# Создать (или обновить без затирания) конфигурацию экземпляра Dedicated Server.
configure_dedicated_server() {
  local server_name="$1" admin_password="$2" tcp_port="$3" udp_port="$4"
  local inst_dir="$ACCWEB_CONFIG_DIR/default"

  mkdir -p "$inst_dir"
  chown -R "$ACC_USER":"$ACC_USER" "$ACCWEB_CONFIG_DIR" 2>/dev/null || true

  # configuration.json — создаём только если отсутствует (не затираем на повторной установке).
  if [[ ! -f "$inst_dir/configuration.json" ]]; then
    local cfg_json
    cfg_json="$(jq -nc \
      --argjson udp "$udp_port" \
      --argjson tcp "$tcp_port" \
      '{configVersion: 1, udpPort: $udp, tcpPort: $tcp, maxConnections: 500, registerToLobby: 1, lanDiscovery: 1, publicIP: ""}')"
    json_write_utf16le "$inst_dir/configuration.json" "$cfg_json"
    info "Создан configuration.json (TCP ${tcp_port}, UDP ${udp_port})."
  fi

  # settings.json
  if [[ ! -f "$inst_dir/settings.json" ]]; then
    local set_json
    set_json="$(jq -nc \
      --arg name "$server_name" \
      --arg admin "$admin_password" \
      '{configVersion: 1, serverName: $name, password: "", adminPassword: $admin, spectatorPassword: "", trackMedalsRequirement: 0, safetyRatingRequirement: -1, racecraftRatingRequirement: -1, ignorePrematureDisconnects: 0, dumpLeaderboards: 1, isRaceLocked: 0, randomizeTrackWhenEmpty: 0, maxCarSlots: 30, centralEntryListPath: "", shortFormationLap: 0, allowAutoDQ: 0, dumpEntryList: 0, formationLapType: 3, carGroup: "FreeForAll"}')"
    json_write_utf16le "$inst_dir/settings.json" "$set_json"
    info "Создан settings.json."
  else
    ensure_ignore_premature_disconnects "$inst_dir/settings.json"
  fi

  # Статические конфигурационные файлы (создаём только если отсутствуют).
  local name
  for name in event.json eventRules.json entrylist.json bop.json assistRules.json; do
    if [[ ! -f "$inst_dir/$name" ]]; then
      json_copy_utf16le "$TEMPLATE_DIR/$name" "$inst_dir/$name"
    fi
  done

  # accwebConfig.json — метаданные экземпляра ACCWeb (автозапуск включён).
  if [[ ! -f "$inst_dir/accwebConfig.json" ]]; then
    local now accweb_json
    now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    accweb_json="$(jq -nc \
      --arg id "$(basename "$inst_dir")" \
      --arg now "$now" \
      '{id: $id, md5Sum: "", autoStart: false, settings: {autoStart: true, enableAdvWindowsCfg: false, advWindowsCfg: null, enableGlobalEntrylist: false, enableGlobalBanlist: false}, createdAt: $now, updatedAt: $now}')"
    json_write_utf16le "$inst_dir/accwebConfig.json" "$accweb_json"
    info "Создан accwebConfig.json (autoStart: true)."
  fi

  # Валидация всех JSON. Некорректный JSON — фатальная ошибка.
  local f
  for f in "$inst_dir"/*.json; do
    [[ -f "$f" ]] || continue
    if ! json_validate "$f"; then
      die "Некорректный JSON: ${f}. Установка прервана."
    fi
  done

  info "Все конфигурационные JSON валидны (UTF-16LE, OK)."
}
