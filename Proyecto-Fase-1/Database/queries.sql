
-- ! selects para ver la cantidad de registros en cada tabla **
SELECT COUNT(*) AS total_profesiones FROM profesiones;
SELECT COUNT(*) AS total_generos FROM generos;
SELECT COUNT(*) AS total_tipo_produccion FROM tipo_produccion;
SELECT COUNT(*) AS total_atributos FROM atributos;
SELECT COUNT(*) AS total_personas FROM personas;
SELECT COUNT(*) AS total_produccion FROM produccion;
SELECT COUNT(*) AS total_top_profesiones FROM top_profesiones;
SELECT COUNT(*) AS total_genero_produccion FROM genero_produccion;
SELECT COUNT(*) AS total_nombres_produccion FROM nombres_produccion;
SELECT COUNT(*) AS total_nombres_titulos_atributos FROM nombres_titulos_atributos;
SELECT COUNT(*) AS total_personas_produccion FROM personas_produccion;
SELECT COUNT(*) AS total_personajes FROM personajes;
SELECT COUNT(*) AS total_episodios FROM episodios;

-- ! SELECT para ver las personas que son conocidas por la producción con id 3
SELECT
    p.id_persona,
    p.nombre,
    pp.conocido_por,
    pr.nombres_produccion
FROM personas_produccion pp
JOIN personas p ON pp.id_persona = p.id_persona
LEFT JOIN nombres_produccion pr ON pr.id_produccion = pp.id_produccion AND pr.orden = 1
WHERE pp.id_produccion = 3
  AND pp.conocido_por IS NOT NULL
ORDER BY pp.conocido_por;

-- ! SELECT que muestra el id, el nombre y el año de inicio de todas las producciones que contienen "Shrek" en el nombre
SELECT
    p.id_titulo,
    np.nombres_produccion,
    p.ahno_inicio
FROM produccion p
JOIN nombres_produccion np ON p.id_titulo = np.id_produccion
WHERE np.nombres_produccion LIKE '%Shrek%'
ORDER BY p.ahno_inicio;

-- procedimiento de peluculas de un director

DELIMITER //
CREATE PROCEDURE sp_peliculas_director(
    IN p_id_persona INT
)
BEGIN
    SELECT 
        p.id_titulo,
        np.nombres_produccion AS titulo_pelicula,
        p.ahno_inicio AS año_estreno,
        p.minutos_duracion AS duracion,
        p.promedio_rating AS rating,
        p.votos,
        tp.tipo_produccion
    FROM produccion p
    INNER JOIN personas_produccion pp ON p.id_titulo = pp.id_produccion
    INNER JOIN personas per ON pp.id_persona = per.id_persona
    INNER JOIN profesiones prof ON pp.id_profesion = prof.id_profesion
    INNER JOIN tipo_produccion tp ON p.id_tipo_titulo = tp.id_tipo_produccion
    LEFT JOIN nombres_produccion np ON p.id_titulo = np.id_produccion AND np.esOriginal = TRUE
    WHERE pp.id_persona = p_id_persona
        AND prof.profesion = 'director'
        AND tp.tipo_produccion IN ('movie', 'película')
    ORDER BY p.ahno_inicio DESC, p.promedio_rating DESC;
END //
DELIMITER ;


-- P4liiculas con mejor rating

SELECT 
    p.id_titulo,
    np.nombres_produccion AS titulo_pelicula,
    p.promedio_rating AS rating,
    p.votos,
    p.ahno_inicio AS año_estreno,
    p.minutos_duracion AS duracion,
    tp.tipo_produccion
FROM produccion p
INNER JOIN tipo_produccion tp ON p.id_tipo_titulo = tp.id_tipo_produccion
LEFT JOIN nombres_produccion np ON p.id_titulo = np.id_produccion AND np.esOriginal = TRUE
WHERE tp.tipo_produccion IN ('movie', 'película')
    AND p.promedio_rating IS NOT NULL
    AND p.votos >= 1000  -- Filtro para asegurar relevancia (ajustable)
ORDER BY p.promedio_rating DESC, p.votos DESC
LIMIT 10;

--  director con ms peliculas 

SELECT 
    per.id_persona,
    per.nombre AS director,
    COUNT(DISTINCT p.id_titulo) AS total_peliculas,
    AVG(p.promedio_rating) AS rating_promedio,
    SUM(p.votos) AS total_votos
FROM personas per
INNER JOIN personas_produccion pp ON per.id_persona = pp.id_persona
INNER JOIN profesiones prof ON pp.id_profesion = prof.id_profesion
INNER JOIN produccion p ON pp.id_produccion = p.id_titulo
INNER JOIN tipo_produccion tp ON p.id_tipo_titulo = tp.id_tipo_produccion
WHERE prof.profesion = 'director'
    AND tp.tipo_produccion IN ('movie', 'película')
GROUP BY per.id_persona, per.nombre
ORDER BY total_peliculas DESC, rating_promedio DESC
LIMIT 1;

-- 10 actores con masc pelculas

SELECT 
    per.id_persona,
    per.nombre AS actor,
    COUNT(DISTINCT p.id_titulo) AS total_peliculas,
    AVG(p.promedio_rating) AS rating_promedio_peliculas,
    MIN(p.ahno_inicio) AS primera_pelicula,
    MAX(p.ahno_inicio) AS ultima_pelicula,
    SUM(p.votos) AS total_votos_acumulados
FROM personas per
INNER JOIN personas_produccion pp ON per.id_persona = pp.id_persona
INNER JOIN profesiones prof ON pp.id_profesion = prof.id_profesion
INNER JOIN produccion p ON pp.id_produccion = p.id_titulo
INNER JOIN tipo_produccion tp ON p.id_tipo_titulo = tp.id_tipo_produccion
WHERE prof.profesion IN ('actor', 'actress', 'actriz')
    AND tp.tipo_produccion IN ('movie', 'película')
GROUP BY per.id_persona, per.nombre
HAVING total_peliculas >= 5  -- Solo actores con al menos 5 películas
ORDER BY total_peliculas DESC, rating_promedio_peliculas DESC
LIMIT 10;