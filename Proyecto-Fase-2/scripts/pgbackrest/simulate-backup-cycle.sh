#!/usr/bin/env bash
# filepath: scripts/pgbackrest/simulate-backup-cycle.sh
set -euo pipefail

COMPOSE_CMD="docker compose"
if ! docker compose version &>/dev/null; then
  if command -v docker-compose &>/dev/null; then
    COMPOSE_CMD="docker-compose"
  else
    echo "No se encontró docker compose" >&2
    exit 1
  fi
fi

STANZA="imdb-master1"
REDIS_SERVICE="redis"
DELAY_SECONDS=1

# ==========================================
# FUNCIÓN PARA CONVERTIR TIMESTAMP UNIX
# ==========================================

function unix_to_date() {
  local timestamp=$1
  if [[ "$OSTYPE" == "darwin"* ]]; then
    date -r "${timestamp}" '+%Y-%m-%d %H:%M:%S'
  else
    date -d "@${timestamp}" '+%Y-%m-%d %H:%M:%S'
  fi
}

# ==========================================
# FUNCIÓN PARA FORMATEAR BYTES A GB
# ==========================================

function bytes_to_gb() {
  local bytes=$1
  awk "BEGIN {printf \"%.2f GB\", $bytes/1024/1024/1024}"
}

# ==========================================
# FUNCIÓN PARA EXTRAER VALOR DE JSON
# ==========================================

function extract_json() {
  local json=$1
  local key=$2
  echo "$json" | grep -o "\"${key}\":[^,}]*" | sed "s/\"${key}\"://g" | tr -d '"' | tr -d ' '
}

# ==========================================
# FUNCIÓN DE BACKUP ULTRA OPTIMIZADA
# ==========================================

function run_backup() {
  local day=$1
  local backup_type=$2
  
  echo ""
  echo "═══════════════════════════════════════════════════════"
  echo "  DÍA ${day}: Ejecutando backup ${backup_type} (ULTRA RÁPIDO)"
  echo "═══════════════════════════════════════════════════════"
  
  if ! ${COMPOSE_CMD} exec -T "${STANZA}" bash -lc \
    "su - postgres -c 'pgbackrest --stanza=${STANZA} \
      --type=${backup_type} \
      --start-fast \
      --stop-auto \
      backup'"; then
    echo "Error en backup ${backup_type} del día ${day}"
    return 1
  fi
  
  echo "Backup ${backup_type} completado"
  
  local info_json=$(${COMPOSE_CMD} exec -T "${STANZA}" bash -lc \
    "su - postgres -c 'pgbackrest --stanza=${STANZA} --output=json info'" | tr -d '\r' | tr -d '\n')
  
  if [[ -z "${info_json// }" ]]; then
    echo "No se pudo obtener información del backup"
    return 1
  fi
  
  # Extraer último backup (el último objeto en el array "backup")
  local last_backup=$(echo "$info_json" | grep -o '"backup":\[.*\]' | sed 's/"backup":\[//g' | sed 's/\]$//g' | awk -F'},*{' '{print $(NF)}' | sed 's/^{//g' | sed 's/}$//g')
  
  # Extraer campos
  local label=$(echo "$last_backup" | grep -o '"label":"[^"]*"' | sed 's/"label":"//g' | sed 's/"//g')
  local type=$(echo "$last_backup" | grep -o '"type":"[^"]*"' | sed 's/"type":"//g' | sed 's/"//g')
  local timestamp_start=$(echo "$last_backup" | grep -o '"timestamp":{[^}]*}' | grep -o '"start":[0-9]*' | sed 's/"start"://g')
  local timestamp_stop=$(echo "$last_backup" | grep -o '"timestamp":{[^}]*}' | grep -o '"stop":[0-9]*' | sed 's/"stop"://g')
  local size=$(echo "$last_backup" | grep -o '"info":{[^}]*"size":[0-9]*' | grep -o '"size":[0-9]*' | sed 's/"size"://g')
  local delta=$(echo "$last_backup" | grep -o '"delta":[0-9]*' | head -1 | sed 's/"delta"://g')
  local repo_size=$(echo "$last_backup" | grep -o '"repository":{[^}]*}' | grep -o '"delta":[0-9]*' | sed 's/"delta"://g')
  
  # Convertir timestamps
  local date_start=$(unix_to_date "${timestamp_start}")
  local date_stop=$(unix_to_date "${timestamp_stop}")
  
  # Calcular duración
  local duration=$((timestamp_stop - timestamp_start))
  local duration_min=$((duration / 60))
  local duration_sec=$((duration % 60))
  
  # Crear JSON simplificado
  local simplified_json=$(cat <<EOF
{
  "day": ${day},
  "label": "${label}",
  "type": "${type}",
  "fecha_inicio": "${date_start}",
  "fecha_fin": "${date_stop}",
  "duracion": "${duration_min}m ${duration_sec}s",
  "tamano_total": "$(bytes_to_gb ${size})",
  "datos_copiados": "$(bytes_to_gb ${delta})",
  "espacio_repositorio": "$(bytes_to_gb ${repo_size})",
  "timestamp_unix": {
    "inicio": ${timestamp_start},
    "fin": ${timestamp_stop}
  }
}
EOF
)
  
  echo " ${type^^} - ${label}"
  echo "    Inicio: ${date_start}"
  echo "    Duración: ${duration_min}m ${duration_sec}s"
  echo "    Tamaño: $(bytes_to_gb ${size})"
  
  local last_key="pgbackrest:last:${STANZA}"
  local history_key="pgbackrest:history:${STANZA}"
  local day_key="pgbackrest:day${day}:${STANZA}"
  local simplified_key="pgbackrest:simple:day${day}:${STANZA}"
  
  printf '%s' "${info_json}" | ${COMPOSE_CMD} exec -T "${REDIS_SERVICE}" redis-cli -x set "${last_key}" >/dev/null
  printf '%s' "${info_json}" | ${COMPOSE_CMD} exec -T "${REDIS_SERVICE}" redis-cli -x lpush "${history_key}" >/dev/null
  printf '%s' "${info_json}" | ${COMPOSE_CMD} exec -T "${REDIS_SERVICE}" redis-cli -x set "${day_key}" >/dev/null
  printf '%s' "${simplified_json}" | ${COMPOSE_CMD} exec -T "${REDIS_SERVICE}" redis-cli -x set "${simplified_key}" >/dev/null
  
  ${COMPOSE_CMD} exec -T "${REDIS_SERVICE}" redis-cli hset "pgbackrest:metadata:${STANZA}" \
    "day${day}_type" "${backup_type}" \
    "day${day}_timestamp" "$(date '+%Y-%m-%d %H:%M:%S')" \
    "day${day}_label" "${label:-N/A}" >/dev/null 2>&1 || true
  
  echo "Información almacenada en Redis (3 formatos)"
  
  return 0
}

