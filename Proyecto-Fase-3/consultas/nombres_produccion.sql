SELECT 
  id_produccion,
  orden,
  nombres_produccion AS titulo,
  region,
  lenguaje,
  esOriginal AS es_original
FROM nombres_produccion
ORDER BY id_produccion, orden;