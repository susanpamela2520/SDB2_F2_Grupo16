# Bitácora de Trabajo
## Proyecto Fase 2 - Sistema IMDB con Alta Disponibilidad

**Universidad:** San Carlos de Guatemala  
**Curso:** Bases de Datos 2  
**Grupo:** 16  
---

## Información del Equipo

| Nombre | Carnet |  
|----------------------------|--------| 
| [Josué Nabí Hurtarte Pinto] | [202202481] |  
| [Naomi Rashel Yos Cujcuj] | [202001814]   
| [Susan Pamela Herrera Monzon] | [201612218]   

---

## Registro de Actividades por Semana

### Semana 1: Planificación y Configuración Inicial 

| Fecha | Actividad | Responsable(s) | Tiempo | Observaciones |
|-------|-----------|----------------|--------|---------------|
| 17/09 | Reunión inicial y análisis del proyecto | Todo el equipo | 2h | Definición de roles y tecnologías a usar |
| 18/09 | Diseño de arquitectura maestro-maestro | Todo el equipo | 2h | Se decidió usar replicación lógica nativa de PostgreSQL 16 |
| 19/09 | Creación de docker-compose.yml | [Josué Nabí] | 4h | Configuración con 2 PostgreSQL + Redis + servicio de replicación automática |
| 20/09 | Primera prueba de levantamiento | [Josué Nabí] | 2h | Contenedores funcionando correctamente |

**Total:** 10 horas

---

### Semana 2: Implementación de Replicación Maestro-Maestro 

| Fecha | Actividad | Responsable(s) | Tiempo | Observaciones |
|-------|-----------|----------------|--------|---------------|
| 23/09 | Investigación replicación lógica PostgreSQL 16 | [Susan Herrera] | 3h | Se decidió usar publications/subscriptions nativas en lugar de pglogical |
| 24/09 | Creación de archivos de configuración PostgreSQL | [Susan Herrera] | 3h | master1.conf y master2.conf con parámetros de replicación lógica habilitados |
| 24/09 | Configuración de pg_hba.conf | [Susan Herrera] | 1h | Permisos para replicación desde cualquier IP |
| 25/09 | **Desarrollo servicio replication-setup** | [Josué Nabí] | 5h | **Script bash automatizado que configura replicación bidireccional al iniciar contenedores** |
| 26/09 | **Implementación de publications** | [Susan Herrera] | 3h | **Creación de `pub_imdb` en ambos masters para publicar todos los cambios** |
| 26/09 | **Implementación de subscriptions bidireccionales** | [Josué Nabí] | 4h | **Master1 se suscribe a Master2 y viceversa. Parámetro `origin='none'` previene bucles** |
| 27/09 | **Pruebas de replicación bidireccional** | Todo el equipo | 3h | **Inserción en M1 replica a M2, inserción en M2 replica a M1. ✅ Exitoso** |
| 27/09 | Implementación de healthchecks | [Josué Nabí] | 2h | pg_isready asegura que PostgreSQL esté listo antes de configurar replicación |

**Total:** 24 horas

**🔑 Aspectos clave de la replicación maestro-maestro:**

1. **Usuario replicator:** Se creó con permisos de `LOGIN` y `REPLICATION`
2. **Publications:** Cada master publica TODAS las tablas con `CREATE PUBLICATION pub_imdb FOR ALL TABLES`
3. **Subscriptions:** Cada master se suscribe a la publicación del otro
4. **Prevención de bucles:** Parámetro `origin='none'` evita que cambios replicados se vuelvan a replicar
5. **Slots de replicación:** `slot_1_to_2` y `slot_2_to_1` garantizan entrega confiable de cambios
6. **Sincronización automática:** Al iniciar contenedores, el servicio `replication-setup` configura todo automáticamente

---

### Semana 3: Sistema de Backups con pgBackRest 

| Fecha | Actividad | Responsable(s) | Tiempo | Observaciones |
|-------|-----------|----------------|--------|---------------|
| 30/09 | Investigación y selección de pgBackRest | [Naomi Rashel] | 2h | Elegido por soporte de backups incrementales/diferenciales |
| 01/10 | Configuración de pgbackrest.conf | [Naomi Rashel] | 3h | Configurado para ambos masters con retención: 2 full, 7 diff, 14 incr |
| 02/10 | Desarrollo de script bootstrap.sh | [Josué Nabí] | 2h | Inicializa stanzas y crea primer backup full |
| 03/10 | Desarrollo de scripts de automatización | [Josué Nabí] | 4h | run-backup.sh, show-info.sh, simulate-backup-cycle.sh |
| 04/10 | Pruebas de backups (full, diff, incr) | Todo el equipo | 3h | Todos los tipos funcionando correctamente |
| 04/10 | Pruebas de restauración | Todo el equipo | 2h | Restauración exitosa desde diferentes tipos de backup |

**Total:** 16 horas

---

### Semana 4: API, Redis y Failover 

| Fecha | Actividad | Responsable(s) | Tiempo | Observaciones |
|-------|-----------|----------------|--------|---------------|
| 05/10 | Configuración de Redis para metadata | [Josué Nabí] | 2h | Redis Alpine integrado en docker-compose |
| 05/10 | Integración Redis con scripts de backup | [Josué Nabí] | 3h | Metadata de backups se registra automáticamente |
| 06/10 | Desarrollo de API con Express | [Naomi Rashel] | 4h | Endpoints básicos y conexión a PostgreSQL |
| 07/10 | **Implementación de lógica de failover** | [Naomi Rashel] | 5h | **Función executeWithFailover() con try-catch y cambio automático entre masters** |
| 07/10 | Creación de endpoints de control | [Naomi Rashel] | 2h | /health, /active-node, /switch-to-primary, /switch-to-secondary |
| 07/10 | **Pruebas de failover manual** | Todo el equipo | 2h | **Detención de M1, API cambia automáticamente a M2. ✅ Exitoso** |
| 08/10 | Desarrollo de locustfile.py | [Josué Nabí] | 2h | Script para pruebas de carga con 10 usuarios |
| 08/10 | **Pruebas de failover bajo carga** | Todo el equipo | 3h | **Locust con 10 usuarios, se detuvo M1, 0% errores, cambio transparente** |
| 08/10 | **Pruebas de failback** | Todo el equipo | 2h | **Recuperación de M1, sincronización automática, switch manual exitoso** |

