// consultas.js
use('fase3DB');

function q1_buscarPorNombre(nombre) {
  return db.producciones.aggregate([
    { $match: { $or: [
      { titulo_original: { $regex: nombre, $options: "i" } },
      { "otros_titulos.titulo": { $regex: nombre, $options: "i" } }
    ]}},
    { $addFields: { __tipo: "produccion" } },
    { $unionWith: {
        coll: "series",
        pipeline: [
          { $match: { $or: [
            { titulo_original: { $regex: nombre, $options: "i" } },
            { "otros_titulos.titulo": { $regex: nombre, $options: "i" } }
          ]}},
          { $addFields: { __tipo: "serie" } }
        ]
    }},
    { $addFields: {
        votos_: { $ifNull: ["$rating.votos", -1] },
        rating_: { $ifNull: ["$rating.promedio", -1] }
    }},
    { $sort: { votos_: -1, rating_: -1, titulo_original: 1 } },
    { $project: { votos_: 0, rating_: 0 } },
    { $limit: 50 }
  ]).toArray();
}

function q2_peliculasDeDirector(nombreDirector) {
  return db.peliculas_por_director.aggregate([
    { $match: { nombre: { $regex: `^${nombreDirector}$`, $options: "i" } } },
    { $project: { _id: 0, nombre: 1, "estadisticas.total_peliculas": 1, "estadisticas.rating_promedio": 1, peliculas: 1 } }
  ]).toArray();
}

function q3_top10peliculas() {
  return db.tops.aggregate([
    { $match: { _id: "top_10_peliculas" } },
    { $unwind: "$peliculas" },
    { $sort: { "peliculas.posicion": 1 } },
    { $limit: 10 },
    { $project: { _id: 0, posicion: "$peliculas.posicion", id_titulo: "$peliculas.id_titulo", tipo: "$peliculas.tipo", "año": "$peliculas.año", rating: "$peliculas.rating", votos: "$peliculas.votos", generos: "$peliculas.generos", directores: "$peliculas.directores" } }
  ]).toArray();
}

function q4_directorConMasPeliculas() {
  return db.peliculas_por_director.aggregate([
    { $sort: { "estadisticas.total_peliculas": -1, nombre: 1 } },
    { $limit: 1 },
    { $project: { _id: 0, nombre: 1, "estadisticas.total_peliculas": 1 } }
  ]).toArray();
}

function q5_top10actores() {
  return db.producciones.aggregate([
    { $project: { actores: 1 } },
    { $unwind: "$actores" },
    { $project: { actor: "$actores.nombre" } },
    { $unionWith: {
        coll: "series",
        pipeline: [
          { $project: { actores: 1 } },
          { $unwind: "$actores" },
          { $project: { actor: "$actores.nombre" } }
        ]
    }},
    { $group: { _id: "$actor", total: { $sum: 1 } } },
    { $sort: { total: -1, _id: 1 } },
    { $limit: 10 },
    { $project: { _id: 0, actor: "$_id", total: 1 } }
  ]).toArray();
}

// Ejemplos de ejecución al cargar:
printjson(q1_buscarPorNombre("Quatermass"));
printjson(q2_peliculasDeDirector("Ingmar Bergman"));
printjson(q3_top10peliculas());
printjson(q4_directorConMasPeliculas());
printjson(q5_top10actores());
