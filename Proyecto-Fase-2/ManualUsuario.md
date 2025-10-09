# Manual de Usuario
## Sistema de Base de Datos IMDB con Alta Disponibilidad

**Universidad San Carlos de Guatemala**  
**Proyecto Fase 2 - Bases de Datos 2**  

 
---

## Tabla de Contenidos

1. [Introducción](#introducción)
2. [Requisitos](#requisitos)
3. [Instalación del Sistema](#instalación-del-sistema)
4. [Uso de la API](#uso-de-la-api)
5. [Verificación de Backups](#verificación-de-backups)
6. [Pruebas de Failover](#pruebas-de-failover)
7. [Solución de Problemas](#solución-de-problemas)

---

## 1. Introducción

Este sistema implementa una arquitectura de base de datos de alta disponibilidad para la gestión de información de IMDB (Internet Movie Database). El sistema cuenta con:

- **Replicación Maestro-Maestro** entre dos servidores PostgreSQL
- **Backups automáticos** (completos, diferenciales e incrementales)
- **Sistema de caché Redis** para registro de backups
- **API REST** para inserción de datos con failover automático

### ¿Para qué sirve este sistema?

- Garantiza disponibilidad continua del servicio
- Protege los datos mediante backups automáticos
- Permite recuperación rápida ante fallos
- Optimiza consultas mediante Redis

---

## 2. Requisitos

Antes de comenzar, asegúrese de tener instalado:

- **Docker** (versión 20.10 o superior)
- **Docker Compose** (versión 2.0 o superior)
- **Node.js** (versión 16 o superior)
- **npm** (versión 7 o superior)
- **Python 3.8+** (para pruebas con Locust - opcional)
- **curl** (para pruebas de API)

### Verificar instalaciones:

```bash
docker --version
docker compose version
node --version
npm --version
python3 --version
```

---

## 3. Instalación del Sistema

### Paso 1: Clonar o descargar el proyecto

```bash
cd Proyecto-Fase-2
```

### Paso 2: Levantar la infraestructura

```bash
docker compose up -d
```

Este comando levantará:
- PostgreSQL Master 1 (puerto 5432)
- PostgreSQL Master 2 (puerto 5433)
- Redis (puerto 6379)
- Servicio de configuración de replicación (temporal)

### Paso 3: Verificar que los contenedores estén corriendo

```bash
docker ps
```

Debe haber al menos 3 contenedores activos:
- `imdb-master1`
- `imdb-master2`
- `imdb-redis`

**Nota:** El contenedor `replication-setup` se ejecuta una vez y se detiene automáticamente después de configurar la replicación bidireccional.

### Paso 4: Configurar pgBackRest

```bash
./scripts/pgbackrest/bootstrap.sh
```

Este script configura el sistema de backups automáticos.

### Paso 5: Iniciar la API

```bash
cd API
npm install
npm start
```

La API estará disponible en: `http://localhost:5000`

---

## 4. Uso de la API

### 4.1 Verificar estado del sistema

**Endpoint:** `GET /health`

```bash
curl http://localhost:5000/health
```

**Respuesta exitosa:**
```json
{
  "status": "ok",
  "database": "connected",
  "active_node": "primary"
}
```

### 4.2 Ver nodo activo

**Endpoint:** `GET /active-node`

```bash
curl http://localhost:5000/active-node
```

**Respuesta:**
```json
{
  "active_node": "primary",
  "host": "postgres1",
  "port": 5432
}
```

### 4.3 Insertar un nuevo género

**Endpoint:** `POST /generos`

```bash
curl -X POST http://localhost:5000/generos \
  -H "Content-Type: application/json" \
  -d '{"genero":"Rock Nacional"}'
```

**Respuesta exitosa:**
```json
{
  "ok": true,
  "data": {
    "id_genero": 1,
    "genero": "Rock Nacional"
  },
  "node_used": "primary"
}
```

### 4.4 Cambiar manualmente entre maestros

**Cambiar a Master 1:**
```bash
curl -X POST http://localhost:5000/switch-to-primary
```

**Cambiar a Master 2:**
```bash
curl -X POST http://localhost:5000/switch-to-secondary
```

---

## 5. Verificación de Backups

### 5.1 Ver backups registrados en Redis

```bash
docker exec -it imdb-redis redis-cli KEYS "pgbackrest:*"
```

### 5.2 Ver detalles de un backup específico

```bash
docker exec -it imdb-redis redis-cli GET "pgbackrest:backup:20251007-120000"
```

**Ejemplo de respuesta:**
```json
{
  "timestamp": "2025-10-07T12:00:00Z",
  "type": "full",
  "location": "/backups/master1/20251007-120000F",
  "size": "256MB",
  "status": "completed"
}
```

### 5.3 Ver información de backups con pgBackRest

```bash
./scripts/pgbackrest/show-info.sh
```

---

## 6. Pruebas de Failover

### 6.1 Prueba de Failover Automático

**Paso 1:** Verificar que la API esté funcionando
```bash
curl http://localhost:5000/health
```

**Paso 2:** Insertar un dato de prueba
```bash
curl -X POST http://localhost:5000/generos \
  -H "Content-Type: application/json" \
  -d '{"genero":"Prueba Failover"}'
```

**Paso 3:** Simular falla del Master 1
```bash
docker stop imdb-master1
```

**Paso 4:** Intentar insertar otro dato
```bash
curl -X POST http://localhost:5000/generos \
  -H "Content-Type: application/json" \
  -d '{"genero":"Durante Failover"}'
```

✅ **Resultado esperado:** La inserción debe ser exitosa usando el Master 2 automáticamente.

**Paso 5:** Verificar nodo activo
```bash
curl http://localhost:5000/active-node
```

Debería mostrar: `"active_node": "secondary"`

### 6.2 Prueba de Failback

**Paso 1:** Recuperar Master 1
```bash
docker start imdb-master1
```

**Paso 2:** Esperar sincronización (5-10 segundos)

**Paso 3:** Cambiar manualmente al Master 1
```bash
curl -X POST http://localhost:5000/switch-to-primary
```

**Paso 4:** Verificar
```bash
curl http://localhost:5000/active-node
```

Debería mostrar: `"active_node": "primary"`

### 6.3 Prueba con Locust (Carga de Trabajo)

Si tiene Python y Locust instalados:

**Paso 1:** Ejecutar Locust
```bash
python -m locust -f locustfile.py -H http://localhost:5000 --headless -u 10 -r 2 -t 2m
```

**Paso 2:** Durante la ejecución, simular failover
```bash
docker stop imdb-master1
```

**Paso 3:** Observar en los logs que las peticiones continúan sin errores

---

## 7. Solución de Problemas

### Problema: "Cannot connect to database"

**Solución:**
```bash
# Verificar que los contenedores estén corriendo
docker ps

# Si no están activos, levantarlos
docker compose up -d

# Esperar 10 segundos para que PostgreSQL inicie completamente
```

### Problema: "API no responde en puerto 5000"

**Solución:**
```bash
# Verificar que la API esté corriendo
cd API
npm start

# Verificar que el puerto no esté ocupado
lsof -i :5000
```

### Problema: "Backup failed"

**Solución:**
```bash
# Verificar configuración de pgBackRest
./scripts/pgbackrest/bootstrap.sh

# Verificar permisos de carpetas
sudo chown -R postgres:postgres /backups
```

### Problema: "Failover no funciona automáticamente"

**Solución:**
```bash
# Verificar que ambos masters estén configurados correctamente
docker logs imdb-master1
docker logs imdb-master2

# Reiniciar la API
cd API
npm restart
```

### Problema: "Redis no guarda datos"

**Solución:**
```bash
# Verificar que Redis esté corriendo
docker exec -it imdb-redis redis-cli PING

# Debería responder: PONG

# Si no responde, reiniciar Redis
docker restart imdb-redis
```

---

