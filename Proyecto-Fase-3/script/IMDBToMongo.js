const fs = require('fs');
const csv = require('csv-parser');
const { MongoClient } = require('mongodb');
const path = require('path');

const MONGO_URI = 'mongodb://localhost:27017';
const DB_NAME = 'imdb';
const CSV_DIR = '../data/csv';

class IMDBToMongo {
  constructor() {
    this.client = null;
    this.db = null;
  }

  async connect() {
    console.log('Conectando a MongoDB...');
    this.client = await MongoClient.connect(MONGO_URI);
    this.db = this.client.db(DB_NAME);
    console.log('Conectado\n');
  }

  async disconnect() {
    if (this.client) {
      await this.client.close();
      console.log('Desconectado de MongoDB');
    }
  }

  async streamCSVToMongo(filename, collectionName, transformer) {
    return new Promise((resolve, reject) => {
      const filePath = path.join(__dirname, CSV_DIR, filename);
      console.log(`Procesando ${filename}...`);

      let batch = [];
      let count = 0;
      const BATCH_SIZE = 5000;
      const stream = fs.createReadStream(filePath).pipe(csv());

      stream.on('data', (row) => {
        try {
          const doc = transformer(row);
          if (doc) batch.push(doc);

          if (batch.length >= BATCH_SIZE) {
            stream.pause();

            const batchToInsert = [...batch];
            batch = [];
            count += batchToInsert.length;

            this.db.collection(collectionName)
              .insertMany(batchToInsert, { ordered: false })
              .then(() => {
                console.log(`  → ${count.toLocaleString()} documentos insertados...`);
                stream.resume();
              })
              .catch((err) => {
                if (err.code !== 11000) {
                  console.error('Error insertando:', err.message);
                }
                stream.resume();
              });
          }
        } catch (err) {
          // Ignorar errores de transformación
        }
      });

      stream.on('end', async () => {
        if (batch.length > 0) {
          count += batch.length;
          try {
            await this.db.collection(collectionName).insertMany(batch, { ordered: false });
          } catch (err) {
            if (err.code !== 11000) {
              console.error('Error en último batch:', err.message);
            }
          }
        }
        console.log(`Total: ${count.toLocaleString()} documentos\n`);
        resolve(count);
      });

      stream.on('error', reject);
    });
  }

  async buildProducciones() {
    console.log('CONSTRUYENDO: producciones_base\n');
    await this.db.collection('producciones_base').deleteMany({});
    
    await this.streamCSVToMongo('produccion_base.csv', 'producciones_base', (row) => ({
      _id: parseInt(row.id_titulo),
      tipo: row.tipo_produccion,
      adultos: row.adultos === 't',
      año_inicio: row.año_inicio ? parseInt(row.año_inicio) : null,
      año_fin: row.año_fin ? parseInt(row.año_fin) : null,
      duracion_minutos: row.minutos_duracion ? parseInt(row.minutos_duracion) : null,
      promedio_rating: row.promedio_rating ? parseFloat(row.promedio_rating) : null,
      votos: row.votos ? parseInt(row.votos) : null
    }));
  }

  async buildNombres() {
    console.log('CONSTRUYENDO: nombres\n');
    await this.db.collection('nombres').deleteMany({});
    
    await this.streamCSVToMongo('nombres_produccion.csv', 'nombres', (row) => ({
      id_produccion: parseInt(row.id_produccion),
      titulo: row.titulo,
      es_original: row.es_original === 't',
      region: row.region || '',
      lenguaje: row.lenguaje || '',
      orden: parseInt(row.orden) || 0
    }));
  }

  async buildGeneros() {
    console.log('CONSTRUYENDO: generos\n');
    await this.db.collection('generos').deleteMany({});
    
    await this.streamCSVToMongo('generos_produccion.csv', 'generos', (row) => ({
      id_produccion: parseInt(row.id_produccion),
      genero: row.genero
    }));
  }

