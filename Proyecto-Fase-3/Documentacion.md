# Documentación Técnica - Fase 3: Migración PostgreSQL a MongoDB
## Proyecto IMDB - Base de Datos No Relacional

---

## Tabla de Contenidos
1. [Resumen Ejecutivo](#resumen-ejecutivo)
2. [Proceso de Traslado de Información (ETL)](#proceso-de-traslado-de-información-etl)
3. [Criterios de Diseño de Colecciones](#criterios-de-diseño-de-colecciones)
4. [Estructura de Datos](#estructura-de-datos)
5. [Optimizaciones Implementadas](#optimizaciones-implementadas)

---

## Resumen Ejecutivo

Este documento describe el proceso de migración de datos desde una base de datos relacional PostgreSQL hacia MongoDB, implementando un modelo de datos orientado a documentos optimizado para consultas de alto rendimiento.

**Tecnologías utilizadas:**
- **Origen:** PostgreSQL (base de datos relacional)
- **Destino:** MongoDB (base de datos NoSQL orientada a documentos)
- **Herramientas:** Node.js, csv-parser, MongoDB Node.js Driver
- **Formato intermedio:** CSV

---

## Proceso de Traslado de Información (ETL)

El proceso de migración se realizó en **3 etapas claramente definidas**:

1. **PostgreSQL → CSV:** Extracción mediante consultas SQL
2. **CSV → MongoDB (Colecciones Base):** Carga inicial usando script Node.js
3. **MongoDB Base → MongoDB Final:** Agregación y desnormalización

### Etapa 1: Extracción de Datos (PostgreSQL → CSV)

Los datos se extraen desde PostgreSQL mediante **8 consultas SQL**. Los resultados de cada consulta se exportan manualmente como archivos CSV que servirán como formato intermedio:

#### 1.1 Consultas SQL de Extracción

Cada consulta SQL se ejecuta en PostgreSQL y su resultado se exporta como archivo CSV:

**a) `produccion_base.sql` - Datos principales de producciones**
```sql
SELECT 
  prod.id_titulo,
  tp.tipo_produccion,
  prod.adultos,
  EXTRACT(YEAR FROM prod.ahno_inicio) AS año_inicio,
  EXTRACT(YEAR FROM prod.ahno_finalizacion) AS año_fin,
  prod.minutos_duracion,
  prod.promedio_rating,
  prod.votos
FROM produccion prod
JOIN tipo_produccion tp ON tp.id_tipo_produccion = prod.id_tipo_titulo
ORDER BY prod.id_titulo;
```

**b) `nombres_produccion.sql` - Títulos en diferentes idiomas**
```sql
SELECT 
  id_produccion,
  orden,
  nombres_produccion AS titulo,
  region,
  lenguaje,
  esOriginal AS es_original
FROM nombres_produccion
ORDER BY id_produccion, orden;
```

**c) `generos_produccion.sql` - Géneros de cada producción**
```sql
SELECT 
  gp.id_produccion,
  g.genero
FROM genero_produccion gp
JOIN generos g ON g.id_genero = gp.id_genero
ORDER BY gp.id_produccion, g.genero;
```

**d) `actores.sql` - Actores y actrices**
```sql
SELECT 
  pp.id_produccion,
  per.id_persona,
  per.nombre,
  pp.orden,
  prof.profesion
FROM personas_produccion pp
JOIN personas per ON per.id_persona = pp.id_persona
JOIN profesiones prof ON prof.id_profesion = pp.id_profesion
WHERE prof.profesion IN ('Actor', 'Actress')
ORDER BY pp.id_produccion, pp.orden;
```

**e) `directores.sql` - Directores**
```sql
SELECT 
  pp.id_produccion,
  per.id_persona,
  per.nombre,
  pp.orden
FROM personas_produccion pp
JOIN personas per ON per.id_persona = pp.id_persona
JOIN profesiones prof ON prof.id_profesion = pp.id_profesion
WHERE prof.profesion = 'Director'
ORDER BY pp.id_produccion, pp.orden;
```

**f) `escritores.sql` - Guionistas**
```sql
SELECT 
  pp.id_produccion,
  per.id_persona,
  per.nombre,
  pp.orden
FROM personas_produccion pp
JOIN personas per ON per.id_persona = pp.id_persona
JOIN profesiones prof ON prof.id_profesion = pp.id_profesion
WHERE prof.profesion = 'Writer'
ORDER BY pp.id_produccion, pp.orden;
```

**g) `personajes.sql` - Personajes interpretados**
```sql
SELECT 
  id_produccion,
  persona_id,
  personaje
FROM personajes
ORDER BY id_produccion, persona_id;
```

**h) `episodios.sql` - Episodios de series**
```sql
SELECT 
  e.id_episodio,
  e.id_serie,
  e.temporada,
  e.episodio,
  (SELECT np.nombres_produccion 
   FROM nombres_produccion np 
   WHERE np.id_produccion = e.id_episodio 
     AND np.esOriginal = TRUE 
   LIMIT 1) AS titulo_episodio
FROM episodios e
ORDER BY e.id_serie, e.temporada NULLS LAST, e.episodio NULLS LAST;
```

#### 1.2 Archivos CSV Generados

Cada consulta SQL genera un archivo CSV correspondiente que se almacena en el directorio `../data/csv`:

