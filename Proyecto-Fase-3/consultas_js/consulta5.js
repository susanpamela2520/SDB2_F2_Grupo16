use('fase3DB');
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
printjson(q5_top10actores());