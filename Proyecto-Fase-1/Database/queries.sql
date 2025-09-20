
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