  async buildActores() {
    console.log('CONSTRUYENDO: actores\n');
    await this.db.collection('actores').deleteMany({});
    
    await this.streamCSVToMongo('actores.csv', 'actores', (row) => ({
      id_produccion: parseInt(row.id_produccion),
      id_persona: parseInt(row.id_persona),
      nombre: row.nombre,
      orden: parseInt(row.orden)
    }));
  }

  async buildDirectores() {
    console.log('CONSTRUYENDO: directores\n');
    await this.db.collection('directores').deleteMany({});
    
    await this.streamCSVToMongo('directores.csv', 'directores', (row) => ({
      id_produccion: parseInt(row.id_produccion),
      id_persona: parseInt(row.id_persona),
      nombre: row.nombre,
      orden: parseInt(row.orden)
    }));
  }

  async buildEscritores() {
    console.log('CONSTRUYENDO: escritores\n');
    await this.db.collection('escritores').deleteMany({});
    
    await this.streamCSVToMongo('escritores.csv', 'escritores', (row) => ({
      id_produccion: parseInt(row.id_produccion),
      id_persona: parseInt(row.id_persona),
      nombre: row.nombre,
      orden: parseInt(row.orden)
    }));
  }

  async buildPersonajes() {
    console.log('CONSTRUYENDO: personajes\n');
    await this.db.collection('personajes').deleteMany({});
    
    await this.streamCSVToMongo('personajes.csv', 'personajes', (row) => ({
      id_produccion: parseInt(row.id_produccion),
      persona_id: parseInt(row.persona_id),
      personaje: row.personaje
    }));
  }

  async buildEpisodios() {
    console.log('CONSTRUYENDO: episodios\n');
    const filePath = path.join(__dirname, CSV_DIR, 'episodios.csv');
    
    if (!fs.existsSync(filePath)) {
      console.log('Archivo episodios.csv no encontrado\n');
      return;
    }

    await this.db.collection('episodios').deleteMany({});
    
    await this.streamCSVToMongo('episodios.csv', 'episodios', (row) => ({
      id_serie: parseInt(row.id_serie),
      id_episodio: parseInt(row.id_episodio),
      temporada: row.temporada ? parseInt(row.temporada) : null,
      episodio: row.episodio ? parseInt(row.episodio) : null,
      titulo_episodio: row.titulo_episodio || null
    }));
  }

  async createBaseIndexes() {
    console.log('CREANDO ÍNDICES EN COLECCIONES BASE...\n');

    await this.db.collection('nombres').createIndex({ id_produccion: 1 });
    await this.db.collection('generos').createIndex({ id_produccion: 1 });
    await this.db.collection('actores').createIndex({ id_produccion: 1 });
    await this.db.collection('directores').createIndex({ id_produccion: 1 });
    await this.db.collection('escritores').createIndex({ id_produccion: 1 });
    await this.db.collection('personajes').createIndex({ id_produccion: 1, persona_id: 1 });
    await this.db.collection('episodios').createIndex({ id_serie: 1 });
    await this.db.collection('producciones_base').createIndex({ tipo: 1 });

    console.log('Índices base creados\n');
  }