# ==========================================
# CICLO DE SIMULACIÓN
# ==========================================

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║   SIMULACIÓN ULTRA RÁPIDA DE BACKUPS (6 DÍAS)          ║"
echo "║   Stanza: ${STANZA}                                    ║"
echo "║   Delay: ${DELAY_SECONDS}s | Fast Checkpoints | Sin Compresión"
echo "╚════════════════════════════════════════════════════════╝"

if ! ${COMPOSE_CMD} ps "${STANZA}" | grep -q "Up"; then
  echo "El servicio ${STANZA} no está activo"
  exit 1
fi

if ! ${COMPOSE_CMD} ps "${REDIS_SERVICE}" | grep -q "Up"; then
  echo "El servicio Redis no está activo"
  exit 1
fi

echo "Servicios verificados"

echo " Limpiando datos anteriores de Redis..."
${COMPOSE_CMD} exec -T "${REDIS_SERVICE}" redis-cli del \
  "pgbackrest:last:${STANZA}" \
  "pgbackrest:history:${STANZA}" \
  "pgbackrest:metadata:${STANZA}" >/dev/null 2>&1 || true

for i in {1..6}; do
  ${COMPOSE_CMD} exec -T "${REDIS_SERVICE}" redis-cli del \
    "pgbackrest:day${i}:${STANZA}" \
    "pgbackrest:simple:day${i}:${STANZA}" >/dev/null 2>&1 || true
done

echo "Redis limpio"
echo ""

start_time=$(date +%s)

run_backup 1 "full" || exit 1
sleep ${DELAY_SECONDS}

run_backup 2 "incr" || exit 1
sleep ${DELAY_SECONDS}

run_backup 3 "incr" || exit 1
sleep ${DELAY_SECONDS}

run_backup 3 "diff" || exit 1
sleep ${DELAY_SECONDS}

run_backup 4 "incr" || exit 1
sleep ${DELAY_SECONDS}

run_backup 5 "incr" || exit 1
sleep ${DELAY_SECONDS}

run_backup 5 "diff" || exit 1
sleep ${DELAY_SECONDS}

run_backup 6 "diff" || exit 1
sleep ${DELAY_SECONDS}

run_backup 6 "full" || exit 1

end_time=$(date +%s)
total_seconds=$((end_time - start_time))
total_minutes=$((total_seconds / 60))
remaining_seconds=$((total_seconds % 60))

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║           SIMULACIÓN COMPLETADA EXITOSAMENTE           ║"
echo "╚════════════════════════════════════════════════════════╝"

echo ""
echo "TIEMPO TOTAL: ${total_minutes}m ${remaining_seconds}s"
echo ""

echo "RESUMEN DE BACKUPS:"
echo "═══════════════════════════════════════════════════════"

${COMPOSE_CMD} exec -T "${STANZA}" bash -lc \
  "su - postgres -c 'pgbackrest --stanza=${STANZA} info'" | grep -E "full backup|incr backup|diff backup|timestamp|database size|repo"

echo ""
echo "Proceso completado"
echo ""