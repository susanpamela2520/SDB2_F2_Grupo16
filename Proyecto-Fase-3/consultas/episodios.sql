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