| Consulta SQL | Archivo CSV Generado | Descripción |
|--------------|---------------------|-------------|
| `produccion_base.sql` | `produccion_base.csv` | Datos principales de producciones |
| `nombres_produccion.sql` | `nombres_produccion.csv` | Títulos en diferentes idiomas |
| `generos_produccion.sql` | `generos_produccion.csv` | Géneros de cada producción |
| `actores.sql` | `actores.csv` | Actores y actrices |
| `directores.sql` | `directores.csv` | Directores |
| `escritores.sql` | `escritores.csv` | Guionistas |
| `personajes.sql` | `personajes.csv` | Personajes interpretados |
| `episodios.sql` | `episodios.csv` | Episodios de series |

**Nota:** Los archivos CSV deben colocarse en el directorio `../data/csv` relativo al script de carga.

### Etapa 2: Carga a MongoDB - Colecciones Base (CSV → MongoDB)

El script `IMDBToMongo.js` lee los archivos CSV generados en la Etapa 1 y los carga en MongoDB como **colecciones base normalizadas**. Este proceso se ejecuta en **3 fases**:

#### FASE 1: Carga de Archivos CSV a Colecciones Base MongoDB

**Objetivo:** Convertir archivos CSV en colecciones MongoDB normalizadas que replican la estructura relacional original.

**Método utilizado:** Streaming con procesamiento por lotes (Batch Processing)

```javascript
// Configuración
const BATCH_SIZE = 5000; // Documentos por lote
const MONGO_URI = 'mongodb://localhost:27017';
const DB_NAME = 'imdb';
```

**Proceso de streaming:**
1. Lee archivos CSV línea por línea usando `csv-parser`
2. Transforma cada fila aplicando funciones de mapeo específicas
3. Acumula documentos en lotes de 5,000 registros
4. Inserta cada lote usando `insertMany()` con `ordered: false` para continuar ante duplicados
5. Maneja errores de duplicados (código 11000) sin detener el proceso

**Colecciones base creadas (intermedias - no para uso final):**
- `producciones_base` - Información principal de cada producción
- `nombres` - Títulos en diferentes idiomas
- `generos` - Géneros asociados
- `actores` - Actores/actrices
- `directores` - Directores
- `escritores` - Guionistas
- `personajes` - Personajes interpretados
- `episodios` - Episodios de series

**Importante:** Estas colecciones son **intermedias** y sirven únicamente como fuente de datos para construir las colecciones finales. Las aplicaciones **NO** consultan estas colecciones directamente.

**Transformaciones aplicadas:**

```javascript
// Ejemplo: Transformación de produccion_base.csv
{
  _id: parseInt(row.id_titulo),              // Convierte a número
  tipo: row.tipo_produccion,                 // String directo
  adultos: row.adultos === 't',              // Convierte 't'/'f' a booleano
  año_inicio: row.año_inicio ? parseInt(row.año_inicio) : null,
  año_fin: row.año_fin ? parseInt(row.año_fin) : null,
  duracion_minutos: row.minutos_duracion ? parseInt(row.minutos_duracion) : null,
  promedio_rating: row.promedio_rating ? parseFloat(row.promedio_rating) : null,
  votos: row.votos ? parseInt(row.votos) : null
}
```

#### FASE 2: Creación de Índices en Colecciones Base

**Objetivo:** Optimizar las operaciones de agregación que se ejecutarán en la Fase 3.

Se crean índices estratégicos para optimizar las agregaciones posteriores:

```javascript
await db.collection('nombres').createIndex({ id_produccion: 1 });
await db.collection('generos').createIndex({ id_produccion: 1 });
await db.collection('actores').createIndex({ id_produccion: 1 });
await db.collection('directores').createIndex({ id_produccion: 1 });
await db.collection('escritores').createIndex({ id_produccion: 1 });
await db.collection('personajes').createIndex({ id_produccion: 1, persona_id: 1 });
await db.collection('episodios').createIndex({ id_serie: 1 });
await db.collection('producciones_base').createIndex({ tipo: 1 });
```

#### FASE 3: Creación de las 4 Colecciones Finales (Desnormalización)

**Objetivo:** Crear las colecciones optimizadas que usarán las aplicaciones.

Esta fase implementa el **patrón de desnormalización** mediante pipelines de agregación complejos que combinan datos de las colecciones base.

**Las 4 colecciones finales creadas son:**
1. **`producciones`** - Películas y contenido cinematográfico
2. **`series`** - Series de televisión con sus episodios
3. **`peliculas_por_director`** - Vista agregada de películas agrupadas por director
4. **`tops`** - Rankings pre-calculados (top películas, top actores, top director)

##### 3.1 Colección `producciones` (Películas y contenido similar)

**Proceso en 2 pasos:**

**PASO 1: Estructura base**
- Filtra producciones del tipo: `movie`, `short`, `tvMovie`, `tvShort`, `tvSpecial`, `video`, `videoGame`, `tvPilot`, `tvMiniSeries`
- Realiza 5 `$lookup` para unir datos relacionados
- Extrae el título original usando `$filter` y `$arrayElemAt`
- Estructura arrays embebidos de actores, directores, escritores
- Genera colección temporal `producciones_temp1`

**PASO 2: Enriquecimiento con personajes**
- Hace `$unwind` de actores
- Asocia personajes mediante `$lookup` correlacionado
- Reagrupa usando `$group` y `$push`
- Genera colección final `producciones`

##### 3.2 Colección `series` (Series de TV)

- Filtra producciones del tipo: `tvSeries`, `tvMiniSeries`, `tvShort`
- Une información de episodios desde colección `episodios`
- Calcula métricas: `total_episodios`, `total_temporadas`
- Embebe array completo de episodios con sus metadatos

