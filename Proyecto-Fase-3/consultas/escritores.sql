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