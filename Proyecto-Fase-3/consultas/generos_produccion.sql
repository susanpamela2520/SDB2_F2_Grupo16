SELECT 
  gp.id_produccion,
  g.genero
FROM genero_produccion gp
JOIN generos g ON g.id_genero = gp.id_genero
ORDER BY gp.id_produccion, g.genero;