##### 3.3 Colección `peliculas_por_director`

**Propósito:** Vista materializada pre-agregada para consultas por director

**Proceso:**
1. Parte desde colección `directores`
2. Hace `$lookup` con `producciones` filtrando solo películas (`movie`, `tvMovie`)
3. Agrupa por `id_persona` del director
4. Calcula estadísticas:
   - `total_peliculas`: Contador de películas
   - `rating_promedio`: Promedio de ratings
5. Construye array `peliculas` con información completa
6. Ordena películas por año descendente

##### 3.4 Colección `tops` (Rankings Pre-calculados)

Se crean 3 documentos específicos en la colección `tops`:

**a) `top_10_peliculas`**
- Filtra películas con mínimo 1000 votos
- Ordena por rating y votos
- Limita a top 10
- Incluye: título, rating, votos, año, duración, género, directores

**b) `director_mas_peliculas`**
- Identifica al director con más películas
- Calcula su rating promedio
- Documento único con estadísticas

**c) `top_10_actores`**
- Agrupa actores por total de apariciones
- Filtra actores con mínimo 5 películas
- Incluye: total películas, rating promedio, rango de años activo

### 3. Configuración de Ejecución

**Comando de ejecución:**
```bash
node --max-old-space-size=8192 IMDBToMongo.js
```

**Parámetros:**
- `--max-old-space-size=8192`: Asigna 8GB de RAM para el proceso Node.js
- Este valor es ajustable según la memoria disponible en el sistema
- Necesario para manejar agregaciones grandes con `allowDiskUse: true`

### Etapa 3: Creación de Colecciones Finales (MongoDB Base → MongoDB Final)

Las colecciones base sirven como fuente para crear las **4 colecciones finales** mediante agregaciones:

```
Colecciones Base (8)          →    Colecciones Finales (4)
├─ producciones_base          →    ├─ producciones
├─ nombres                    →    ├─ series
├─ generos                    →    ├─ peliculas_por_director
├─ actores                    →    └─ tops
├─ directores                 →
├─ escritores                 →
├─ personajes                 →
└─ episodios                  →
```

Este proceso utiliza pipelines de agregación complejos (explicados en la Fase 3 anterior) que:
- Combinan datos de múltiples colecciones base usando `$lookup`
- Transforman y estructuran los datos en formato desnormalizado
- Calculan métricas y estadísticas pre-agregadas
- Generan documentos auto-contenidos optimizados para consultas

**Resultado final:** 4 colecciones listas para uso en producción, optimizadas para las consultas más frecuentes de la aplicación.

---

## Resumen del Flujo Completo

```
┌─────────────────┐
│   PostgreSQL    │
│  (BD Relacional)│
└────────┬────────┘
         │
         │ 1. Consultas SQL
         │    (8 archivos)
         ▼
┌─────────────────┐
│   Archivos CSV  │
│  (8 archivos)   │
└────────┬────────┘
         │
         │ 2. IMDBToMongo.js
         │    - Fase 1: Carga CSV
         │    - Fase 2: Indexación
         ▼
┌─────────────────┐
│  MongoDB Base   │
│  (8 colecciones)│
└────────┬────────┘
         │
         │ 3. IMDBToMongo.js
         │    - Fase 3: Agregación
         ▼
┌─────────────────┐
│ MongoDB Final   │
│ (4 colecciones) │
│  - producciones │
│  - series       │
│  - peliculas_   │
│    por_director │
│  - tops         │
└─────────────────┘
```

### 3. Configuración de Ejecución

---

## Criterios de Diseño de Colecciones

### 1. Modelo de Datos: Desnormalización Estratégica

**Filosofía:** Privilegiar el rendimiento de lectura sobre la normalización

El diseño sigue el principio de **"Data that is accessed together should be stored together"** (Los datos que se acceden juntos deben almacenarse juntos).

### 2. Arquitectura de Dos Capas: Base vs. Final

#### Colecciones Base (Capa Intermedia - 8 colecciones)
**Propósito:** Facilitar la carga inicial desde CSV y servir como fuente para agregaciones

**Características:**
- Reflejan la estructura relacional original de PostgreSQL
- Mantienen relaciones mediante IDs (normalizadas)
- Optimizadas para el proceso de ETL
- **NO se consultan directamente** por las aplicaciones
- Se usan únicamente como fuente de datos para construir las colecciones finales

**Colecciones:**
1. `producciones_base`
2. `nombres`
3. `generos`
4. `actores`
5. `directores`
6. `escritores`
7. `personajes`
8. `episodios`

#### Colecciones Finales (Capa de Aplicación - 4 colecciones)
**Propósito:** Optimizar consultas frecuentes de la aplicación

**Características:**
- Documentos auto-contenidos con toda la información necesaria
- Desnormalizadas mediante agregaciones complejas
- Minimizan o eliminan JOINs en tiempo de consulta
- Optimizadas para lectura de alto rendimiento
- **Son las únicas que consultan las aplicaciones**

**Colecciones:**
1. **`producciones`** - Películas y contenido cinematográfico con toda su información embebida
2. **`series`** - Series de TV con episodios, temporadas y reparto completo
3. **`peliculas_por_director`** - Películas agrupadas por director con estadísticas pre-calculadas
4. **`tops`** - Rankings pre-calculados (top 10 películas, director con más películas, top 10 actores)

### 3. Criterios Específicos por Colección Final

#### 3.1 `producciones`

**Criterio:** Documento rico que embebe toda la información de una película/producción

**Decisiones de diseño:**

