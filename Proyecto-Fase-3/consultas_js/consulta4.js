use('fase3DB');
function q4_directorConMasPeliculas() {
  return db.peliculas_por_director.aggregate([
    { $sort: { "estadisticas.total_peliculas": -1, nombre: 1 } },
    { $limit: 1 },
    { $project: { _id: 0, nombre: 1, "estadisticas.total_peliculas": 1 } }
  ]).toArray();
}
printjson(q4_directorConMasPeliculas());