  async createAggregatedCollections() {
    console.log('\nCREANDO COLECCIONES AGREGADAS...\n');

    // ========================================
    // 1. PRODUCCIONES (PASO 1: estructura básica)
    // ========================================
    console.log('Paso 1: Creando estructura base de producciones...');
    await this.db.collection('producciones').drop().catch(() => {});
    
    await this.db.collection('producciones_base').aggregate([
      {
        $match: {
          tipo: { $in: ['movie', 'short', 'tvMovie', 'tvShort', 'tvSpecial', 'video', 'videoGame', 'tvPilot', 'tvMiniSeries'] }
        }
      },
      {
        $lookup: {
          from: 'nombres',
          localField: '_id',
          foreignField: 'id_produccion',
          as: 'nombres_data'
        }
      },
      {
        $lookup: {
          from: 'generos',
          localField: '_id',
          foreignField: 'id_produccion',
          as: 'generos_data'
        }
      },
      {
        $lookup: {
          from: 'actores',
          localField: '_id',
          foreignField: 'id_produccion',
          as: 'actores_data'
        }
      },
      {
        $lookup: {
          from: 'directores',
          localField: '_id',
          foreignField: 'id_produccion',
          as: 'directores_data'
        }
      },
      {
        $lookup: {
          from: 'escritores',
          localField: '_id',
          foreignField: 'id_produccion',
          as: 'escritores_data'
        }
      },
      {
        $project: {
          _id: 1,
          tipo: 1,
          adultos: 1,
          año_inicio: 1,
          año_fin: 1,
          duracion_minutos: 1,
          // EXTRAER TITULO ORIGINAL DIRECTAMENTE
          titulo_original: {
            $let: {
              vars: {
                tituloObj: {
                  $arrayElemAt: [
                    {
                      $filter: {
                        input: '$nombres_data',
                        as: 'nom',
                        cond: { $eq: ['$$nom.es_original', true] }
                      }
                    },
                    0
                  ]
                }
              },
              in: '$$tituloObj.titulo'
            }
          },
          // OTROS TITULOS (sin el original)
          otros_titulos: {
            $map: {
              input: {
                $filter: {
                  input: '$nombres_data',
                  as: 'nom',
                  cond: { $eq: ['$$nom.es_original', false] }
                }
              },
              as: 'alt',
              in: {
                titulo: '$$alt.titulo',
                region: '$$alt.region',
                lenguaje: '$$alt.lenguaje'
              }
            }
          },
          rating: {
            promedio: '$promedio_rating',
            votos: '$votos'
          },
          generos: '$generos_data.genero',
          actores: {
            $map: {
              input: '$actores_data',
              as: 'actor',
              in: {
                id_persona: '$$actor.id_persona',
                nombre: '$$actor.nombre',
                orden: '$$actor.orden',
                personajes: [] // Se llenará en el siguiente paso
              }
            }
          },
          directores: {
            $map: {
              input: '$directores_data',
              as: 'dir',
              in: {
                id_persona: '$$dir.id_persona',
                nombre: '$$dir.nombre',
                orden: '$$dir.orden'
              }
            }
          },
          escritores: {
            $map: {
              input: '$escritores_data',
              as: 'esc',
              in: {
                id_persona: '$$esc.id_persona',
                nombre: '$$esc.nombre',
                orden: '$$esc.orden'
              }
            }
          }
        }
      },
      { $out: 'producciones_temp1' }
    ], { allowDiskUse: true, maxTimeMS: 3600000 }).toArray();

    console.log('Estructura base creada\n');

    // ========================================
    // PASO 2: Agregar personajes a los actores
    // ========================================
    console.log('Paso 2: Agregando personajes a actores...');
    
    await this.db.collection('producciones_temp1').aggregate([
      { $unwind: { path: '$actores', preserveNullAndEmptyArrays: true } },
      {
        $lookup: {
          from: 'personajes',
          let: { 
            prod_id: '$_id', 
            pers_id: '$actores.id_persona' 
          },
          pipeline: [
            {
              $match: {
                $expr: {
                  $and: [
                    { $eq: ['$id_produccion', '$$prod_id'] },
                    { $eq: ['$persona_id', '$$pers_id'] }
                  ]
                }
              }
            },
            {
              $project: {
                personaje: 1,
                _id: 0
              }
            }
          ],
          as: 'personajes_match'
        }
      },
      {
        $addFields: {
          'actores.personajes': '$personajes_match.personaje'
        }
      },
      {
        $group: {
          _id: '$_id',
          documento: { $first: '$$ROOT' },
          actores_completos: { $push: '$actores' }
        }
      },
      {
        $replaceRoot: {
          newRoot: {
            $mergeObjects: [
              '$documento',
              { actores: '$actores_completos' }
            ]
          }
        }
      },
      {
        $project: {
          personajes_match: 0,
          documento: 0
        }
      },
      { $out: 'producciones' }
    ], { allowDiskUse: true, maxTimeMS: 3600000 }).toArray();

    // Limpieza
    await this.db.collection('producciones_temp1').drop().catch(() => {});
    
    console.log('Producciones completas\n');

    // ========================================
    // 2. SERIES
    // ========================================
    console.log('Agregando series...');
    await this.db.collection('series').drop().catch(() => {});

    await this.db.collection('producciones_base').aggregate([
      { 
        $match: { 
          tipo: { $in: ['tvSeries', 'tvMiniSeries', 'tvShort'] } 
        } 
      },
      {
        $lookup: {
          from: 'nombres',
          localField: '_id',
          foreignField: 'id_produccion',
          as: 'nombres_data'
        }
      },
      {
        $lookup: {
          from: 'generos',
          localField: '_id',
          foreignField: 'id_produccion',
          as: 'generos_data'
        }
      },
      {
        $lookup: {
          from: 'episodios',
          localField: '_id',
          foreignField: 'id_serie',
          as: 'episodios_data'
        }
      },
      {
        $lookup: {
          from: 'actores',
          localField: '_id',
          foreignField: 'id_produccion',
          as: 'actores_data'
        }
      },
      {
        $lookup: {
          from: 'directores',
          localField: '_id',
          foreignField: 'id_produccion',
          as: 'directores_data'
        }
      },
      {
        $project: {
          _id: 1,
          tipo: 1,
          adultos: 1,
          año_inicio: 1,
          año_fin: 1,
          titulo_original: {
            $let: {
              vars: {
                tituloObj: {
                  $arrayElemAt: [
                    {
                      $filter: {
                        input: '$nombres_data',
                        as: 'nom',
                        cond: { $eq: ['$$nom.es_original', true] }
                      }
                    },
                    0
                  ]
                }
              },
              in: '$$tituloObj.titulo'
            }
          },
          rating: {
            promedio: '$promedio_rating',
            votos: '$votos'
          },
          generos: '$generos_data.genero',
          actores: {
            $map: {
              input: '$actores_data',
              as: 'actor',
              in: {
                id_persona: '$$actor.id_persona',
                nombre: '$$actor.nombre',
                orden: '$$actor.orden'
              }
            }
          },
          directores: {
            $map: {
              input: '$directores_data',
              as: 'dir',
              in: {
                id_persona: '$$dir.id_persona',
                nombre: '$$dir.nombre',
                orden: '$$dir.orden'
              }
            }
          },
          total_episodios: { $size: '$episodios_data' },
          total_temporadas: {
            $size: {
              $setUnion: {
                $map: {
                  input: '$episodios_data',
                  as: 'ep',
                  in: '$$ep.temporada'
                }
              }
            }
          },
          episodios: {
            $map: {
              input: '$episodios_data',
              as: 'ep',
              in: {
                id_episodio: '$$ep.id_episodio',
                temporada: '$$ep.temporada',
                episodio: '$$ep.episodio',
                titulo: '$$ep.titulo_episodio'
              }
            }
          }
        }
      },
      { $out: 'series' }
    ], { allowDiskUse: true, maxTimeMS: 3600000 }).toArray();

    console.log('Series agregadas\n');

    // ========================================
    // 3. PELÍCULAS POR DIRECTOR
    // ========================================
    console.log('Agregando peliculas_por_director...');
    await this.db.collection('peliculas_por_director').drop().catch(() => {});

    await this.db.collection('directores').aggregate([
      {
        $lookup: {
          from: 'producciones',
          let: { prod_id: '$id_produccion' },
          pipeline: [
            {
              $match: {
                $expr: {
                  $and: [
                    { $eq: ['$_id', '$$prod_id'] },
                    { $in: ['$tipo', ['movie', 'tvMovie']] }
                  ]
                }
              }
            }
          ],
          as: 'pelicula'
        }
      },
      { $unwind: '$pelicula' },
      {
        $group: {
          _id: '$id_persona',
          nombre: { $first: '$nombre' },
          total_peliculas: { $sum: 1 },
          rating_promedio: { $avg: '$pelicula.rating.promedio' },
          peliculas: {
            $push: {
              id_titulo: '$pelicula._id',
              titulo: '$pelicula.titulo_original',
              año: '$pelicula.año_inicio',
              tipo: '$pelicula.tipo',
              duracion_minutos: '$pelicula.duracion_minutos',
              rating: '$pelicula.rating',
              generos: '$pelicula.generos',
              actores_principales: {
                $slice: ['$pelicula.actores', 5]
              }
            }
          }
        }
      },
      {
        $project: {
          _id: 1,
          nombre: 1,
          estadisticas: {
            total_peliculas: '$total_peliculas',
            rating_promedio: { $round: ['$rating_promedio', 2] }
          },
          peliculas: {
            $sortArray: {
              input: '$peliculas',
              sortBy: { año: -1 }
            }
          }
        }
      },
      { $out: 'peliculas_por_director' }
    ], { allowDiskUse: true, maxTimeMS: 3600000 }).toArray();

    console.log('Películas por director agregadas\n');
  }