1. **Título Original Prioritario:**
   - Se extrae y coloca en campo de primer nivel
   - Facilita búsquedas y ordenamiento
   ```javascript
   titulo_original: "The Matrix"
   ```

2. **Títulos Alternativos como Array:**
   - Otros títulos (traducciones, nombres regionales) en array separado
   - Permite búsqueda en múltiples idiomas sin duplicar documentos
   ```javascript
   otros_titulos: [
     { titulo: "Matrix", region: "ES", lenguaje: "es" },
     { titulo: "La Matrice", region: "FR", lenguaje: "fr" }
   ]
   ```

3. **Rating como Subdocumento:**
   - Agrupa métricas relacionadas
   ```javascript
   rating: {
     promedio: 8.7,
     votos: 1847920
   }
   ```

4. **Actores con Personajes Embebidos:**
   - Array de actores con sus personajes interpretados
   - Elimina necesidad de JOIN para mostrar reparto completo
   ```javascript
   actores: [
     {
       id_persona: 1,
       nombre: "Keanu Reeves",
       orden: 1,
       personajes: ["Neo", "Thomas A. Anderson"]
     }
   ]
   ```

5. **Géneros como Array Simple:**
   - Fácil filtrado con operador `$in`
   ```javascript
   generos: ["Action", "Sci-Fi"]
   ```

**Justificación:** Las consultas típicas requieren ver toda esta información junta (título, rating, reparto, género). Embeber evita múltiples consultas o JOINs.

#### 3.2 `series`

**Criterio:** Similar a producciones pero optimizado para contenido serializado

**Decisiones de diseño:**

1. **Episodios Embebidos:**
   - Todo el catálogo de episodios en un array
   - Permite recuperar serie completa en una consulta
   ```javascript
   episodios: [
     {
       id_episodio: 123,
       temporada: 1,
       episodio: 1,
       titulo: "Pilot"
     }
   ]
   ```

2. **Métricas Pre-calculadas:**
   - `total_episodios` y `total_temporadas` en campos de primer nivel
   - Evita conteos y agregaciones en tiempo de consulta
   ```javascript
   total_episodios: 73,
   total_temporadas: 5
   ```

**Justificación:** Las series tienen relaciones 1-a-muchos con episodios. Embeber es más eficiente que mantener colección separada dado que típicamente se consultan juntos.

#### 3.3 `peliculas_por_director`

**Criterio:** Vista materializada para consultas por director

**Decisiones de diseño:**

1. **Agrupación por Director:**
   - `_id` es el `id_persona` del director
   - Facilita búsquedas directas por director

2. **Estadísticas Pre-calculadas:**
   ```javascript
   estadisticas: {
     total_peliculas: 45,
     rating_promedio: 7.82
   }
   ```

3. **Array de Películas Completo:**
   - Cada película con su información completa
   - Ordenadas por año descendente
   - Incluye actores principales (límite: 5 primeros)
   ```javascript
   peliculas: [
     {
       id_titulo: 456,
       titulo: "Inception",
       año: 2010,
       rating: { promedio: 8.8, votos: 2000000 },
       generos: ["Action", "Sci-Fi", "Thriller"],
       actores_principales: [/* top 5 actores */]
     }
   ]
   ```

**Justificación:** 
- Patrón de acceso común: "Dame todas las películas del director X"
- Pre-agregar elimina necesidad de JOIN entre directores y producciones
- Cálculo de estadísticas una sola vez en carga, no en cada consulta

#### 3.4 `tops`

**Criterio:** Cache de rankings frecuentemente consultados

**Decisiones de diseño:**

1. **Documentos Únicos por Tipo de Top:**
   - `_id` describe el tipo de ranking
   - Permite consultas directas por ID
   ```javascript
   { _id: "top_10_peliculas" }
   { _id: "director_mas_peliculas" }
   { _id: "top_10_actores" }
   ```

2. **Timestamp de Actualización:**
   ```javascript
   actualizado: ISODate("2025-10-26T...")
   ```

3. **Array Ordenado con Posiciones:**
   ```javascript
   peliculas: [
     { posicion: 1, id_titulo: 111, titulo: "...", rating: 9.2 },
     { posicion: 2, id_titulo: 222, titulo: "...", rating: 9.0 }
   ]
   ```

**Justificación:**
- Rankings son costosos de calcular (requieren ordenar millones de registros)
- Se consultan frecuentemente pero cambian raramente
- Pre-calcular mejora dramáticamente el tiempo de respuesta
- Un solo documento por tipo de ranking = una sola consulta

### 4. Patrones de Diseño Aplicados

#### 4.1 Patrón de Documento Extendido (Extended Reference Pattern)

**Uso:** Actores, directores, escritores en producciones

En lugar de solo guardar IDs, se embebe información básica:
```javascript
directores: [
  {
    id_persona: 123,      // Referencia
    nombre: "Christopher Nolan",  // Información embebida
    orden: 1
  }
]
```

**Ventaja:** Permite mostrar información básica sin consultas adicionales. Si se necesita información completa de la persona, se puede hacer consulta adicional usando `id_persona`.

#### 4.2 Patrón de Subconjunto (Subset Pattern)

**Uso:** Actores principales en `peliculas_por_director`

Se limita el array embebido a los 5 primeros actores:
```javascript
actores_principales: { $slice: ['$pelicula.actores', 5] }
```

**Ventaja:** Mantiene el documento a un tamaño manejable mientras proporciona la información más relevante.

#### 4.3 Patrón de Agregación Computada (Computed Pattern)

