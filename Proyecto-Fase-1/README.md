# IMDB Data Loader - Proyecto Fase 1

Este proyecto implementa una solución completa para cargar y procesar datos de IMDB en una base de datos MySQL. El sistema incluye herramientas para conversión de archivos, exploración de datos y carga masiva optimizada.

## Estructura del Proyecto

```
Proyecto-Fase-1/
├── CSVs/                     # Herramientas de conversión y exploración
│   ├── convertor.py          # Conversor TSV a CSV
│   ├── view-tsv.ipynb        # Notebook para exploración de datos
│   └── README.md             # Documentación específica de CSVs
├── Database/                 # Esquemas y consultas
│   ├── schema.sql            # Definición completa del esquema
│   └── queries.sql           # Consultas de ejemplo
├── LoadData/                 # Motor de carga de datos
│   ├── app.py                # Aplicación principal
│   └── imdb_loader.py        # Clase principal de carga
└── README.md                 # Este archivo
```

## Flujo de Trabajo Completo

### 1. Preparación de Archivos TSV

Los archivos TSV de IMDB deben descargarse y descomprimirse antes de comenzar. El sistema procesa los siguientes archivos oficiales de IMDB:

#### Archivos Requeridos:
- **`name.basics.tsv`** - Información básica de personas (actores, directores, escritores)
  - Descarga: https://datasets.imdbws.com/name.basics.tsv.gz
  - Contiene: nconst, primaryName, birthYear, deathYear, primaryProfession, knownForTitles

- **`title.basics.tsv`** - Información básica de producciones 
  - Descarga: https://datasets.imdbws.com/title.basics.tsv.gz
  - Contiene: tconst, titleType, primaryTitle, originalTitle, isAdult, startYear, endYear, runtimeMinutes, genres

- **`title.akas.tsv`** - Títulos alternativos y traducciones
  - Descarga: https://datasets.imdbws.com/title.akas.tsv.gz
  - Contiene: titleId, ordering, title, region, language, types, attributes, isOriginalTitle

- **`title.crew.tsv`** - Información de crew (directores y escritores)
  - Descarga: https://datasets.imdbws.com/title.crew.tsv.gz
  - Contiene: tconst, directors, writers

- **`title.episode.tsv`** - Información de episodios de series
  - Descarga: https://datasets.imdbws.com/title.episode.tsv.gz
  - Contiene: tconst, parentTconst, seasonNumber, episodeNumber

- **`title.principals.tsv`** - Elenco principal y crew de cada título
  - Descarga: https://datasets.imdbws.com/title.principals.tsv.gz
  - Contiene: tconst, ordering, nconst, category, job, characters

- **`title.ratings.tsv`** - Calificaciones y votos de IMDb
  - Descarga: https://datasets.imdbws.com/title.ratings.tsv.gz
  - Contiene: tconst, averageRating, numVotes


### 2. Conversión TSV a CSV (Opcional)

Aunque no es estrictamente necesario, puedes convertir archivos TSV a CSV para mayor compatibilidad:

```python
# Usar convertor.py
python CSVs/convertor.py
```

El script `convertor.py` proporciona funciones para convertir formatos:
- Manejo automático de delimitadores
- Preservación de encoding UTF-8
- Validación de estructura de datos

### 3. Exploración de Datos

Antes de la carga masiva, usa el notebook para explorar y validar los datos:

```bash
# Abrir Jupyter Notebook
jupyter notebook CSVs/view-tsv.ipynb
```

**Características del notebook:**
- **Lectura de muestras**: Lee las primeras 1000 líneas para análisis rápido
- **Validación de estructura**: Verifica columnas y tipos de datos
- **Estadísticas básicas**: Cuenta registros y identifica valores faltantes
- **Visualización**: Muestra ejemplos de datos para validación manual

**Ejemplo de uso en el notebook:**
```python
import pandas as pd

# Leer primeras 1000 líneas de un archivo TSV
df = pd.read_csv('path/to/file.tsv', sep='\t', nrows=1000)
print(f"Registros leídos: {len(df)}")
print(f"Columnas: {list(df.columns)}")
df.head()
```

### 4. Preparación de Base de Datos

Ejecuta el script de esquema para crear todas las tablas:

```sql
-- Ejecutar en MySQL
source Database/schema.sql;
```

**Esquema de Base de Datos:**
- **personas**: Información de actores, directores, etc.
- **produccion**: Películas, series, episodios
- **profesiones**: Catálogo de profesiones
- **generos**: Catálogo de géneros
- **tipo_produccion**: Tipos (movie, tvSeries, etc.)
- **atributos**: Atributos especiales
- **Tablas de relación**: personas_produccion, genero_produccion, etc.