  async createTopCollections() {
    console.log('CREANDO COLECCIÓN TOPS...\n');

    // ========================================
    // TOP 10 PELÍCULAS
    // ========================================
    console.log('Creando top 10 películas...');
    
    const topPeliculas = await this.db.collection('producciones').aggregate([
      {
        $match: {
          tipo: { $in: ['movie', 'tvMovie'] },
          'rating.promedio': { $ne: null },
          'rating.votos': { $gte: 1000 }
        }
      },
      { $sort: { 'rating.promedio': -1, 'rating.votos': -1 } },
      { $limit: 10 },
      {
        $project: {
          id_titulo: '$_id',
          titulo: '$titulo_original',
          rating: '$rating.promedio',
          votos: '$rating.votos',
          año: '$año_inicio',
          duracion_minutos: 1,
          tipo: 1,
          generos: 1,
          directores: '$directores.nombre'
        }
      }
    ]).toArray();

    await this.db.collection('tops').updateOne(
      { _id: 'top_10_peliculas' },
      {
        $set: {
          actualizado: new Date(),
          peliculas: topPeliculas.map((p, idx) => ({ posicion: idx + 1, ...p }))
        }
      },
      { upsert: true }
    );

    console.log('Top películas creado');

    // ========================================
    // DIRECTOR CON MÁS PELÍCULAS
    // ========================================
    console.log('Creando top director...');
    
    const topDirector = await this.db.collection('directores').aggregate([
      {
        $lookup: {
          from: 'producciones_base',
          let: { prod_id: '$id_produccion' },
          pipeline: [
            {
              $match: {
                $expr: {
                  $and: [
                    { $eq: ['$_id', '$$prod_id'] },
                    { $eq: ['$tipo', 'movie'] }
                  ]
                }
              }
            }
          ],
          as: 'pelicula'
        }
      },
      { $unwind: '$pelicula' },
      {
        $group: {
          _id: '$id_persona',
          nombre: { $first: '$nombre' },
          total_peliculas: { $sum: 1 },
          rating_promedio: { $avg: '$pelicula.promedio_rating' }
        }
      },
      { $sort: { total_peliculas: -1 } },
      { $limit: 1 }
    ]).toArray();

    if (topDirector.length > 0) {
      await this.db.collection('tops').updateOne(
        { _id: 'director_mas_peliculas' },
        {
          $set: {
            actualizado: new Date(),
            director: {
              id_persona: topDirector[0]._id,
              nombre: topDirector[0].nombre,
              total_peliculas: topDirector[0].total_peliculas,
              rating_promedio: Math.round(topDirector[0].rating_promedio * 100) / 100
            }
          }
        },
        { upsert: true }
      );
      console.log('Top director creado');
    }

    // ========================================
    // TOP 10 ACTORES
    // ========================================
    console.log('Creando top 10 actores...');
    
    const topActores = await this.db.collection('actores').aggregate([
      {
        $lookup: {
          from: 'producciones_base',
          let: { prod_id: '$id_produccion' },
          pipeline: [
            {
              $match: {
                $expr: {
                  $and: [
                    { $eq: ['$_id', '$$prod_id'] },
                    { $in: ['$tipo', ['movie', 'tvMovie']] }
                  ]
                }
              }
            }
          ],
          as: 'pelicula'
        }
      },
      { $unwind: '$pelicula' },
      {
        $group: {
          _id: '$id_persona',
          nombre: { $first: '$nombre' },
          total_peliculas: { $sum: 1 },
          rating_promedio: { $avg: '$pelicula.promedio_rating' },
          primera_pelicula: { $min: '$pelicula.año_inicio' },
          ultima_pelicula: { $max: '$pelicula.año_inicio' }
        }
      },
      { $match: { total_peliculas: { $gte: 5 } } },
      { $sort: { total_peliculas: -1 } },
      { $limit: 10 }
    ]).toArray();

    await this.db.collection('tops').updateOne(
      { _id: 'top_10_actores' },
      {
        $set: {
          actualizado: new Date(),
          actores: topActores.map((a, idx) => ({
            posicion: idx + 1,
            id_persona: a._id,
            nombre: a.nombre,
            total_peliculas: a.total_peliculas,
            rating_promedio: Math.round(a.rating_promedio * 100) / 100,
            primera_pelicula: a.primera_pelicula,
            ultima_pelicula: a.ultima_pelicula
          }))
        }
      },
      { upsert: true }
    );

    console.log('Top actores creado\n');
  }