**Uso:** Estadísticas en `peliculas_por_director` y `tops`

Pre-calcula valores que serían costosos de calcular en tiempo de consulta:
```javascript
estadisticas: {
  total_peliculas: 45,           // Cuenta pre-calculada
  rating_promedio: 7.82          // Promedio pre-calculado
}
```

**Ventaja:** Transforma operaciones de agregación complejas en simples lecturas de campos.

#### 4.4 Patrón de Outlier (Outlier Pattern)

**Uso:** Separación de `series` y `producciones`

Series tienen características únicas (episodios, temporadas) que no aplican a películas.

**Ventaja:** Evita documentos con campos nulos y optimiza índices específicos para cada tipo.

### 5. Decisiones de Indexación

#### Índices en Colecciones Base
```javascript
// Índices simples para JOINs ($lookup)
{ id_produccion: 1 }
{ id_serie: 1 }
{ tipo: 1 }

// Índice compuesto para búsquedas específicas
{ id_produccion: 1, persona_id: 1 }
```

#### Índices en Colecciones Finales
```javascript
// Búsquedas de texto completo
{ titulo_original: "text" }
{ nombre: "text" }

// Filtros y ordenamientos
{ tipo: 1 }
{ 'rating.promedio': -1 }

// Búsquedas directas
{ '_id': 1 }
```

**Criterio:** Indexar campos usados en:
1. Filtros de búsqueda (`$match`)
2. Ordenamientos (`$sort`)
3. Búsquedas de texto (`$regex`, búsqueda full-text)

### 6. Trade-offs Aceptados

#### Duplicación de Datos
**Decisión:** Aceptar duplicación de nombres de actores/directores en múltiples documentos

**Trade-off:**
- ❌ Mayor espacio en disco
- ❌ Posible inconsistencia si cambia el nombre de una persona
- ✅ Consultas mucho más rápidas
- ✅ Sin necesidad de JOINs

**Justificación:** Los nombres raramente cambian. El beneficio en rendimiento supera el costo de almacenamiento.

#### Tamaño de Documentos
**Decisión:** Crear documentos ricos que pueden ser grandes (especialmente series con muchos episodios)

**Trade-off:**
- ❌ Documentos pueden exceder 1MB en casos extremos
- ❌ Mayor uso de memoria en caché
- ✅ Toda la información en una consulta
- ✅ Experiencia de usuario más rápida

**Justificación:** MongoDB maneja bien documentos hasta 16MB. La mayoría quedan bajo 100KB. El límite de tamaño no es problema práctico.

#### Actualización de Datos
**Decisión:** Colecciones finales se regeneran completamente en cada ETL

**Trade-off:**
- ❌ No es posible actualizar un solo campo fácilmente
- ❌ Proceso de carga más largo
- ✅ Garantiza consistencia completa
- ✅ Simplifica la lógica de actualización

**Justificación:** Los datos de IMDB se actualizan por lotes completos (diario/semanal), no en tiempo real. Regenerar es más simple que gestionar actualizaciones parciales.

---

## Estructura de Datos

### Esquema de Colecciones Finales

#### Colección `producciones`
```javascript
{
  _id: 111161,                           // ID del título (Integer)
  tipo: "movie",                         // Tipo de producción (String)
  adultos: false,                        // Contenido para adultos (Boolean)
  año_inicio: 1994,                      // Año de lanzamiento (Integer)
  año_fin: null,                         // Año de finalización (Integer/null)
  duracion_minutos: 142,                 // Duración (Integer/null)
  titulo_original: "The Shawshank Redemption",  // Título original (String)
  otros_titulos: [                       // Títulos alternativos (Array)
    {
      titulo: "Cadena perpetua",
      region: "ES",
      lenguaje: "es"
    }
  ],
  rating: {                              // Información de rating (Object)
    promedio: 9.3,                       // Promedio (Float)
    votos: 2500000                       // Número de votos (Integer)
  },
  generos: ["Drama"],                    // Array de géneros (Array[String])
  actores: [                             // Array de actores (Array[Object])
    {
      id_persona: 102,
      nombre: "Tim Robbins",
      orden: 1,
      personajes: ["Andy Dufresne"]      // Personajes interpretados
    }
  ],
  directores: [                          // Array de directores (Array[Object])
    {
      id_persona: 230,
      nombre: "Frank Darabont",
      orden: 1
    }
  ],
  escritores: [                          // Array de escritores (Array[Object])
    {
      id_persona: 321,
      nombre: "Stephen King",
      orden: 1
    }
  ]
}
```

#### Colección `series`
```javascript
{
  _id: 903747,
  tipo: "tvSeries",
  adultos: false,
  año_inicio: 2011,
  año_fin: 2019,
  titulo_original: "Breaking Bad",
  rating: {
    promedio: 9.5,
    votos: 1800000
  },
  generos: ["Crime", "Drama", "Thriller"],
  actores: [
    {
      id_persona: 17419,
      nombre: "Bryan Cranston",
      orden: 1
    }
  ],
  directores: [
    {
      id_persona: 66633,
      nombre: "Vince Gilligan",
      orden: 1
    }
  ],
  total_episodios: 62,                   // Total de episodios (Integer)
  total_temporadas: 5,                   // Total de temporadas (Integer)
  episodios: [                           // Array de episodios (Array[Object])
    {
      id_episodio: 2301451,
      temporada: 1,
      episodio: 1,
      titulo: "Pilot"
    },
    {
      id_episodio: 2301452,
      temporada: 1,
      episodio: 2,
      titulo: "Cat's in the Bag..."
    }
    // ... más episodios
  ]
}
```

