-- ===============================================
-- PROCEDIMIENTOS Y CONSULTAS OPTIMIZADAS - PostgreSQL
-- ===============================================

-- ===============================================
-- 1. PROCEDIMIENTO: BUSCAR PRODUCCION (CORREGIDO)
-- ===============================================
CREATE OR REPLACE FUNCTION buscar_produccion(
    p_id INT DEFAULT NULL,
    p_nombre VARCHAR(500) DEFAULT NULL
)
RETURNS TABLE (
    id_produccion INT,
    nombre VARCHAR(500),
    tipo VARCHAR(100),
    duracion_minutos INT,
    promedio_rating NUMERIC(4,2),
    adulto BOOLEAN,
    tambien_conocido_como TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_id IS NULL AND (p_nombre IS NULL OR LENGTH(TRIM(p_nombre)) = 0) THEN
        RAISE EXCEPTION 'Debe proporcionar p_id o p_nombre';
    END IF;

    RETURN QUERY
    SELECT
        prod.id_titulo AS id_produccion,
        COALESCE(
            (SELECT np.nombres_produccion
             FROM nombres_produccion np
             WHERE np.id_produccion = prod.id_titulo
               AND (p_nombre IS NULL OR LOWER(np.nombres_produccion) = LOWER(TRIM(p_nombre)))
             ORDER BY np.esOriginal DESC, np.orden
             LIMIT 1),
            (SELECT np.nombres_produccion
             FROM nombres_produccion np
             WHERE np.id_produccion = prod.id_titulo
             ORDER BY np.orden
             LIMIT 1)
        ) AS nombre,
        tp.tipo_produccion AS tipo,
        prod.minutos_duracion AS duracion_minutos,
        prod.promedio_rating,
        prod.adultos AS adulto,
        (SELECT STRING_AGG(DISTINCT np2.nombres_produccion, ' | ' ORDER BY np2.nombres_produccion)
         FROM nombres_produccion np2
         WHERE np2.id_produccion = prod.id_titulo
           AND np2.orden > 1) AS tambien_conocido_como
    FROM produccion prod
    JOIN tipo_produccion tp ON prod.id_tipo_titulo = tp.id_tipo_produccion
    WHERE (p_id IS NULL OR prod.id_titulo = p_id)
      AND (p_nombre IS NULL OR prod.id_titulo IN (
          SELECT np3.id_produccion
          FROM nombres_produccion np3
          WHERE LOWER(np3.nombres_produccion) = LOWER(TRIM(p_nombre))
      ))
    LIMIT 20;
END;
$$;


-- ===============================================
-- 2. PROCEDIMIENTO: PELICULAS DE UN DIRECTOR (CORREGIDO)
-- ===============================================
CREATE OR REPLACE FUNCTION sp_peliculas_director(
    p_id_persona INT DEFAULT NULL,
    p_nombre_persona VARCHAR(200) DEFAULT NULL
)
RETURNS TABLE (
    id_titulo INT,
    titulo_pelicula VARCHAR(500),
    año_estreno DATE,
    duracion_minutos INT,
    rating NUMERIC(4,2),
    votos INT,
    tipo_produccion VARCHAR(100)
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_id_persona IS NULL AND (p_nombre_persona IS NULL OR LENGTH(TRIM(p_nombre_persona)) = 0) THEN
        RAISE EXCEPTION 'Debe proporcionar p_id_persona o p_nombre_persona';
    END IF;

    RETURN QUERY
    SELECT
        prod.id_titulo,
        COALESCE(
            (SELECT np.nombres_produccion
             FROM nombres_produccion np
             WHERE np.id_produccion = prod.id_titulo AND np.esOriginal = TRUE
             LIMIT 1),
            (SELECT np.nombres_produccion
             FROM nombres_produccion np
             WHERE np.id_produccion = prod.id_titulo
             ORDER BY np.orden
             LIMIT 1)
        ) AS titulo_pelicula,
        prod.ahno_inicio AS año_estreno,
        prod.minutos_duracion,
        prod.promedio_rating AS rating,
        prod.votos,
        tp.tipo_produccion
    FROM produccion prod
    JOIN personas_produccion pp ON prod.id_titulo = pp.id_produccion
    JOIN personas per ON pp.id_persona = per.id_persona
    JOIN profesiones prof ON pp.id_profesion = prof.id_profesion
    JOIN tipo_produccion tp ON prod.id_tipo_titulo = tp.id_tipo_produccion
    WHERE LOWER(prof.profesion) = 'director'
      AND tp.tipo_produccion IN ('movie', 'tvMovie')
      AND (
          (p_id_persona IS NOT NULL AND pp.id_persona = p_id_persona)
          OR (p_nombre_persona IS NOT NULL AND per.nombre ILIKE '%' || TRIM(p_nombre_persona) || '%')
      )
    ORDER BY prod.ahno_inicio DESC NULLS LAST, prod.promedio_rating DESC NULLS LAST;
END;
$$;


-- ===============================================
-- 3. SELECT: TOP 10 PELICULAS CON MEJOR RATING
-- ===============================================
SELECT
    p.id_titulo,
    COALESCE(
        (SELECT np.nombres_produccion
         FROM nombres_produccion np
         WHERE np.id_produccion = p.id_titulo AND np.esOriginal = TRUE
         LIMIT 1),
        (SELECT np.nombres_produccion
         FROM nombres_produccion np
         WHERE np.id_produccion = p.id_titulo
         ORDER BY np.orden
         LIMIT 1)
    ) AS titulo_pelicula,
    p.promedio_rating AS rating,
    p.votos,
    p.ahno_inicio AS año_estreno,
    p.minutos_duracion AS duracion_minutos,
    tp.tipo_produccion
FROM produccion p
JOIN tipo_produccion tp ON p.id_tipo_titulo = tp.id_tipo_produccion
WHERE tp.tipo_produccion IN ('movie', 'tvMovie')
  AND p.promedio_rating IS NOT NULL
  AND p.votos >= 1000
ORDER BY p.promedio_rating DESC, p.votos DESC
LIMIT 10;


-- ===============================================
-- 4. SELECT: DIRECTOR CON MAS PELICULAS
-- ===============================================
SELECT
    per.id_persona,
    per.nombre AS director,
    COUNT(DISTINCT p.id_titulo) AS total_peliculas,
    ROUND(AVG(p.promedio_rating), 2) AS rating_promedio,
    SUM(p.votos) AS total_votos
FROM personas per
JOIN personas_produccion pp ON per.id_persona = pp.id_persona
JOIN profesiones prof ON pp.id_profesion = prof.id_profesion
JOIN produccion p ON pp.id_produccion = p.id_titulo
JOIN tipo_produccion tp ON p.id_tipo_titulo = tp.id_tipo_produccion
WHERE LOWER(prof.profesion) = 'director'
  AND tp.tipo_produccion = 'movie'
GROUP BY per.id_persona, per.nombre
ORDER BY total_peliculas DESC, rating_promedio DESC
LIMIT 1;


-- ===============================================
-- 5. SELECT: TOP 10 ACTORES CON MAS PELICULAS
-- ===============================================
SELECT
    per.id_persona,
    per.nombre AS actor,
    COUNT(DISTINCT p.id_titulo) AS total_peliculas,
    ROUND(AVG(p.promedio_rating), 2) AS rating_promedio,
    MIN(p.ahno_inicio) AS primera_pelicula,
    MAX(p.ahno_inicio) AS ultima_pelicula,
    SUM(p.votos) AS total_votos
FROM personas per
JOIN personas_produccion pp ON per.id_persona = pp.id_persona
JOIN profesiones prof ON pp.id_profesion = prof.id_profesion
JOIN produccion p ON pp.id_produccion = p.id_titulo
JOIN tipo_produccion tp ON p.id_tipo_titulo = tp.id_tipo_produccion
WHERE LOWER(prof.profesion) IN ('actor', 'actress')
  AND tp.tipo_produccion IN ('movie', 'tvMovie')
GROUP BY per.id_persona, per.nombre
HAVING COUNT(DISTINCT p.id_titulo) >= 5
ORDER BY total_peliculas DESC, rating_promedio DESC
LIMIT 10;


-- ===============================================
-- EJEMPLOS DE USO
-- ===============================================

-- Buscar por nombre
SELECT * FROM buscar_produccion(NULL, 'The Matrix');

-- Buscar por ID
SELECT * FROM buscar_produccion(111161, NULL);

-- Películas de director por ID
SELECT * FROM sp_peliculas_director(5, NULL);

-- Películas de director por nombre
SELECT * FROM sp_peliculas_director(NULL, 'Christopher Nolan');


-- ===============================================
-- ÍNDICES OPTIMIZADOS PARA CONSULTAS Y PROCEDIMIENTOS
-- ===============================================

-- ===============================================
-- 1. ÍNDICES PARA buscar_produccion()
-- ===============================================

-- Búsqueda por nombre (case-insensitive)
CREATE INDEX idx_nombres_produccion_lower
ON nombres_produccion (LOWER(nombres_produccion), id_produccion);

-- Priorizar nombres originales
CREATE INDEX idx_nombres_produccion_original
ON nombres_produccion (id_produccion, esOriginal DESC, orden);


-- ===============================================
-- 2. ÍNDICES PARA sp_peliculas_director()
-- ===============================================

-- Búsqueda de directores por profesión
CREATE INDEX idx_profesiones_lower
ON profesiones (LOWER(profesion));

-- Relación persona-producción-profesión
CREATE INDEX idx_personas_produccion_composite
ON personas_produccion (id_persona, id_profesion, id_produccion);

-- Búsqueda de personas por nombre (case-insensitive)
CREATE INDEX idx_personas_nombre_lower
ON personas (LOWER(nombre), id_persona);

-- Filtrar por tipo de producción
CREATE INDEX idx_produccion_tipo
ON produccion (id_tipo_titulo, id_titulo);


-- ===============================================
-- 3. ÍNDICES PARA TOP PELÍCULAS CON MEJOR RATING
-- ===============================================

-- Ordenar por rating y filtrar por votos
CREATE INDEX idx_produccion_rating
ON produccion (promedio_rating DESC, votos DESC)
WHERE promedio_rating IS NOT NULL AND votos >= 1000;


-- ===============================================
-- 4. ÍNDICES PARA DIRECTOR CON MÁS PELÍCULAS
-- ===============================================

-- Ya cubierto por:
-- - idx_personas_produccion_composite
-- - idx_profesiones_lower
-- - idx_produccion_tipo


-- ===============================================
-- 5. ÍNDICES PARA TOP ACTORES CON MÁS PELÍCULAS
-- ===============================================

-- Búsqueda de actores/actrices por profesión
-- (Ya cubierto por idx_profesiones_lower, pero agregamos uno específico)
CREATE INDEX idx_personas_produccion_actor
ON personas_produccion (id_profesion, id_persona, id_produccion)
WHERE id_profesion IN (
    SELECT id_profesion FROM profesiones
    WHERE LOWER(profesion) IN ('actor', 'actress')
);


-- ===============================================
-- 6. ÍNDICES ADICIONALES PARA RENDIMIENTO GENERAL
-- ===============================================

-- Ordenar producciones por fecha
CREATE INDEX idx_produccion_fecha_rating
ON produccion (ahno_inicio DESC NULLS LAST, promedio_rating DESC NULLS LAST);

-- Relación producción-género (para filtros futuros)
CREATE INDEX idx_genero_produccion_id
ON genero_produccion (id_genero, id_produccion);


-- ===============================================
-- VERIFICAR ÍNDICES CREADOS
-- ===============================================

-- Ver todos los índices de la base de datos
SELECT
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;


-- ===============================================
-- ESTADÍSTICAS DE USO (ejecutar después de pruebas)
-- ===============================================

-- Ver qué índices se están usando
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan as num_scans,
    idx_tup_read as tuples_read,
    idx_tup_fetch as tuples_fetched
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan DESC;


-- ===============================================
-- MANTENIMIENTO (ejecutar periódicamente)
-- ===============================================

-- Actualizar estadísticas para el optimizador
ANALYZE;

-- Reconstruir índices si es necesario (después de cargas masivas)
-- REINDEX DATABASE "bases2-db";