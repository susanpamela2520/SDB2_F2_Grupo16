#!/usr/bin/env bash
set -euo pipefail

COMPOSE_CMD="docker compose"
if ! command -v docker &>/dev/null; then
  echo "docker no está instalado" >&2
  exit 1
fi

if ! docker compose version &>/dev/null; then
  if command -v docker-compose &>/dev/null; then
    COMPOSE_CMD="docker-compose"
  else
    echo "No se encontró docker compose" >&2
    exit 1
  fi
fi

containers=("imdb-master1" "imdb-master1")

for container in "${containers[@]}"; do
  echo "== Configurando ${container} =="
  ${COMPOSE_CMD} exec -T -u root "${container}" bash -lc "set -e; \
    if ! command -v pgbackrest >/dev/null 2>&1; then \
      apt-get update >/dev/null && \
      DEBIAN_FRONTEND=noninteractive apt-get install -y pgbackrest >/dev/null; \
    fi; \
    mkdir -p /var/lib/pgbackrest /var/lib/pgbackrest/spool; \
    chown -R postgres:postgres /var/lib/pgbackrest; \
    chmod 750 /var/lib/pgbackrest; \
    su - postgres -c 'pgbackrest --stanza=${container} --log-level-console=info stanza-create --force'; \
    if ! su - postgres -c 'pgbackrest --stanza=${container} --archive-check=n check'; then \
      echo 'Aviso: pgBackRest check falló (posiblemente primera ejecución sin WAL archivados). Ejecuta un backup full y vuelve a intentar.'; \
    fi"
done

echo "Bootstrap completado"