#### Colección `peliculas_por_director`
```javascript
{
  _id: 893,                              // id_persona del director
  nombre: "Christopher Nolan",           // Nombre del director
  estadisticas: {                        // Estadísticas agregadas
    total_peliculas: 11,
    rating_promedio: 8.45
  },
  peliculas: [                           // Array de películas (ordenado por año desc)
    {
      id_titulo: 1375666,
      titulo: "Inception",
      año: 2010,
      tipo: "movie",
      duracion_minutos: 148,
      rating: {
        promedio: 8.8,
        votos: 2000000
      },
      generos: ["Action", "Sci-Fi", "Thriller"],
      actores_principales: [             // Solo top 5 actores
        {
          id_persona: 6384,
          nombre: "Leonardo DiCaprio",
          orden: 1,
          personajes: ["Cobb"]
        }
        // ... hasta 5 actores
      ]
    }
    // ... más películas
  ]
}
```

#### Colección `tops`
```javascript
// Documento: Top 10 Películas
{
  _id: "top_10_peliculas",
  actualizado: ISODate("2025-10-26T10:30:00Z"),
  peliculas: [
    {
      posicion: 1,
      id_titulo: 111161,
      titulo: "The Shawshank Redemption",
      rating: 9.3,
      votos: 2500000,
      año: 1994,
      duracion_minutos: 142,
      tipo: "movie",
      generos: ["Drama"],
      directores: ["Frank Darabont"]
    }
    // ... posiciones 2-10
  ]
}

// Documento: Director con Más Películas
{
  _id: "director_mas_peliculas",
  actualizado: ISODate("2025-10-26T10:30:00Z"),
  director: {
    id_persona: 1234,
    nombre: "Steven Spielberg",
    total_peliculas: 67,
    rating_promedio: 7.65
  }
}

// Documento: Top 10 Actores
{
  _id: "top_10_actores",
  actualizado: ISODate("2025-10-26T10:30:00Z"),
  actores: [
    {
      posicion: 1,
      id_persona: 5678,
      nombre: "Samuel L. Jackson",
      total_peliculas: 189,
      rating_promedio: 7.2,
      primera_pelicula: 1972,
      ultima_pelicula: 2024
    }
    // ... posiciones 2-10
  ]
}
```

---

## Optimizaciones Implementadas

### 1. Optimizaciones de Procesamiento

#### 1.1 Streaming de Datos
- **Problema:** Archivos CSV pueden tener millones de líneas
- **Solución:** Procesamiento por streaming en lugar de cargar todo en memoria
- **Beneficio:** Uso constante de memoria independiente del tamaño del archivo

#### 1.2 Batch Inserts
- **Configuración:** Lotes de 5,000 documentos
- **Beneficio:** Reduce overhead de red y operaciones de escritura
- **Resultado:** ~10x más rápido que inserts individuales

#### 1.3 Unordered Inserts
```javascript
insertMany(batch, { ordered: false })
```
- **Beneficio:** Continúa insertando aunque encuentre duplicados
- **Uso:** Permite re-ejecutar el script sin limpiar datos previos

#### 1.4 Disk Usage en Agregaciones
```javascript
{ allowDiskUse: true, maxTimeMS: 3600000 }
```
- **Beneficio:** Permite agregaciones que exceden límite de RAM (100MB)
- **Necesario:** Para procesar millones de documentos en agregaciones complejas

### 2. Optimizaciones de Almacenamiento

#### 2.1 Conversión de Tipos
- **Strings a Números:** IDs y métricas como integers/floats
- **Beneficio:** 50-75% menos espacio que strings equivalentes
- **Impacto:** Índices más pequeños y rápidos

#### 2.2 Valores Null Explícitos
```javascript
año_fin: row.año_fin ? parseInt(row.año_fin) : null
```
- **Beneficio:** Diferencia entre "no tiene valor" vs "valor desconocido"
- **Uso:** Facilita consultas con `$exists` y `$ne: null`

#### 2.3 Arrays en Lugar de Colecciones Relacionadas
- **Decisión:** Géneros como array simple en lugar de colección separada
- **Beneficio:** Elimina índices adicionales y lookups

### 3. Optimizaciones de Consultas

#### 3.1 Índices de Texto Completo
```javascript
{ titulo_original: "text" }
```
- **Uso:** Búsquedas tipo "contains" eficientes
- **Sintaxis de consulta:**
```javascript
db.producciones.find({ $text: { $search: "Matrix" } })
```

#### 3.2 Índices Compuestos Estratégicos
```javascript
{ id_produccion: 1, persona_id: 1 }
```
- **Beneficio:** Optimiza lookups en agregaciones con múltiples condiciones

#### 3.3 Proyecciones Selectivas
- **Práctica:** Solo devolver campos necesarios
- **Ejemplo:**
```javascript
{ $project: { 
  titulo_original: 1, 
  'rating.promedio': 1,
  generos: 1,
  _id: 0  // Excluir _id si no es necesario
}}
```

### 4. Optimizaciones de Escalabilidad

#### 4.1 Separación de Series y Producciones
- **Razón:** Patrones de acceso diferentes
- **Beneficio:** Índices más específicos y eficientes para cada tipo

#### 4.2 Colección de Tops Pre-calculados
- **Beneficio:** Evita re-calcular rankings en cada consulta
- **Trade-off:** Actualización periódica vs cálculo en tiempo real
- **Decisión:** Aceptable porque rankings cambian lentamente

