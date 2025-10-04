#!/usr/bin/env bash
# filepath: scripts/pgbackrest/simulate-backup-cycle.sh
set -euo pipefail

# ==========================================
# CONFIGURACIÓN
# ==========================================

COMPOSE_CMD="docker compose"
if ! docker compose version &>/dev/null; then
  if command -v docker-compose &>/dev/null; then
    COMPOSE_CMD="docker-compose"
  else
    echo "❌ No se encontró docker compose" >&2
    exit 1
  fi
fi

STANZA="imdb-master1"
REDIS_SERVICE="redis"
DELAY_SECONDS=15  # Tiempo entre cada backup (simula días)

# ==========================================
# FUNCIÓN DE BACKUP
# ==========================================

function run_backup() {
  local day=$1
  local backup_type=$2
  
  echo ""
  echo "═══════════════════════════════════════════════════════"
  echo "  DÍA ${day}: Ejecutando backup ${backup_type}"
  echo "═══════════════════════════════════════════════════════"
  
  # Ejecutar backup
  if ! ${COMPOSE_CMD} exec -T "${STANZA}" bash -lc \
    "su - postgres -c 'pgbackrest --stanza=${STANZA} --type=${backup_type} --archive-check=n backup'"; then
    echo "❌ Error en backup ${backup_type} del día ${day}"
    return 1
  fi
  
  echo "✅ Backup ${backup_type} completado"
  
  # Obtener información del backup
  local info_json=$(${COMPOSE_CMD} exec -T "${STANZA}" bash -lc \
    "su - postgres -c 'pgbackrest --stanza=${STANZA} --output=json info'" | tr -d '\r')
  
  if [[ -z "${info_json// }" ]]; then
    echo "⚠️  No se pudo obtener información del backup"
    return 1
  fi
  
  # Publicar en Redis
  local last_key="pgbackrest:last:${STANZA}"
  local history_key="pgbackrest:history:${STANZA}"
  local day_key="pgbackrest:day${day}:${STANZA}"
  
  # Guardar última información
  printf '%s' "${info_json}" | ${COMPOSE_CMD} exec -T "${REDIS_SERVICE}" redis-cli -x set "${last_key}" >/dev/null
  
  # Agregar al historial
  printf '%s' "${info_json}" | ${COMPOSE_CMD} exec -T "${REDIS_SERVICE}" redis-cli -x lpush "${history_key}" >/dev/null
  
  # Guardar información específica del día
  printf '%s' "${info_json}" | ${COMPOSE_CMD} exec -T "${REDIS_SERVICE}" redis-cli -x set "${day_key}" >/dev/null
  
  # Guardar metadata del día
  ${COMPOSE_CMD} exec -T "${REDIS_SERVICE}" redis-cli hset "pgbackrest:metadata:${STANZA}" \
    "day${day}_type" "${backup_type}" \
    "day${day}_timestamp" "$(date '+%Y-%m-%d %H:%M:%S')" >/dev/null
  
  echo "📦 Información almacenada en Redis:"
  echo "   • ${last_key}"
  echo "   • ${history_key}"
  echo "   • ${day_key}"
  
  # Mostrar último backup
  echo ""
  echo "📊 Último backup registrado:"
  echo "${info_json}" | jq -r '.[0].backup[-1] | "   Tipo: \(.type)\n   Label: \(.label)\n   Inicio: \(.timestamp.start)\n   Fin: \(.timestamp.stop)"'
  
  return 0
}

# ==========================================
# CICLO DE SIMULACIÓN
# ==========================================

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║     SIMULACIÓN DE CICLO DE BACKUPS (6 DÍAS)           ║"
echo "║     Stanza: ${STANZA}                                  "
echo "║     Delay entre backups: ${DELAY_SECONDS} segundos     "
echo "╚════════════════════════════════════════════════════════╝"

# Verificar que los servicios estén corriendo
if ! ${COMPOSE_CMD} ps "${STANZA}" | grep -q "Up"; then
  echo "❌ El servicio ${STANZA} no está activo"
  exit 1
fi

if ! ${COMPOSE_CMD} ps "${REDIS_SERVICE}" | grep -q "Up"; then
  echo "❌ El servicio Redis no está activo"
  exit 1
fi

echo "✅ Servicios verificados"

# Limpiar datos anteriores de Redis (opcional)
read -p "¿Limpiar datos anteriores de Redis? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  ${COMPOSE_CMD} exec -T "${REDIS_SERVICE}" redis-cli del \
    "pgbackrest:last:${STANZA}" \
    "pgbackrest:history:${STANZA}" \
    "pgbackrest:metadata:${STANZA}" >/dev/null
  
  for i in {1..6}; do
    ${COMPOSE_CMD} exec -T "${REDIS_SERVICE}" redis-cli del "pgbackrest:day${i}:${STANZA}" >/dev/null
  done
  
  echo "🧹 Datos anteriores eliminados"
fi

# ==========================================
# DÍA 1: COMPLETO
# ==========================================
run_backup 1 "full" || exit 1
sleep ${DELAY_SECONDS}

# ==========================================
# DÍA 2: INCREMENTAL
# ==========================================
run_backup 2 "incr" || exit 1
sleep ${DELAY_SECONDS}

# ==========================================
# DÍA 3: INCREMENTAL + DIFERENCIAL
# ==========================================
run_backup 3 "incr" || exit 1
sleep ${DELAY_SECONDS}

run_backup 3 "diff" || exit 1
sleep ${DELAY_SECONDS}

# ==========================================
# DÍA 4: INCREMENTAL
# ==========================================
run_backup 4 "incr" || exit 1
sleep ${DELAY_SECONDS}

# ==========================================
# DÍA 5: INCREMENTAL + DIFERENCIAL
# ==========================================
run_backup 5 "incr" || exit 1
sleep ${DELAY_SECONDS}

run_backup 5 "diff" || exit 1
sleep ${DELAY_SECONDS}

# ==========================================
# DÍA 6: DIFERENCIAL + COMPLETO
# ==========================================
run_backup 6 "diff" || exit 1
sleep ${DELAY_SECONDS}

run_backup 6 "full" || exit 1

# ==========================================
# RESUMEN FINAL
# ==========================================

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║            SIMULACIÓN COMPLETADA EXITOSAMENTE          ║"
echo "╚════════════════════════════════════════════════════════╝"

echo ""
echo "📊 RESUMEN DE BACKUPS REALIZADOS:"
echo "═══════════════════════════════════════════════════════"

${COMPOSE_CMD} exec -T "${STANZA}" bash -lc \
  "su - postgres -c 'pgbackrest --stanza=${STANZA} info'"

echo ""
echo "📦 DATOS EN REDIS:"
echo "═══════════════════════════════════════════════════════"

echo ""
echo "🗂️  Metadata por día:"
${COMPOSE_CMD} exec -T "${REDIS_SERVICE}" redis-cli hgetall "pgbackrest:metadata:${STANZA}"

echo ""
echo "📈 Total de backups en historial:"
${COMPOSE_CMD} exec -T "${REDIS_SERVICE}" redis-cli llen "pgbackrest:history:${STANZA}"

echo ""
echo "🔑 Claves disponibles:"
${COMPOSE_CMD} exec -T "${REDIS_SERVICE}" redis-cli keys "pgbackrest:*:${STANZA}"

echo ""
echo "✅ Proceso completado"
echo ""