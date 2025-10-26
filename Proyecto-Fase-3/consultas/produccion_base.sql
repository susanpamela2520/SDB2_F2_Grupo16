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