#### 4.3 Límite en Arrays Embebidos
- **Ejemplo:** Solo 5 actores principales en `peliculas_por_director`
- **Beneficio:** Controla el tamaño máximo de documentos
- **Principio:** "Good enough" - la mayoría de usuarios solo ven los primeros actores

### 5. Métricas de Rendimiento

#### Comparación: Consultas Relacionales vs MongoDB

**Caso 1: Obtener película con reparto completo**

Modelo Relacional (PostgreSQL):
```sql
-- Requiere 4 JOINs
SELECT p.*, a.nombre, personajes.personaje, d.nombre, g.genero
FROM produccion p
LEFT JOIN actores a ON ...
LEFT JOIN personajes ON ...
LEFT JOIN directores d ON ...
LEFT JOIN generos g ON ...
WHERE p.id_titulo = 111161;

-- Tiempo típico: 50-200ms (según índices)
```

Modelo MongoDB:
```javascript
db.producciones.findOne({ _id: 111161 })

// Tiempo típico: 1-5ms
```

**Mejora:** ~20-50x más rápido

**Caso 2: Top 10 películas mejor valoradas**

Modelo Relacional:
```sql
-- Requiere scan completo de tabla + ordenamiento
SELECT * FROM produccion
WHERE votos >= 1000
ORDER BY promedio_rating DESC, votos DESC
LIMIT 10;

-- Tiempo típico: 500ms-2s (millones de registros)
```

Modelo MongoDB:
```javascript
db.tops.findOne({ _id: "top_10_peliculas" })

// Tiempo típico: <1ms
```

**Mejora:** ~500-2000x más rápido

---

## Ejemplos de Consultas

### Consulta 1: Búsqueda por Nombre
```javascript
// Búsqueda en producciones y series
function q1_buscarPorNombre(nombre, limit=50) {
  const rx = new RegExp(nombre, "i"); 
  return db.producciones.aggregate([
    { $match: { $or: [
      { titulo_original: { $regex: rx } },
      { "otros_titulos.titulo": { $regex: rx } }
    ]}},
    { $addFields: { __tipo: "produccion" } },
    { $unionWith: {
        coll: "series",
        pipeline: [
          { $match: { $or: [
            { titulo_original: { $regex: rx } },
            { "otros_titulos.titulo": { $regex: rx } }
          ]}},
          { $addFields: { __tipo: "serie" } }
        ]
    }},
    { $sort: { 
      'rating.votos': -1, 
      'rating.promedio': -1, 
      titulo_original: 1 
    }},
    { $limit: limit }
  ]).toArray();
}
```

**Ventaja del diseño:** 
- Búsqueda en título original Y traducciones sin múltiples consultas
- Union de producciones y series en single pipeline

### Consulta 2: Películas de un Director
```javascript
function q2_peliculasDeDirector(nombreDirector) {
  return db.peliculas_por_director.aggregate([
    { $match: { nombre: { $regex: `^${nombreDirector}$`, $options: "i" } } },
    { $project: { 
      _id: 0, 
      nombre: 1, 
      "estadisticas.total_peliculas": 1, 
      "estadisticas.rating_promedio": 1, 
      peliculas: 1 
    }}
  ]).toArray();
}
```

**Ventaja del diseño:**
- Toda la información en un solo documento
- Sin JOINs necesarios
- Estadísticas pre-calculadas

### Consulta 3: Top 10 Películas
```javascript
function q3_top10peliculas() {
  return db.tops.aggregate([
    { $match: { _id: "top_10_peliculas" } },
    { $unwind: "$peliculas" },
    { $sort: { "peliculas.posicion": 1 } },
    { $limit: 10 },
    { $project: { 
      _id: 0, 
      posicion: "$peliculas.posicion", 
      titulo: "$peliculas.titulo",
      rating: "$peliculas.rating", 
      votos: "$peliculas.votos",
      año: "$peliculas.año",
      generos: "$peliculas.generos", 
      directores: "$peliculas.directores" 
    }}
  ]).toArray();
}
```

**Ventaja del diseño:**
- Ranking pre-calculado
- Respuesta en <1ms
- Sin necesidad de ordenar millones de registros

### Consulta 4: Director con Más Películas
```javascript
function q4_directorConMasPeliculas() {
  return db.peliculas_por_director.aggregate([
    { $sort: { "estadisticas.total_peliculas": -1, nombre: 1 } },
    { $limit: 1 },
    { $project: { 
      _id: 0, 
      nombre: 1, 
      "estadisticas.total_peliculas": 1 
    }}
  ]).toArray();
}
```

**Ventaja del diseño:**
- Simple ordenamiento y límite
- No requiere GROUP BY en tiempo real

### Consulta 5: Top 10 Actores
```javascript
function q5_top10actores() {
  return db.producciones.aggregate([
    { $project: { actores: 1 } },
    { $unwind: "$actores" },
    { $project: { actor: "$actores.nombre" } },
    { $unionWith: {
        coll: "series",
        pipeline: [
          { $project: { actores: 1 } },
          { $unwind: "$actores" },
          { $project: { actor: "$actores.nombre" } }
        ]
    }},
    { $group: { 
      _id: "$actor", 
      total: { $sum: 1 } 
    }},
    { $sort: { total: -1, _id: 1 } },
    { $limit: 10 },
    { $project: { 
      _id: 0, 
      actor: "$_id", 
      total: 1 
    }}
  ]).toArray();
}
```

**Ventaja del diseño:**
- Actores embebidos en documentos
- Union eficiente de producciones y series