**Total:** 25 horas

---

### Semana 5: Documentación 

| Fecha | Actividad | Responsable(s) | Tiempo | Estado |
|-------|-----------|----------------|--------|--------|
| 09/10 | Manual de Usuario | [Susan Herrera] | 4h | ✅ Completo |
| 09/10 | Manual Técnico | [Susan Herrera] | 5h | ✅ Completo |
| 10/10 | Bitácora de Trabajo | [ Todo el equipo] | 3h | ✅ Completo |
| 10/10 | README.md y revisión final | Todo el equipo | 3h | ✅ Completo |
| 11/10 | Preparación de repositorio GitHub | [Josué Nabí] | 2h | ✅ Completo |

**Total:** 17 horas

---

## Resumen Total de Horas

| Actividad | Horas |
|-----------|-------|
| Planificación y Docker | 10 |
| **Replicación Maestro-Maestro** | **24** |
| Sistema de Backups | 16 |
| API y Failover | 25 |
| Documentación | 17 |
| **TOTAL** | **92** |

---

## Arquitectura Implementada: Replicación Maestro-Maestro

### Decisión Técnica Principal

**¿Por qué replicación maestro-maestro con replicación lógica nativa?**

✅ **Ventajas:**
- Ambos servidores aceptan escrituras simultáneamente
- No hay nodo "pasivo" → mejor aprovechamiento de recursos
- Failover instantáneo (no hay promoción de réplica)
- Replicación bidireccional automática
- PostgreSQL 16 incluye soporte nativo robusto

🔧 **Implementación:**

```sql
-- En Master 1
CREATE PUBLICATION pub_imdb FOR ALL TABLES;
CREATE SUBSCRIPTION sub_from_master2
  CONNECTION 'host=imdb-master2 port=5432 user=replicator password=repl_pass dbname=bases2-db'
  PUBLICATION pub_imdb
  WITH (create_slot = true, slot_name = 'slot_2_to_1', copy_data = false, origin = 'none');

-- En Master 2 (simétrico)
CREATE PUBLICATION pub_imdb FOR ALL TABLES;
CREATE SUBSCRIPTION sub_from_master1
  CONNECTION 'host=imdb-master1 port=5432 user=replicator password=repl_pass dbname=bases2-db'
  PUBLICATION pub_imdb
  WITH (create_slot = true, slot_name = 'slot_1_to_2', copy_data = false, origin = 'none');
```

---

## Problemas Resueltos

### 1. Configuración Automática de Replicación
**Problema:** Configurar manualmente replicación bidireccional era propenso a errores.

**Solución:** Servicio `replication-setup` en Docker que:
- Espera healthchecks de ambos masters
- Crea usuario replicator automáticamente
- Limpia configuraciones anteriores
- Crea publications y subscriptions
- Todo en un solo `docker compose up`

**Tiempo invertido:** 5 horas | **Responsable:** [Josué Nabí]

---

### 2. Prevención de Bucles de Replicación
**Problema:** Riesgo de replicar un cambio infinitamente entre masters.

**Solución:** Parámetro `origin = 'none'` en subscriptions que instruye a PostgreSQL a NO replicar cambios que ya fueron replicados desde otro nodo.

**Tiempo invertido:** 2 horas (investigación) | **Responsable:** [Susan Herrera]

---

### 3. Sincronización de Contenedores
**Problema:** replication-setup intentaba configurar antes de que PostgreSQL estuviera listo.

**Solución:** Healthchecks con `pg_isready` y `condition: service_healthy` en depends_on.

```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U root -d bases2-db"]
  interval: 5s
  timeout: 3s
  retries: 20
```

**Tiempo invertido:** 2 horas | **Responsable:** [Josué Nabí]

---

## Pruebas Realizadas

### Prueba 1: Replicación Bidireccional
- **Fecha:** 27/09/2025
- **Procedimiento:** 
  1. Insertar en Master 1 → verificar en Master 2
  2. Insertar en Master 2 → verificar en Master 1
- **Resultado:** Exitoso, latencia < 100ms

### Prueba 2: Failover Automático
- **Fecha:** 08/10/2025
- **Procedimiento:** `docker stop imdb-master1` durante uso de API
- **Resultado:** API cambia automáticamente a Master 2, 0% errores

### Prueba 3: Failover bajo Carga
- **Fecha:** 08/10/2025
- **Procedimiento:** Locust con 10 usuarios, detener Master 1
- **Resultado:** 0% requests fallidos, throughput constante

### Prueba 4: Failback
- **Fecha:** 08/10/2025
- **Procedimiento:** Recuperar Master 1, ejecutar switch manual
- **Resultado:** Sincronización automática, sin pérdida de datos

---


## Conclusión

Se implementó exitosamente un sistema de base de datos IMDB con **alta disponibilidad mediante replicación maestro-maestro**, utilizando las capacidades nativas de PostgreSQL 16. 

**Evaluación del proyecto:** El sistema cumple todos los objetivos propuestos y demuestra robustez bajo pruebas de carga y escenarios de fallo.

---