  async createIndexes() {
    console.log('CREANDO ÍNDICES FINALES...\n');

    await this.db.collection('producciones').createIndex({ titulo_original: 'text' });
    await this.db.collection('producciones').createIndex({ tipo: 1 });
    await this.db.collection('producciones').createIndex({ 'rating.promedio': -1 });
    await this.db.collection('series').createIndex({ titulo_original: 'text' });
    await this.db.collection('series').createIndex({ tipo: 1 });
    await this.db.collection('peliculas_por_director').createIndex({ '_id': 1 });
    await this.db.collection('peliculas_por_director').createIndex({ 'nombre': 'text' });

    console.log('Índices finales creados\n');
  }

  async run() {
    try {
      await this.connect();
      
      console.log('='.repeat(60));
      console.log('FASE 1: CARGANDO DATOS DESDE CSV');
      console.log('='.repeat(60) + '\n');
      
      await this.buildProducciones();
      await this.buildNombres();
      await this.buildGeneros();
      await this.buildActores();
      await this.buildDirectores();
      await this.buildEscritores();
      await this.buildPersonajes();
      await this.buildEpisodios();
      
      console.log('='.repeat(60));
      console.log('FASE 2: CREANDO ÍNDICES BASE');
      console.log('='.repeat(60) + '\n');
      
      await this.createBaseIndexes();
      
      console.log('='.repeat(60));
      console.log('FASE 3: CREANDO COLECCIONES FINALES');
      console.log('='.repeat(60) + '\n');
      
      await this.createAggregatedCollections();
      await this.createTopCollections();
      await this.createIndexes();

      console.log('\n' + '='.repeat(60));
      console.log('PROCESO COMPLETADO EXITOSAMENTE');
      console.log('='.repeat(60));
      console.log('\nCOLECCIONES CREADAS:');
      console.log('  ✓ producciones');
      console.log('  ✓ series');
      console.log('  ✓ peliculas_por_director');
      console.log('  ✓ tops (top_10_peliculas, director_mas_peliculas, top_10_actores)');
      console.log('='.repeat(60) + '\n');
      
    } catch (error) {
      console.error('\nERROR:', error);
      console.error('Stack:', error.stack);
    } finally {
      await this.disconnect();
    }
  }
}

const loader = new IMDBToMongo();
loader.run();