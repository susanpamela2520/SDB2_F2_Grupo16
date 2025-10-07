
---

# README – API Generos (Failover M1/M2)

API en **Node.js + Express** para insertar en la tabla `public.generos` de una base PostgreSQL con **replicación maestro-maestro**.

---

## 1. Requisitos previos

* Existen **dos contenedores PostgreSQL** configurados con replicación:

  * `postgres1` (Maestro 1) → puerto **5432**
  * `postgres2` (Maestro 2) → puerto **5433**
* Ambos tienen:

  ```sql
  CREATE TABLE IF NOT EXISTS public.generos (
    id_genero SMALLINT PRIMARY KEY,
    genero VARCHAR(100) NOT NULL
  );
  ```

---

## 2. Configuración de la API

Instala dependencias y ejecuta:

```bash
npm install
npm start
```

---

## 3. Endpoints principales

| Método   | Ruta                   | Descripción                                               |
| -------- | ---------------------- | --------------------------------------------------------- |
| **GET**  | `/health`              | Verifica conexión actual.                                 |
| **GET**  | `/active-node`         | Indica qué maestro está activo (`primary` o `secondary`). |
| **POST** | `/generos`             | Inserta un nuevo género.                                  |
| **POST** | `/switch-to-primary`   | Fuerza uso del maestro 1.                                 |
| **POST** | `/switch-to-secondary` | Fuerza uso del maestro 2.                                 |

Ejemplo de inserción:

```bash
curl -X POST http://localhost:5000/generos \
  -H "Content-Type: application/json" \
  -d '{"genero":"Rock Nacional"}'
```

Respuesta:

```json
{"ok":true,"data":{"id_genero":1,"genero":"Rock Nacional"},"node_used":"primary"}
```

---

## 4. Prueba de failover

1. **Inicia los dos PostgreSQL** (`postgres1` y `postgres2`).
2. Verifica conexión:

   ```bash
   curl http://localhost:5000/health
   ```
3. **Apaga Maestro 1**:

   ```bash
   docker stop postgres1
   ```
4. Inserta de nuevo:

   ```bash
   curl -X POST http://localhost:5000/generos -H "Content-Type: application/json" -d "{\"genero\":\"Salsa\"}"
   ```

   → La API usará automáticamente el **maestro 2**.
5. **Vuelve a encender Maestro 1**:

   ```bash
   docker start postgres1
   ```
6. Cuando esté sincronizado, regresa el tráfico a M1:

   ```bash
   curl -X POST http://localhost:5000/switch-to-primary
   ```
7. Verifica:

   ```bash
   curl http://localhost:5000/active-node
   ```

---

## 5. Prueba con Locust (opcional)

Archivo `locustfile.py`:

```python
from locust import HttpUser, task, between
import random

class InsercionGeneros(HttpUser):
    wait_time = between(1, 3)

    @task
    def insertar_genero(self):
        genero = f"Genero {random.randint(1,10000)}"
        self.client.post("/generos", json={"genero": genero})
```

Ejecuta:

```bash
locust -H http://localhost:5000 --headless -u 5 -r 0.5 -t 2m
```

Esto genera pocas inserciones para observar el failover.

---

## 6. En resumen

| Acción               | Comando                                                                                                       |
| -------------------- | ------------------------------------------------------------------------------------------------------------- |
| Arrancar API         | `npm start`                                                                                                   |
| Insertar dato        | `curl -X POST http://localhost:5000/generos -H "Content-Type: application/json" -d "{\"genero\":\"Prueba\"}"` |
| Apagar M1            | `docker stop postgres1`                                                                                       |
| Confirmar que usa M2 | `curl http://localhost:5000/active-node`                                                                      |
| Encender M1          | `docker start postgres1`                                                                                      |
| Volver a M1          | `curl -X POST http://localhost:5000/switch-to-primary`                                                        |

---
