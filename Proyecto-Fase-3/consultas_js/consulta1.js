use('fase3DB');

function q1_buscarPorNombre(nombre, limit=50) {
  const rx = new RegExp(nombre, "i"); 
  return db.producciones.aggregate([
    { $match: { $or: [
      { titulo_original: { $regex: rx } },
      { "otros_titulos.titulo": { $regex: rx } }
    ]}},
    { $addFields: { __tipo: "produccion" } },
    { $unionWith: {
        coll: "series",
        pipeline: [
          { $match: { $or: [
            { titulo_original: { $regex: rx } },
            { "otros_titulos.titulo": { $regex: rx } }
          ]}},
          { $addFields: { __tipo: "serie" } }
        ]
    }},
    { $addFields: {
        votos_: { $ifNull: ["$rating.votos", -1] },
        rating_: { $ifNull: ["$rating.promedio", -1] }
    }},
    { $sort: { votos_: -1, rating_: -1, titulo_original: 1 } },
    { $limit: limit },
    { $project: { votos_: 0, rating_: 0 } }
  ], { allowDiskUse: true }).toArray();
}

printjson(q1_buscarPorNombre("Matrix", 20));// Aqui se cambia el nombre y el limite de resultados