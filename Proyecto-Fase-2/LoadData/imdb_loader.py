import pandas as pd
import psycopg2
from psycopg2.extras import execute_values
import os
import traceback
from datetime import datetime

class IMDBDataLoader:
    def __init__(self, db_config, tsv_path):
        self.db_config = db_config
        self.tsv_path = tsv_path
        self.connection = None
        
        # Diccionarios para mapear IDs
        self.profession_ids = {}
        self.genre_ids = {}
        self.titletype_ids = {}
        self.attribute_ids = {}

    def connect_db(self):
        """Conexión optimizada para PostgreSQL"""
        try:
            self.connection = psycopg2.connect(
                **self.db_config,
                keepalives=1,
                keepalives_idle=30,
                keepalives_interval=10,
                keepalives_count=5
            )
            self.connection.autocommit = False
            
            cursor = self.connection.cursor()
            # 🔧 DESACTIVAR CONSTRAINTS Y TRIGGERS PARA CARGA MASIVA
            cursor.execute("SET session_replication_role = 'replica';")
            cursor.execute("SET maintenance_work_mem = '1GB';")
            cursor.execute("SET work_mem = '256MB';")
            cursor.execute("SET synchronous_commit = OFF;")
            cursor.close()
            
            print("✅ Conectado a PostgreSQL")
            
        except Exception as e:
            print(f"❌ Error conectando: {e}")
            raise

    def keep_alive(self):
        """Mantiene la conexión activa"""
        try:
            if self.connection and not self.connection.closed:
                cursor = self.connection.cursor()
                cursor.execute("SELECT 1")
                cursor.fetchone()
                cursor.close()
            else:
                self.connect_db()
        except:
            self.connect_db()

    def disconnect_db(self):
        """Cierra la conexión y reactiva constraints"""
        if self.connection and not self.connection.closed:
            try:
                cursor = self.connection.cursor()
                print("\n🔄 Reactivando constraints...")
                cursor.execute("SET session_replication_role = 'origin';")
                cursor.execute("SET synchronous_commit = ON;")
                self.connection.commit()
                cursor.close()
                self.connection.close()
                print("✅ Desconectado de PostgreSQL")
            except Exception as e:
                print(f"⚠️  Error al cerrar: {e}")

    def insert_fast(self, query, data, batch_size=10000):
        """Inserción masiva optimizada con execute_values"""
        if not data:
            return
            
        total_inserted = 0
        
        for i in range(0, len(data), batch_size):
            batch = data[i:i + batch_size]
            
            try:
                self.keep_alive()
                cursor = self.connection.cursor()
                
                execute_values(cursor, query, batch, page_size=batch_size)
                
                self.connection.commit()
                cursor.close()
                
                total_inserted += len(batch)
                
                if total_inserted % 100000 == 0:
                    print(f"  → {total_inserted:,} registros insertados...")
                    
            except Exception as e:
                print(f"⚠️  Error en batch {i}: {e}")
                self.connection.rollback()
                try:
                    self.connect_db()
                except:
                    continue
        
        print(f"✅ Total insertado: {total_inserted:,} registros")

    def read_tsv_safely(self, file_path, usecols=None, chunksize=None):
        """Lectura segura de archivos TSV"""
        try:
            if not os.path.exists(file_path):
                print(f"⚠️  Archivo no encontrado: {file_path}")
                return None
                
            print(f"📖 Leyendo: {os.path.basename(file_path)}")

            read_params = {
                'delimiter': '\t',
                'dtype': str,
                'na_values': ['\\N'],
                'keep_default_na': False,
                'encoding': 'utf-8',
                'quoting': 3,
                'low_memory': False,
            }
            
            if usecols:
                read_params['usecols'] = usecols
                
            if chunksize:
                read_params['chunksize'] = chunksize
                
            df = pd.read_csv(file_path, **read_params)
            
            if isinstance(df, pd.DataFrame):
                print(f"  → {len(df):,} filas leídas")
                
            return df
            
        except Exception as e:
            print(f"❌ Error leyendo {file_path}: {e}")
            return None

    def extract_id(self, imdb_id):
        """Extrae ID numérico de formato IMDB (nm0000001 → 1)"""
        if not imdb_id or imdb_id == '\\N':
            return None
        try:
            return int(imdb_id[2:])
        except:
            return None

    def format_text(self, text):
        """Normaliza texto"""
        if not text or text == '\\N':
            return None
        return text.replace('_', ' ').capitalize()

    def year_to_date(self, year, is_end=False):
        """Convierte año a fecha PostgreSQL"""
        if not year or year == '\\N':
            return None
        try:
            y = int(year)
            y_str = f"{y:04d}"
            return f"{y_str}-12-31" if is_end else f"{y_str}-01-01"
        except:
            return None

    def minutes_to_int(self, minutes):
        """Convierte minutos a INT (🔧 CAMBIADO de INTERVAL a INT)"""
        if not minutes or minutes == '\\N':
            return None
        try:
            return int(minutes)
        except:
            return None

    # ==========================================
    # CARGA DE CATÁLOGOS
    # ==========================================

    def load_professions(self):
        """Carga profesiones con IDs secuenciales"""
        print("\n📋 Cargando PROFESIONES...")
        professions = set()
        
        try:
            df = self.read_tsv_safely(f"{self.tsv_path}/name.basics.tsv", usecols=['primaryProfession'])
            if df is not None:
                for profs in df['primaryProfession'].dropna():
                    if profs != '\\N':
                        for p in profs.split(','):
                            if p.strip():
                                professions.add(self.format_text(p.strip()))
        except:
            pass
        
        try:
            chunk_iterator = self.read_tsv_safely(
                f"{self.tsv_path}/title.principals.tsv", 
                usecols=['category'], 
                chunksize=1000000
            )
            if chunk_iterator is not None:
                for df_chunk in chunk_iterator:
                    for cat in df_chunk['category'].dropna().unique():
                        if cat != '\\N':
                            professions.add(self.format_text(cat))
        except:
            pass
        
        data = []
        prof_id = 1
        
        for prof in sorted(professions):
            if prof:
                self.profession_ids[prof] = prof_id
                data.append((prof_id, prof))
                prof_id += 1
        
        query = """
            INSERT INTO profesiones (id_profesion, profesion) 
            VALUES %s 
            ON CONFLICT (id_profesion) DO NOTHING
        """
        self.insert_fast(query, data)

    def load_genres(self):
        """Carga géneros"""
        print("\n🎭 Cargando GÉNEROS...")
        try:
            df = self.read_tsv_safely(f"{self.tsv_path}/title.basics.tsv", usecols=['genres'])
            if df is None:
                return
            
            genres = set()
            for genre_list in df['genres'].dropna():
                if genre_list != '\\N':
                    for g in genre_list.split(','):
                        if g.strip():
                            genres.add(self.format_text(g.strip()))
            
            data = []
            genre_id = 1
            
            for genre in sorted(genres):
                if genre:
                    self.genre_ids[genre] = genre_id
                    data.append((genre_id, genre))
                    genre_id += 1
            
            query = """
                INSERT INTO generos (id_genero, genero) 
                VALUES %s 
                ON CONFLICT (id_genero) DO NOTHING
            """
            self.insert_fast(query, data)
        except Exception as e:
            print(f"⚠️  Error en géneros: {e}")

    def load_title_types(self):
        """Carga tipos de producción"""
        print("\n🎬 Cargando TIPOS DE PRODUCCIÓN...")
        try:
            df = self.read_tsv_safely(f"{self.tsv_path}/title.basics.tsv", usecols=['titleType'])
            if df is None:
                return
            
            types = set(df['titleType'].dropna().unique())
            types.discard('\\N')
            types.add('Unknown')
            
            data = []
            type_id = 0
            
            self.titletype_ids['Unknown'] = 0
            data.append((0, 'Unknown'))
            type_id = 1
            
            for t_type in sorted(types):
                if t_type != 'Unknown':
                    self.titletype_ids[t_type] = type_id
                    data.append((type_id, t_type))
                    type_id += 1
            
            query = """
                INSERT INTO tipo_produccion (id_tipo_produccion, tipo_produccion) 
                VALUES %s 
                ON CONFLICT (id_tipo_produccion) DO NOTHING
            """
            self.insert_fast(query, data)
        except Exception as e:
            print(f"⚠️  Error en tipos: {e}")

    def load_attributes(self):
        """Carga atributos (🔧 LIMITADO A 200 caracteres)"""
        print("\n🏷️  Cargando ATRIBUTOS...")
        attributes = set()
        
        try:
            chunk_iterator = self.read_tsv_safely(
                f"{self.tsv_path}/title.akas.tsv", 
                usecols=['attributes', 'types'], 
                chunksize=1000000
            )
            if chunk_iterator is not None:
                for df_chunk in chunk_iterator:
                    for attr_str in df_chunk['attributes'].dropna():
                        if attr_str != '\\N':
                            try:
                                for attr in str(attr_str).replace('\x02', '|').split('|'):
                                    if attr.strip():
                                        attributes.add(('Title attribute', attr.strip()[:200]))
                            except:
                                continue
                    
                    for type_str in df_chunk['types'].dropna():
                        if type_str != '\\N':
                            try:
                                for t in str(type_str).replace('\x02', '|').split('|'):
                                    if t.strip() and t.strip() not in ['imdbDisplay', 'original']:
                                        attributes.add(('Title types', t.strip()[:200]))
                            except:
                                continue
        except Exception as e:
            print(f"⚠️  Error en atributos: {e}")
        
        data = []
        attr_id = 1
        
        for class_name, attribute in sorted(attributes):
            self.attribute_ids[(class_name, attribute)] = attr_id
            data.append((attr_id, class_name, attribute))
            attr_id += 1
        
        query = """
            INSERT INTO atributos (id_atributo, class, atributo) 
            VALUES %s 
            ON CONFLICT (id_atributo) DO NOTHING
        """
        self.insert_fast(query, data)

    # ==========================================
    # CARGA DE ENTIDADES PRINCIPALES
    # ==========================================

    def load_personas(self):
        """Carga personas (🔧 VARCHAR(200))"""
        print("\n👥 Cargando PERSONAS...")
        personas_data = []
        existing_ids = set()
        
        try:
            df = self.read_tsv_safely(f"{self.tsv_path}/name.basics.tsv")
            if df is not None:
                for _, row in df.iterrows():
                    person_id = self.extract_id(row.get('nconst'))
                    if person_id:
                        birth = self.year_to_date(row.get('birthYear'))
                        death = self.year_to_date(row.get('deathYear'), True)
                        name = str(row.get('primaryName', 'Unknown'))[:200] if pd.notna(row.get('primaryName')) else 'Unknown'
                        
                        personas_data.append((person_id, name, birth, death))
                        existing_ids.add(person_id)
        except Exception as e:
            print(f"⚠️  Error en name.basics: {e}")
        
        try:
            chunk_iterator = self.read_tsv_safely(
                f"{self.tsv_path}/title.principals.tsv", 
                usecols=['nconst'], 
                chunksize=1000000
            )
            if chunk_iterator is not None:
                for df_chunk in chunk_iterator:
                    for _, row in df_chunk.iterrows():
                        person_id = self.extract_id(row.get('nconst'))
                        if person_id and person_id not in existing_ids:
                            personas_data.append((person_id, 'Unknown', None, None))
                            existing_ids.add(person_id)
        except Exception as e:
            print(f"⚠️  Error en principals: {e}")
        
        query = """
            INSERT INTO personas (id_persona, nombre, ahno_nacimiento, ahno_muerte) 
            VALUES %s 
            ON CONFLICT (id_persona) DO NOTHING
        """
        self.insert_fast(query, personas_data, batch_size=50000)

    def load_produccion(self):
        """Carga producciones (🔧 minutos_duracion como INT)"""
        print("\n🎥 Cargando PRODUCCIÓN...")
        produccion_data = []
        existing_ids = set()
        
        try:
            df = self.read_tsv_safely(f"{self.tsv_path}/title.basics.tsv")
            if df is not None:
                for _, row in df.iterrows():
                    title_id = self.extract_id(row.get('tconst'))
                    if title_id:
                        type_id = self.titletype_ids.get(row.get('titleType'), 0)
                        start_date = self.year_to_date(row.get('startYear'))
                        end_date = self.year_to_date(row.get('endYear'), True)
                        runtime = self.minutes_to_int(row.get('runtimeMinutes'))  # 🔧 INT
                        is_adult = True if row.get('isAdult') == '1' else False
                        
                        produccion_data.append((
                            title_id, type_id, is_adult, start_date, 
                            end_date, runtime, None, None
                        ))
                        existing_ids.add(title_id)
        except Exception as e:
            print(f"⚠️  Error en title.basics: {e}")
        
        try:
            chunk_iterator = self.read_tsv_safely(
                f"{self.tsv_path}/title.akas.tsv", 
                usecols=['titleId'], 
                chunksize=1000000
            )
            if chunk_iterator is not None:
                for df_chunk in chunk_iterator:
                    for _, row in df_chunk.iterrows():
                        title_id = self.extract_id(row.get('titleId'))
                        if title_id and title_id not in existing_ids:
                            produccion_data.append((title_id, 0, False, None, None, None, None, None))
                            existing_ids.add(title_id)
        except Exception as e:
            print(f"⚠️  Error en title.akas: {e}")
        
        try:
            chunk_iterator = self.read_tsv_safely(
                f"{self.tsv_path}/title.principals.tsv", 
                usecols=['tconst'], 
                chunksize=1000000
            )
            if chunk_iterator is not None:
                for df_chunk in chunk_iterator:
                    for _, row in df_chunk.iterrows():
                        title_id = self.extract_id(row.get('tconst'))
                        if title_id and title_id not in existing_ids:
                            produccion_data.append((title_id, 0, False, None, None, None, None, None))
                            existing_ids.add(title_id)
        except Exception as e:
            print(f"⚠️  Error en title.principals: {e}")
        
        query = """
            INSERT INTO produccion 
            (id_titulo, id_tipo_titulo, adultos, ahno_inicio, ahno_finalizacion, 
             minutos_duracion, votos, promedio_rating) 
            VALUES %s
            ON CONFLICT (id_titulo) DO NOTHING
        """
        self.insert_fast(query, produccion_data, batch_size=50000)

    # ==========================================
    # CARGA DE RELACIONES
    # ==========================================

    def load_top_profesiones(self):
        """Carga top profesiones de cada persona"""
        print("\n🏆 Cargando TOP PROFESIONES...")
        try:
            df = self.read_tsv_safely(
                f"{self.tsv_path}/name.basics.tsv", 
                usecols=['nconst', 'primaryProfession']
            )
            if df is None:
                return
            
            data = []
            for _, row in df.iterrows():
                person_id = self.extract_id(row.get('nconst'))
                if person_id and pd.notna(row.get('primaryProfession')) and row.get('primaryProfession') != '\\N':
                    for ordinal, prof in enumerate(row.get('primaryProfession').split(','), 1):
                        if prof.strip():
                            formatted_prof = self.format_text(prof.strip())
                            prof_id = self.profession_ids.get(formatted_prof)
                            if prof_id:
                                data.append((person_id, prof_id, ordinal))
            
            query = """
                INSERT INTO top_profesiones (id_persona, id_profesion, ordinal) 
                VALUES %s 
                ON CONFLICT (id_persona, id_profesion) DO NOTHING
            """
            self.insert_fast(query, data)
        except Exception as e:
            print(f"⚠️  Error: {e}")

    def load_genero_produccion(self):
        """Carga géneros de cada producción"""
        print("\n🎭 Cargando GÉNEROS POR PRODUCCIÓN...")
        try:
            df = self.read_tsv_safely(
                f"{self.tsv_path}/title.basics.tsv", 
                usecols=['tconst', 'genres']
            )
            if df is None:
                return
            
            data = []
            for _, row in df.iterrows():
                title_id = self.extract_id(row.get('tconst'))
                if title_id and pd.notna(row.get('genres')) and row.get('genres') != '\\N':
                    for genre in row.get('genres').split(','):
                        if genre.strip():
                            formatted_genre = self.format_text(genre.strip())
                            genre_id = self.genre_ids.get(formatted_genre)
                            if genre_id:
                                data.append((title_id, genre_id))
            
            query = """
                INSERT INTO genero_produccion (id_produccion, id_genero) 
                VALUES %s 
                ON CONFLICT (id_produccion, id_genero) DO NOTHING
            """
            self.insert_fast(query, data)
        except Exception as e:
            print(f"⚠️  Error: {e}")

    def load_nombres_produccion(self):
        """Carga nombres alternativos (🔧 VARCHAR(500))"""
        print("\n📝 Cargando NOMBRES DE PRODUCCIÓN...")
        try:
            chunk_iterator = self.read_tsv_safely(
                f"{self.tsv_path}/title.akas.tsv", 
                chunksize=500000
            )
            if chunk_iterator is None:
                return
                
            for df_chunk in chunk_iterator:
                data = []
                for _, row in df_chunk.iterrows():
                    title_id = self.extract_id(row.get('titleId'))
                    if title_id:
                        is_original = True if pd.notna(row.get('isOriginalTitle')) and str(row.get('isOriginalTitle')) == '1' else False
                        
                        title = str(row.get('title', 'Unknown'))[:500] if pd.notna(row.get('title')) else 'Unknown'
                        region = str(row.get('region', ''))[:100] if pd.notna(row.get('region')) else ''
                        language = str(row.get('language', ''))[:100] if pd.notna(row.get('language')) else ''
                        ordering = int(row.get('ordering', 1)) if pd.notna(row.get('ordering')) else 1
                        
                        data.append((title_id, ordering, title, region, language, is_original))

                query = """
                    INSERT INTO nombres_produccion 
                    (id_produccion, orden, nombres_produccion, region, lenguaje, esOriginal) 
                    VALUES %s
                    ON CONFLICT (id_produccion, orden) DO NOTHING
                """
                self.insert_fast(query, data, batch_size=10000)
        except Exception as e:
            print(f"⚠️  Error: {e}")

    def load_nombres_titulos_atributos(self):
        """Carga atributos de nombres (🔧 limitado a 200 chars)"""
        print("\n🏷️  Cargando ATRIBUTOS DE NOMBRES...")
        try:
            chunk_iterator = self.read_tsv_safely(
                f"{self.tsv_path}/title.akas.tsv", 
                chunksize=500000
            )
            if chunk_iterator is None:
                return
                
            for df_chunk in chunk_iterator:
                data = []
                for _, row in df_chunk.iterrows():
                    title_id = self.extract_id(row.get('titleId'))
                    if title_id:
                        ordering = int(row.get('ordering', 1)) if pd.notna(row.get('ordering')) else 1
                        
                        if pd.notna(row.get('attributes')) and row.get('attributes') != '\\N':
                            try:
                                for attr in str(row.get('attributes')).replace('\x02', '|').split('|'):
                                    if attr.strip():
                                        attr_id = self.attribute_ids.get(('Title attribute', attr.strip()[:200]))
                                        if attr_id:
                                            data.append((title_id, ordering, attr_id))
                            except:
                                continue
                        
                        if pd.notna(row.get('types')) and row.get('types') != '\\N':
                            try:
                                for attr_type in str(row.get('types')).replace('\x02', '|').split('|'):
                                    if attr_type.strip() and attr_type.strip() not in ['imdbDisplay', 'original']:
                                        attr_id = self.attribute_ids.get(('Title types', attr_type.strip()[:200]))
                                        if attr_id:
                                            data.append((title_id, ordering, attr_id))
                            except:
                                continue

                query = """
                    INSERT INTO nombres_titulos_atributos (id_titulo, orden, id_atributo) 
                    VALUES %s 
                    ON CONFLICT (id_titulo, orden, id_atributo) DO NOTHING
                """
                self.insert_fast(query, data, batch_size=10000)
        except Exception as e:
            print(f"⚠️  Error: {e}")

    def load_personas_produccion(self):
        """Carga relación personas-producción"""
        print("\n🎬 Cargando PERSONAS-PRODUCCIÓN...")
        principals_data = []
        
        try:
            chunk_iterator = self.read_tsv_safely(
                f"{self.tsv_path}/title.principals.tsv", 
                chunksize=1000000
            )
            if chunk_iterator is not None:
                for df_chunk in chunk_iterator:
                    for _, row in df_chunk.iterrows():
                        title_id = self.extract_id(row.get('tconst'))
                        person_id = self.extract_id(row.get('nconst'))
                        
                        if title_id and person_id:
                            ordering = int(row.get('ordering')) if pd.notna(row.get('ordering')) else 1
                            formatted_cat = self.format_text(row.get('category'))
                            prof_id = self.profession_ids.get(formatted_cat)
                            
                            if prof_id:
                                principals_data.append((title_id, ordering, person_id, prof_id, None))
            
            query = """
                INSERT INTO personas_produccion 
                (id_produccion, orden, id_persona, id_profesion, conocido_por) 
                VALUES %s
                ON CONFLICT (id_produccion, orden) DO NOTHING
            """
            self.insert_fast(query, principals_data, batch_size=50000)
            
        except Exception as e:
            print(f"⚠️  Error en principals: {e}")
            return
        
        print("  → Procesando directores y escritores...")
        try:
            df_crew = self.read_tsv_safely(f"{self.tsv_path}/title.crew.tsv")
            if df_crew is None:
                return
            
            self.keep_alive()
            cursor = self.connection.cursor()
            
            cursor.execute("""
                CREATE TEMP TABLE writers_directors (
                    titleId INT,
                    principalId INT,
                    professionId INT
                )
            """)
            cursor.execute("CREATE INDEX idx_wd ON writers_directors (titleId, principalId)")
            
            director_prof_id = self.profession_ids.get('Director')
            writer_prof_id = self.profession_ids.get('Writer')
            
            for _, row in df_crew.iterrows():
                title_id = self.extract_id(row.get('tconst'))
                if title_id:
                    if pd.notna(row.get('directors')) and row.get('directors') != '\\N':
                        for director in row.get('directors').split(','):
                            if director.strip():
                                person_id = self.extract_id(director.strip())
                                if person_id and director_prof_id:
                                    cursor.execute("""
                                        INSERT INTO writers_directors (titleId, principalId, professionId)
                                        SELECT %s, %s, %s
                                        WHERE NOT EXISTS (
                                            SELECT 1 FROM personas_produccion pp 
                                            WHERE pp.id_produccion = %s AND pp.id_persona = %s
                                        )
                                    """, (title_id, person_id, director_prof_id, title_id, person_id))
                    
                    if pd.notna(row.get('writers')) and row.get('writers') != '\\N':
                        for writer in row.get('writers').split(','):
                            if writer.strip():
                                person_id = self.extract_id(writer.strip())
                                if person_id and writer_prof_id:
                                    cursor.execute("""
                                        INSERT INTO writers_directors (titleId, principalId, professionId)
                                        SELECT %s, %s, %s
                                        WHERE NOT EXISTS (
                                            SELECT 1 FROM personas_produccion pp 
                                            WHERE pp.id_produccion = %s AND pp.id_persona = %s
                                        )
                                    """, (title_id, person_id, writer_prof_id, title_id, person_id))
            
            self.connection.commit()
            
            cursor.execute("SELECT titleId, principalId, professionId FROM writers_directors")
            missing_crew = cursor.fetchall()
            
            if missing_crew:
                cursor.execute("""
                    SELECT id_produccion, MAX(orden) as max_ordinal
                    FROM personas_produccion
                    GROUP BY id_produccion
                """)
                max_ordinals = dict(cursor.fetchall())
                
                final_crew_data = []
                current_title = None
                current_ordinal = 0
                
                missing_crew.sort(key=lambda x: (x[0], x[2], x[1]))
                
                for title_id, person_id, prof_id in missing_crew:
                    if title_id != current_title:
                        current_title = title_id
                        current_ordinal = max_ordinals.get(title_id, 0)
                    
                    current_ordinal += 1
                    final_crew_data.append((title_id, current_ordinal, person_id, prof_id, None))
                
                query = """
                    INSERT INTO personas_produccion 
                    (id_produccion, orden, id_persona, id_profesion, conocido_por) 
                    VALUES %s
                    ON CONFLICT (id_produccion, orden) DO NOTHING
                """
                self.insert_fast(query, final_crew_data, batch_size=50000)
            
            cursor.execute("DROP TABLE writers_directors")
            cursor.close()
            
        except Exception as e:
            print(f"⚠️  Error en crew: {e}")
            try:
                cursor.execute("DROP TABLE IF EXISTS writers_directors")
                cursor.close()
            except:
                pass

    def parse_characters(self, chars_str):
        """Parsea string de personajes"""
        if not chars_str or chars_str == '\\N':
            return []
        try:
            if chars_str.startswith('[') and chars_str.endswith(']'):
                content = chars_str[1:-1].replace('","', '\t').replace('"', '')
                return [c.strip() for c in content.split('\t') if c.strip()]
            return [chars_str]
        except:
            return [chars_str] if chars_str else []

    def load_personajes(self):
        """Carga personajes (🔧 VARCHAR(200))"""
        print("\n🎭 Cargando PERSONAJES...")
        try:
            chunk_iterator = self.read_tsv_safely(
                f"{self.tsv_path}/title.principals.tsv", 
                usecols=['tconst', 'nconst', 'characters'], 
                chunksize=1000000
            )
            if chunk_iterator is None:
                return
            
            for df_chunk in chunk_iterator:
                data = []
                for _, row in df_chunk.iterrows():
                    title_id = self.extract_id(row.get('tconst'))
                    person_id = self.extract_id(row.get('nconst'))
                    
                    if title_id and person_id and pd.notna(row.get('characters')):
                        characters = self.parse_characters(row.get('characters'))
                        for char in characters:
                            if char and char != '\\N':
                                data.append((title_id, person_id, char[:200]))
                
                query = "INSERT INTO personajes (id_produccion, persona_id, personaje) VALUES %s"
                self.insert_fast(query, data, batch_size=10000)
        except Exception as e:
            print(f"⚠️  Error: {e}")

    def load_episodios(self):
        """Carga episodios (🔧 temporada y episodio NULL permitidos)"""
        print("\n📺 Cargando EPISODIOS...")
        try:
            df = self.read_tsv_safely(f"{self.tsv_path}/title.episode.tsv")
            if df is None:
                return
            
            data = []
            for _, row in df.iterrows():
                episode_id = self.extract_id(row.get('tconst'))
                parent_id = self.extract_id(row.get('parentTconst'))
                
                if episode_id and parent_id:
                    season = int(row.get('seasonNumber')) if pd.notna(row.get('seasonNumber')) and row.get('seasonNumber') != '\\N' else None
                    episode_num = int(row.get('episodeNumber')) if pd.notna(row.get('episodeNumber')) and row.get('episodeNumber') != '\\N' else None
                    data.append((episode_id, parent_id, season, episode_num))
            
            query = """
                INSERT INTO episodios (id_episodio, id_serie, temporada, episodio) 
                VALUES %s 
                ON CONFLICT (id_episodio) DO NOTHING
            """
            self.insert_fast(query, data)
        except Exception as e:
            print(f"⚠️  Error: {e}")

    # ==========================================
    # ACTUALIZACIONES FINALES
    # ==========================================

    def update_ratings(self):
        """Actualiza ratings"""
        print("\n⭐ Actualizando RATINGS...")
        try:
            df = self.read_tsv_safely(f"{self.tsv_path}/title.ratings.tsv")
            if df is None:
                return
            
            self.keep_alive()
            cursor = self.connection.cursor()
            
            updated_count = 0
            batch_data = []
            
            for _, row in df.iterrows():
                title_id = self.extract_id(row.get('tconst'))
                if title_id:
                    votos = int(row.get('numVotes')) if pd.notna(row.get('numVotes')) else None
                    rating = float(row.get('averageRating')) if pd.notna(row.get('averageRating')) else None
                    
                    batch_data.append((votos, rating, title_id))
                    updated_count += 1
                    
                    if len(batch_data) >= 10000:
                        execute_values(
                            cursor,
                            """
                            UPDATE produccion p
                            SET votos = t.votos, promedio_rating = t.rating
                            FROM (VALUES %s) AS t(votos, rating, id_titulo)
                            WHERE p.id_titulo = t.id_titulo
                            """,
                            batch_data
                        )
                        self.connection.commit()
                        batch_data = []
                        
                        if updated_count % 100000 == 0:
                            print(f"  → {updated_count:,} ratings actualizados...")
            
            if batch_data:
                execute_values(
                    cursor,
                    """
                    UPDATE produccion p
                    SET votos = t.votos, promedio_rating = t.rating
                    FROM (VALUES %s) AS t(votos, rating, id_titulo)
                    WHERE p.id_titulo = t.id_titulo
                    """,
                    batch_data
                )
                self.connection.commit()
            
            cursor.close()
            print(f"✅ Total ratings actualizados: {updated_count:,}")
        except Exception as e:
            print(f"❌ Error: {e}")

    def update_conocido_por(self):
        """Actualiza campo conocido por"""
        print("\n🌟 Actualizando CONOCIDO POR...")
        try:
            df = self.read_tsv_safely(
                f"{self.tsv_path}/name.basics.tsv", 
                usecols=['nconst', 'knownForTitles']
            )
            if df is None:
                return
            
            self.keep_alive()
            cursor = self.connection.cursor()
            
            updated_count = 0
            batch_data = []
            
            for _, row in df.iterrows():
                person_id = self.extract_id(row.get('nconst'))
                if person_id and pd.notna(row.get('knownForTitles')) and row.get('knownForTitles') != '\\N':
                    for ordinal, title in enumerate(row.get('knownForTitles').split(','), 1):
                        if title.strip():
                            title_id = self.extract_id(title.strip())
                            if title_id:
                                batch_data.append((ordinal, person_id, title_id))
                                updated_count += 1
                                
                                if len(batch_data) >= 10000:
                                    execute_values(
                                        cursor,
                                        """
                                        UPDATE personas_produccion pp
                                        SET conocido_por = t.ordinal
                                        FROM (VALUES %s) AS t(ordinal, id_persona, id_produccion)
                                        WHERE pp.id_persona = t.id_persona AND pp.id_produccion = t.id_produccion
                                        """,
                                        batch_data
                                    )
                                    self.connection.commit()
                                    batch_data = []
                                    
                                    if updated_count % 100000 == 0:
                                        print(f"  → {updated_count:,} actualizados...")
            
            if batch_data:
                execute_values(
                    cursor,
                    """
                    UPDATE personas_produccion pp
                    SET conocido_por = t.ordinal
                    FROM (VALUES %s) AS t(ordinal, id_persona, id_produccion)
                    WHERE pp.id_persona = t.id_persona AND pp.id_produccion = t.id_produccion
                    """,
                    batch_data
                )
                self.connection.commit()
            
            cursor.close()
            print(f"✅ Total actualizados: {updated_count:,}")
        except Exception as e:
            print(f"❌ Error: {e}")

    # ==========================================
    # FUNCIÓN PRINCIPAL
    # ==========================================

    def load_all_data(self):
        """Carga completa de datos"""
        start_time = datetime.now()
        print("\n" + "="*60)
        print("🚀 INICIANDO CARGA DE DATOS IMDB EN POSTGRESQL")
        print("="*60)
        
        try:
            self.connect_db()
            
            print("\n📦 FASE 1: CATÁLOGOS")
            print("-" * 60)
            self.load_professions()
            self.load_genres()
            self.load_title_types()
            self.load_attributes()
            
            print("\n👥 FASE 2: ENTIDADES PRINCIPALES")
            print("-" * 60)
            self.load_personas()
            self.load_produccion()
            
            print("\n🔗 FASE 3: RELACIONES")
            print("-" * 60)
            self.load_top_profesiones()
            self.load_genero_produccion()
            self.load_nombres_produccion()
            self.load_nombres_titulos_atributos()
            self.load_personas_produccion()
            self.load_personajes()
            self.load_episodios()
            
            print("\n🔄 FASE 4: ACTUALIZACIONES FINALES")
            print("-" * 60)
            self.update_ratings()
            self.update_conocido_por()
            
            end_time = datetime.now()
            duration = end_time - start_time
            
            print("\n" + "="*60)
            print(f"✅ CARGA COMPLETADA EXITOSAMENTE")
            print(f"⏱️  Tiempo total: {duration}")
            print("="*60)
            
        except Exception as e:
            print(f"\n❌ ERROR CRÍTICO: {e}")
            traceback.print_exc()
        finally:
            self.disconnect_db()