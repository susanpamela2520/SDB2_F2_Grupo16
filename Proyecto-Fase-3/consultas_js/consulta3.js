
function q3_top10peliculas() {
  return db.tops.aggregate([
    { $match: { _id: "top_10_peliculas" } },
    { $unwind: "$peliculas" },
    { $sort: { "peliculas.posicion": 1 } },
    { $limit: 10 },
    { $project: { _id: 0, posicion: "$peliculas.posicion", id_titulo: "$peliculas.id_titulo", tipo: "$peliculas.tipo", "año": "$peliculas.año", rating: "$peliculas.rating", votos: "$peliculas.votos", generos: "$peliculas.generos", directores: "$peliculas.directores" } }
  ]).toArray();
}