### 5. Carga Masiva de Datos

El motor principal está en `LoadData/imdb_loader.py`. Este sistema fue optimizado para manejar millones de registros eficientemente.

#### Configuración de Conexión

```python
from imdb_loader import IMDBDataLoader

# Configurar conexión
db_config = {
    'host': 'localhost',
    'user': 'root',
    'password': 'tu_password',
    'database': 'imdb_fase1',
    'charset': 'utf8mb4'
}

# Ruta donde están los archivos TSV
tsv_path = "./imdb_data/"

loader = IMDBDataLoader(db_config, tsv_path)
```

#### Proceso de Carga Completo

```python
# Ejecutar carga completa
loader.load_all_data()
```

**El proceso interno incluye:**

1. **Catálogos** (orden crítico):
   - Profesiones (de name.basics.tsv + title.principals.tsv)
   - Géneros (de title.basics.tsv)
   - Tipos de producción (de title.basics.tsv)
   - Atributos (de title.akas.tsv)

2. **Entidades principales**:
   - Personas (de name.basics.tsv + title.principals.tsv)
   - Producción (de title.basics.tsv + title.akas.tsv)

3. **Relaciones**:
   - Top profesiones (name.basics.tsv)
   - Género-producción (title.basics.tsv)
   - Nombres de producción (title.akas.tsv)
   - Atributos de títulos (title.akas.tsv)
   - Personas-producción (title.principals.tsv + title.crew.tsv)
   - Personajes (title.principals.tsv)
   - Episodios (title.episode.tsv)

4. **Actualizaciones finales**:
   - Ratings (title.ratings.tsv)
   - Conocido por (name.basics.tsv)

## Características Técnicas

### Optimizaciones Implementadas

1. **IDs Secuenciales**: Se resolvió un problema crítico de hash collision reemplazando la generación de IDs basada en hash con IDs secuenciales para todos los catálogos.

2. **Conexión Persistente**: Sistema de keep-alive para mantener conexiones activas durante cargas largas.

3. **Inserción por Lotes**: Método `insert_fast()` procesa 200,000 registros por lote para optimizar rendimiento.

4. **Manejo de Reconexión**: Sistema automático de retry para reconexiones perdidas.

5. **Índices de Rendimiento**: 
```sql
-- Índices recomendados para optimizar consultas
CREATE INDEX idx_personas_nombre ON personas(nombre);
CREATE INDEX idx_produccion_rating ON produccion(promedio_rating DESC);
CREATE INDEX idx_nombres_produccion_busqueda ON nombres_produccion(nombres_produccion);
CREATE INDEX idx_personas_produccion_persona ON personas_produccion(id_persona);
CREATE INDEX idx_personas_produccion_prod ON personas_produccion(id_produccion);
```

### Resolución de Problemas Técnicos

**Problema Original**: Durante las pruebas se detectó que solo se insertaban 5 de 12 tipos de producción, a pesar de leer correctamente todos los registros del archivo.

**Causa Raíz**: El método `generate_id()` basado en hash generaba IDs duplicados debido a colisiones hash, causando violaciones de clave primaria que se enmascaraban con `INSERT IGNORE`.

**Solución Implementada**: 
- Reemplazó `generate_id(value)` con contadores secuenciales
- Eliminó dependencia de hash para IDs únicos
- Implementó validación de inserción exitosa

```python
# Antes (problemático)
def generate_id(self, value):
    return hash(value) % 1000000

# Después (solución)
def load_title_types(self):
    type_id = 0
    for title_type in sorted(types):
        self.titletype_ids[title_type] = type_id
        data.append((type_id, title_type))
        type_id += 1
```

## Requisitos del Sistema

### Software Necesario
- Python 3.8+
- MySQL 8.0+
- Jupyter Notebook
- 16+ GB RAM recomendado
- 50+ GB espacio libre en disco

### Instalación de Dependencias

```bash
pip install pandas mysql-connector-python
```

## Notas de Desarrollo

- Los archivos TSV de IMDB contienen valores `\N` para campos nulos
- El sistema maneja automáticamente conversión de encoding UTF-8
- Las transacciones se optimizan para lotes de 200,000 registros
- Se implementa retry automático para reconexiones de base de datos
- Los archivos se procesan en orden específico debido a dependencias de claves foráneas

---

**Desarrollado para el curso de Bases de Datos 2 - Grupo 16**  
**Universidad de San Carlos de Guatemala - Facultad de Ingeniería**