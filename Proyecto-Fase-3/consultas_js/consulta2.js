use('fase3DB');
function q2_peliculasDeDirector(nombreDirector) {
  return db.peliculas_por_director.aggregate([
    { $match: { nombre: { $regex: `^${nombreDirector}$`, $options: "i" } } },
    { $project: { _id: 0, nombre: 1, "estadisticas.total_peliculas": 1, "estadisticas.rating_promedio": 1, peliculas: 1 } }
  ]).toArray();
}