---

## Conclusiones

### Logros del Diseño

1. **Separación Clara de Responsabilidades:**
   - Colecciones base (8) para ETL e integración
   - Colecciones finales (4) para aplicaciones
   - Arquitectura de dos capas facilita mantenimiento

2. **Rendimiento Optimizado:**
   - Consultas 20-2000x más rápidas que modelo relacional equivalente
   - Tiempo de respuesta <5ms para la mayoría de consultas
   - Las 4 colecciones finales están completamente desnormalizadas

3. **Proceso ETL Robusto:**
   - Extracción controlada desde PostgreSQL
   - Formato CSV como punto de control intermedio
   - Carga por lotes eficiente en MongoDB
   - Agregaciones complejas pero automatizadas

4. **Escalabilidad:**
   - Diseño soporta millones de documentos
   - Uso de disk en agregaciones permite procesar datasets grandes
   - Las 4 colecciones finales tienen índices optimizados

5. **Mantenibilidad:**
   - Proceso claro en 3 etapas bien definidas
   - Script único que ejecuta todo el pipeline
   - Fácil de re-ejecutar para actualizaciones
   - Colecciones intermedias permiten debugging

### Aprendizajes Clave

1. **Arquitectura de Dos Capas:**
   - Mantener colecciones base normalizadas facilita el proceso ETL
   - Separar colecciones finales permite optimización específica
   - CSV como formato intermedio da flexibilidad

2. **Desnormalización Inteligente:**
   - Las 4 colecciones finales cubren los casos de uso principales
   - Pre-calcular estadísticas ahorra tiempo en consultas
   - Evaluar patrones de acceso antes de decidir qué desnormalizar

3. **Pre-cálculo Selectivo:**
   - Colección `tops` para rankings frecuentes
   - `peliculas_por_director` para vistas agregadas comunes
   - ROI positivo en tiempo de respuesta

4. **Balance Storage vs Performance:**
   - 8 colecciones base + 4 finales = más espacio pero mejor rendimiento
   - Duplicación de datos acceptable si mejora significativamente las consultas
   - Colecciones base pueden limpiarse después si espacio es crítico

### Recomendaciones Futuras

1. **Gestión de Colecciones Base:**
   - Considerar eliminar las 8 colecciones base después de crear las finales si el espacio en disco es limitado
   - Mantenerlas si se planean actualizaciones incrementales
   - Documentar si deben conservarse para debugging

2. **Actualización de Datos:**
   - Para actualizaciones completas: re-ejecutar todo el proceso ETL
   - Para actualizaciones parciales: considerar scripts específicos que actualicen solo colecciones afectadas
   - Implementar timestamp de última actualización en cada colección

3. **Monitoreo:**
   - Implementar logging de tiempos de consulta en las 4 colecciones finales
   - Identificar slow queries para optimización adicional
   - Monitorear tamaño de documentos en colecciones finales

4. **Optimizaciones Adicionales:**
   - Si dataset crece a decenas de millones, considerar sharding
   - Shard key sugerido: `tipo` para producciones/series
   - Evaluar compresión WiredTiger para reducir espacio

5. **Automatización:**
   - Crear script para todo el pipeline: `extract_sql.sh → IMDBToMongo.js`
   - Considerar scheduling para actualizaciones periódicas
   - Implementar validaciones de datos entre etapas

6. **Caché de Aplicación:**
   - Implementar Redis/Memcached para colección `tops`
   - Reducir carga en MongoDB para consultas ultra-frecuentes de rankings
   - TTL corto (minutos/horas) ya que datos se actualizan raramente

---

## Referencias

- **MongoDB Aggregation Framework:** https://docs.mongodb.com/manual/aggregation/
- **Data Modeling Patterns:** https://www.mongodb.com/blog/post/building-with-patterns-a-summary
- **Performance Best Practices:** https://docs.mongodb.com/manual/administration/analyzing-mongodb-performance/
- **Schema Design Guide:** https://www.mongodb.com/developer/products/mongodb/schema-design-anti-pattern-summary/

---

**Documento preparado por:** Equipo de Desarrollo - Proyecto IMDB Fase 3  
**Fecha:** 26 de Octubre de 2025  
**Versión:** 1.1

---

## Anexo: Resumen del Proceso Completo

### Paso a Paso del Proceso de Migración

**1. Extracción desde PostgreSQL:**
- Se ejecutan 8 consultas SQL en la base de datos relacional
- Cada consulta se exporta manualmente como archivo CSV
- Los archivos CSV se colocan en `../data/csv/`

**2. Carga a MongoDB (Colecciones Base):**
- Se ejecuta `node --max-old-space-size=8192 IMDBToMongo.js`
- El script lee los 8 archivos CSV
- Crea 8 colecciones base normalizadas en MongoDB
- Estas colecciones son intermedias (no para uso final)

**3. Agregación (Colecciones Finales):**
- El mismo script continúa con agregaciones complejas
- Combina datos de las 8 colecciones base
- Genera las 4 colecciones finales desnormalizadas
- Estas son las únicas que usa la aplicación

**4. Resultado:**
- 4 colecciones finales optimizadas para consultas
- Tiempos de respuesta de <5ms para la mayoría de consultas
- Base de datos lista para producción

### Colecciones que Usa la Aplicación

✅ **producciones** - Para búsquedas de películas  
✅ **series** - Para búsquedas de series  
✅ **peliculas_por_director** - Para consultas por director  
✅ **tops** - Para rankings y estadísticas  

