import pandas as pd
import mysql.connector
from mysql.connector import Error
import hashlib
import os
from datetime import datetime

class IMDBDataLoader:
    # constructor
    def __init__(self, db_config, tsv_path):
        self.db_config = db_config
        self.tsv_path = tsv_path
        self.connection = None
        
        self.profession_ids = {}
        self.genre_ids = {}
        self.titletype_ids = {}
        self.attribute_ids = {}
    
    # método para conectar a la base de datos
    def connect_db(self):
        # Conexión simple y rápida
        try:
            config = self.db_config.copy()
            config.update({
                'autocommit': False,
                'connection_timeout': 3600,
                'use_unicode': True,
                'charset': 'utf8mb4',
                'ssl_disabled': True,
                'use_pure': True,
            })
            
            self.connection = mysql.connector.connect(**config)
            
            cursor = self.connection.cursor()
            cursor.execute("SET SESSION wait_timeout = 86400")
            cursor.execute("SET SESSION interactive_timeout = 86400")
            cursor.execute("SET SESSION autocommit = 0")
            cursor.execute("SET SESSION foreign_key_checks = 0")
            cursor.execute("SET SESSION unique_checks = 0")
            cursor.close()
            
        except Error as e:
            print(f"Error: {e}")
            raise
    
    # método para mantener viva la conexión (como tarda mucho puede cerrarse)
    def keep_alive(self):
        try:
            if self.connection and self.connection.is_connected():
                self.connection.ping(reconnect=True, attempts=1, delay=0)
            else:
                self.connect_db()
        except:
            self.connect_db()

    # método para desconectar de la base de datos
    def disconnect_db(self):
        if self.connection and self.connection.is_connected():
            try:
                cursor = self.connection.cursor()
                cursor.execute("SET SESSION foreign_key_checks = 1")
                cursor.execute("SET SESSION unique_checks = 1")
                cursor.close()
            except:
                pass
            self.connection.close()
    
    # método para insertar datos rápidamente en lotes
    def insert_fast(self, query, data, batch_size=200000):
        if not data:
            return
            
        for i in range(0, len(data), batch_size):
            batch = data[i:i + batch_size]
            
            try:
                self.keep_alive()
                cursor = self.connection.cursor()
                cursor.executemany(query, batch)
                self.connection.commit()
                cursor.close()
            except Exception as e:
                try:
                    self.connection.close()
                except:
                    pass
                self.connect_db()
                try:
                    cursor = self.connection.cursor()
                    cursor.executemany(query, batch)
                    self.connection.commit()
                    cursor.close()
                except:
                    continue
    
    # metodos para generar IDs y formatear datos
    def generate_id(self, value, max_range=10000):
        if not value or value == '\\N':
            return None
        return abs(hash(str(value))) % max_range
    
    # metodos para extraer el ID y formatear datos
    def extract_id(self, imdb_id):
        if not imdb_id or imdb_id == '\\N':
            return None
        try:
            return int(imdb_id[2:])
        except:
            return None
    
    # metodos para formatear datos
    def format_text(self, text):
        if not text or text == '\\N':
            return None
        return text.replace('_', ' ').capitalize()
    
    # metodos para formatear años y fechas
    def year_to_date(self, year, is_end=False):
        if not year or year == '\\N':
            return None
        try:
            y = int(year)
            return f"{y}-12-31" if is_end else f"{y}-01-01"
        except:
            return None
    
    # metodos para formatear minutos a tiempo
    def minutes_to_time(self, minutes):
        if not minutes or minutes == '\\N':
            return None
        try:
            m = int(minutes)
            return f"{m//60:02d}:{m%60:02d}:00"
        except:
            return None

    # métodos para cargar la tabla de profesiones
    def load_professions(self):
        professions = set()
        
        try:
            df = pd.read_csv(f"{self.tsv_path}/name.basics.tsv", 
                           delimiter='\t', dtype=str, na_values=['\\N'], usecols=['primaryProfession'])
            
            for profs in df['primaryProfession'].dropna():
                if profs != '\\N':
                    for p in profs.split(','):
                        if p.strip():
                            professions.add(self.format_text(p.strip()))
        except:
            pass
        
        try:
            df = pd.read_csv(f"{self.tsv_path}/title.principals.tsv", 
                           delimiter='\t', dtype=str, na_values=['\\N'], usecols=['category'])
            
            for cat in df['category'].dropna().unique():
                if cat != '\\N':
                    professions.add(self.format_text(cat))
        except:
            pass
        
        data = []
        for prof in professions:
            if prof:
                prof_id = self.generate_id(prof, 10000)
                self.profession_ids[prof] = prof_id
                data.append((prof_id, prof))
        
        self.insert_fast("INSERT IGNORE INTO profesiones (id_profesion, profesion) VALUES (%s, %s)", data)
    
    # métodos para cargar la tabla de géneros
    def load_genres(self):
        try:
            df = pd.read_csv(f"{self.tsv_path}/title.basics.tsv", 
                           delimiter='\t', dtype=str, na_values=['\\N'], usecols=['genres'])
            
            genres = set()
            for genre_list in df['genres'].dropna():
                if genre_list != '\\N':
                    for g in genre_list.split(','):
                        if g.strip():
                            genres.add(self.format_text(g.strip()))
            
            data = []
            for genre in genres:
                if genre:
                    genre_id = self.generate_id(genre, 32000)
                    self.genre_ids[genre] = genre_id
                    data.append((genre_id, genre))
            
            self.insert_fast("INSERT IGNORE INTO generos (id_genero, genero) VALUES (%s, %s)", data)
        except:
            pass
    
    # métodos para cargar la tabla de tipos de producción
    def load_title_types(self):
        try:
            df = pd.read_csv(f"{self.tsv_path}/title.basics.tsv", 
                           delimiter='\t', dtype=str, na_values=['\\N'], usecols=['titleType'])
            
            types = set(df['titleType'].dropna().unique())
            types.discard('\\N')
            types.add('Unknown')
            
            data = []
            for t_type in types:
                type_id = 0 if t_type == 'Unknown' else self.generate_id(t_type, 255)
                self.titletype_ids[t_type] = type_id
                data.append((type_id, t_type))
            
            self.insert_fast("INSERT IGNORE INTO tipo_produccion (id_tipo_produccion, tipo_produccion) VALUES (%s, %s)", data)
        except:
            pass
    
    # métodos para cargar la tabla de atributos
    def load_attributes(self):
        attributes = set()
        
        try:
            for chunk in pd.read_csv(f"{self.tsv_path}/title.akas.tsv", 
                                   delimiter='\t', dtype=str, na_values=['\\N'], 
                                   chunksize=2000000, usecols=['attributes', 'types']):
                
                for attr_str in chunk['attributes'].dropna():
                    if attr_str != '\\N':
                        for attr in str(attr_str).replace('\x02', '|').split('|'):
                            if attr.strip():
                                attributes.add(('Title attribute', attr.strip()))
                
                for type_str in chunk['types'].dropna():
                    if type_str != '\\N':
                        for t in str(type_str).replace('\x02', '|').split('|'):
                            if t.strip() and t.strip() not in ['imdbDisplay', 'original']:
                                attributes.add(('Title types', t.strip()))
            
            data = []
            attr_id = 1
            for class_name, attribute in attributes:
                self.attribute_ids[(class_name, attribute)] = attr_id
                data.append((attr_id, class_name, attribute))
                attr_id += 1
            
            self.insert_fast("INSERT IGNORE INTO atributos (id_atributo, class, atributo) VALUES (%s, %s, %s)", data)
        except:
            pass

    # metodo para cargar la tabla de personas
    def load_personas(self):
        personas_data = []
        existing_ids = set()
        
        try:
            df = pd.read_csv(f"{self.tsv_path}/name.basics.tsv", 
                           delimiter='\t', dtype=str, na_values=['\\N'])
            
            for _, row in df.iterrows():
                person_id = self.extract_id(row['nconst'])
                if person_id:
                    birth = self.year_to_date(row.get('birthYear'))
                    death = self.year_to_date(row.get('deathYear'), True)
                    name = row['primaryName'] if pd.notna(row['primaryName']) else 'Unknown'
                    
                    personas_data.append((person_id, name, birth, death))
                    existing_ids.add(person_id)
        except:
            pass
        
        try:
            for chunk in pd.read_csv(f"{self.tsv_path}/title.principals.tsv", 
                                   delimiter='\t', dtype=str, na_values=['\\N'], 
                                   chunksize=2000000, usecols=['nconst']):
                
                for _, row in chunk.iterrows():
                    person_id = self.extract_id(row['nconst'])
                    if person_id and person_id not in existing_ids:
                        personas_data.append((person_id, 'Unknown', None, None))
                        existing_ids.add(person_id)
        except:
            pass
        
        self.insert_fast("INSERT IGNORE INTO personas (id_persona, nombre, ahno_nacimiento, ahno_muerte) VALUES (%s, %s, %s, %s)", personas_data)

    # metodo para cargar la tabla de produccion
    def load_produccion(self):
        produccion_data = []
        existing_ids = set()
        
        try:
            df = pd.read_csv(f"{self.tsv_path}/title.basics.tsv", 
                           delimiter='\t', dtype=str, na_values=['\\N'])
            
            for _, row in df.iterrows():
                title_id = self.extract_id(row['tconst'])
                if title_id:
                    type_id = self.titletype_ids.get(row['titleType'], 0)
                    start_date = self.year_to_date(row.get('startYear'))
                    end_date = self.year_to_date(row.get('endYear'), True)
                    runtime = self.minutes_to_time(row.get('runtimeMinutes'))
                    is_adult = 1 if row.get('isAdult') == '1' else 0
                    
                    produccion_data.append((title_id, type_id, is_adult, start_date, end_date, runtime, None, None))
                    existing_ids.add(title_id)
        except:
            pass
        
        try:
            for chunk in pd.read_csv(f"{self.tsv_path}/title.akas.tsv", 
                                   delimiter='\t', dtype=str, na_values=['\\N'], 
                                   chunksize=2000000, usecols=['titleId']):
                
                for _, row in chunk.iterrows():
                    title_id = self.extract_id(row['titleId'])
                    if title_id and title_id not in existing_ids:
                        produccion_data.append((title_id, 0, 0, None, None, None, None, None))
                        existing_ids.add(title_id)
        except:
            pass
        
        try:
            for chunk in pd.read_csv(f"{self.tsv_path}/title.principals.tsv", 
                                   delimiter='\t', dtype=str, na_values=['\\N'], 
                                   chunksize=2000000, usecols=['tconst']):
                
                for _, row in chunk.iterrows():
                    title_id = self.extract_id(row['tconst'])
                    if title_id and title_id not in existing_ids:
                        produccion_data.append((title_id, 0, 0, None, None, None, None, None))
                        existing_ids.add(title_id)
        except:
            pass
        
        self.insert_fast("""INSERT IGNORE INTO produccion 
                           (id_titulo, id_tipo_titulo, adultos, ahno_inicio, ahno_finalizacion, 
                            minutos_duracion, votos, promedio_rating) 
                           VALUES (%s, %s, %s, %s, %s, %s, %s, %s)""", produccion_data)

    # metodo para cargar la tabla de top_profesiones
    def load_top_profesiones(self):
        try:
            df = pd.read_csv(f"{self.tsv_path}/name.basics.tsv", 
                           delimiter='\t', dtype=str, na_values=['\\N'], 
                           usecols=['nconst', 'primaryProfession'])
            
            data = []
            for _, row in df.iterrows():
                person_id = self.extract_id(row['nconst'])
                if person_id and pd.notna(row['primaryProfession']) and row['primaryProfession'] != '\\N':
                    
                    for ordinal, prof in enumerate(row['primaryProfession'].split(','), 1):
                        if prof.strip():
                            formatted_prof = self.format_text(prof.strip())
                            prof_id = self.profession_ids.get(formatted_prof)
                            if prof_id:
                                data.append((person_id, prof_id, ordinal))
            
            self.insert_fast("INSERT IGNORE INTO top_profesiones (id_persona, id_profesion, ordinal) VALUES (%s, %s, %s)", data)
        except:
            pass
    
    # metodo para cargar la tabla de genero_produccion
    def load_genero_produccion(self):
        try:
            df = pd.read_csv(f"{self.tsv_path}/title.basics.tsv", 
                           delimiter='\t', dtype=str, na_values=['\\N'], 
                           usecols=['tconst', 'genres'])
            
            data = []
            for _, row in df.iterrows():
                title_id = self.extract_id(row['tconst'])
                if title_id and pd.notna(row['genres']) and row['genres'] != '\\N':
                    
                    for genre in row['genres'].split(','):
                        if genre.strip():
                            formatted_genre = self.format_text(genre.strip())
                            genre_id = self.genre_ids.get(formatted_genre)
                            if genre_id:
                                data.append((title_id, genre_id))
            
            self.insert_fast("INSERT IGNORE INTO genero_produccion (id_produccion, id_genero) VALUES (%s, %s)", data)
        except:
            pass
    
    # metodo para cargar la tabla de nombres_produccion
    def load_nombres_produccion(self):
        try:
            for chunk in pd.read_csv(f"{self.tsv_path}/title.akas.tsv", 
                                   delimiter='\t', dtype=str, na_values=['\\N'], 
                                   chunksize=2000000):
                
                data = []
                for _, row in chunk.iterrows():
                    title_id = self.extract_id(row['titleId'])
                    if title_id:
                        is_original = 1 if pd.notna(row['isOriginalTitle']) and str(row['isOriginalTitle']) == '1' else 0
                        
                        data.append((
                            title_id,
                            int(row['ordering']) if pd.notna(row['ordering']) else 1,
                            row['title'] if pd.notna(row['title']) else 'Unknown',
                            row['region'] if pd.notna(row['region']) else '',
                            row['language'] if pd.notna(row['language']) else '',
                            is_original
                        ))
                
                if data:
                    self.insert_fast("""INSERT IGNORE INTO nombres_produccion 
                                       (id_produccion, orden, nombres_produccion, region, lenguaje, esOriginal) 
                                       VALUES (%s, %s, %s, %s, %s, %s)""", data)
        except:
            pass
    
    # metodo para cargar la tabla de nombres_titulos_atributos
    def load_nombres_titulos_atributos(self):
        try:
            for chunk in pd.read_csv(f"{self.tsv_path}/title.akas.tsv", 
                                   delimiter='\t', dtype=str, na_values=['\\N'], 
                                   chunksize=2000000):
                
                data = []
                for _, row in chunk.iterrows():
                    title_id = self.extract_id(row['titleId'])
                    if title_id:
                        ordering = int(row['ordering']) if pd.notna(row['ordering']) else 1
                        
                        if pd.notna(row['attributes']) and row['attributes'] != '\\N':
                            for attr in str(row['attributes']).replace('\x02', '|').split('|'):
                                if attr.strip():
                                    attr_id = self.attribute_ids.get(('Title attribute', attr.strip()))
                                    if attr_id:
                                        data.append((title_id, ordering, attr_id))
                        
                        if pd.notna(row['types']) and row['types'] != '\\N':
                            for attr_type in str(row['types']).replace('\x02', '|').split('|'):
                                if attr_type.strip() and attr_type.strip() not in ['imdbDisplay', 'original']:
                                    attr_id = self.attribute_ids.get(('Title types', attr_type.strip()))
                                    if attr_id:
                                        data.append((title_id, ordering, attr_id))
                
                if data:
                    self.insert_fast("INSERT IGNORE INTO nombres_titulos_atributos (id_titulo, orden, id_atributo) VALUES (%s, %s, %s)", data)
        except:
            pass
    
    # metodo para cargar la tabla de personas_produccion
    def load_personas_produccion(self):
        
        # PASO 1: SOLO title.principals.tsv 
        print("Cargando title.principals.tsv...")
        
        try:
            df = pd.read_csv(f"{self.tsv_path}/title.principals.tsv", 
                        delimiter='\t', dtype=str, na_values=['\\N'])
            
            principals_data = []
            for _, row in df.iterrows():
                title_id = self.extract_id(row['tconst'])
                person_id = self.extract_id(row['nconst'])
                
                if title_id and person_id:
                    ordering = int(row['ordering']) if pd.notna(row['ordering']) else 1
                    formatted_cat = self.format_text(row['category'])
                    prof_id = self.profession_ids.get(formatted_cat)
                    
                    if prof_id:
                        principals_data.append((title_id, ordering, person_id, prof_id, None))
            
            # Insertar SOLO title.principals
            self.insert_fast("""INSERT IGNORE INTO personas_produccion 
                            (id_produccion, orden, id_persona, id_profesion, conocido_por) 
                            VALUES (%s, %s, %s, %s, %s)""", principals_data)
            
            print(f"✓ Insertados {len(principals_data):,} registros de title.principals")
            
        except Exception as e:
            print(f"✗ Error en title.principals: {e}")
            return
        
        # PASO 2: Procesar title.crew.tsv
        print("Procesando title.crew.tsv...")
        
        try:
            df_crew = pd.read_csv(f"{self.tsv_path}/title.crew.tsv", 
                                delimiter='\t', dtype=str, na_values=['\\N'])
            
            self.keep_alive()
            cursor = self.connection.cursor()
            
            # Crear writers_directors
            cursor.execute("""CREATE TEMPORARY TABLE writers_directors (
                                titleId INT,
                                principalId INT,
                                professionId INT,
                                INDEX idx_wd (titleId, principalId)
                            )""")
            
            # Procesar crew 
            director_prof_id = self.profession_ids.get('Director')
            writer_prof_id = self.profession_ids.get('Writer')
            
            for _, row in df_crew.iterrows():
                title_id = self.extract_id(row['tconst'])
                if title_id:
                    
                    # Directores
                    if pd.notna(row['directors']) and row['directors'] != '\\N':
                        for director in row['directors'].split(','):
                            if director.strip():
                                person_id = self.extract_id(director.strip())
                                if person_id and director_prof_id:
                                    # !CLAVE: Solo insertar si NO existe en personas_produccion
                                    cursor.execute("""
                                        INSERT INTO writers_directors (titleId, principalId, professionId)
                                        SELECT %s, %s, %s
                                        WHERE NOT EXISTS (
                                            SELECT 1 FROM personas_produccion pp 
                                            WHERE pp.id_produccion = %s AND pp.id_persona = %s
                                        )
                                    """, (title_id, person_id, director_prof_id, title_id, person_id))
                    
                    # Escritores
                    if pd.notna(row['writers']) and row['writers'] != '\\N':
                        for writer in row['writers'].split(','):
                            if writer.strip():
                                person_id = self.extract_id(writer.strip())
                                if person_id and writer_prof_id:
                                    # !CLAVE: Solo insertar si NO existe en personas_produccion
                                    cursor.execute("""
                                        INSERT INTO writers_directors (titleId, principalId, professionId)
                                        SELECT %s, %s, %s
                                        WHERE NOT EXISTS (
                                            SELECT 1 FROM personas_produccion pp 
                                            WHERE pp.id_produccion = %s AND pp.id_persona = %s
                                        )
                                    """, (title_id, person_id, writer_prof_id, title_id, person_id))
            
            self.connection.commit()
            
            # PASO 3: Obtener solo los faltantes
            cursor.execute("SELECT titleId, principalId, professionId FROM writers_directors")
            missing_crew = cursor.fetchall()
            print(f"✓ Encontrados {len(missing_crew):,} registros de crew faltantes")
            
            if missing_crew:
                # PASO 4: Ordinales continuos
                cursor.execute("""
                    SELECT id_produccion, MAX(orden) as max_ordinal
                    FROM personas_produccion
                    GROUP BY id_produccion
                """)
                max_ordinals = dict(cursor.fetchall())
                
                # PASO 5: ROW_NUMBER()
                final_crew_data = []
                current_title = None
                current_ordinal = 0
                
                # Ordenar por título para ROW_NUMBER() correcto
                missing_crew.sort(key=lambda x: (x[0], x[2], x[1]))  # titleId, professionId, principalId
                
                for title_id, person_id, prof_id in missing_crew:
                    if title_id != current_title:
                        current_title = title_id
                        current_ordinal = max_ordinals.get(title_id, 0)
                    
                    current_ordinal += 1
                    final_crew_data.append((title_id, current_ordinal, person_id, prof_id, None))
                
                # PASO 6: Insertar SOLO los faltantes
                self.insert_fast("""INSERT IGNORE INTO personas_produccion 
                                (id_produccion, orden, id_persona, id_profesion, conocido_por) 
                                VALUES (%s, %s, %s, %s, %s)""", final_crew_data)
                
                print(f"✓ Insertados {len(final_crew_data):,} registros adicionales de crew")
            
            # Limpiar
            cursor.execute("DROP TEMPORARY TABLE writers_directors")
            cursor.close()
            
            print("✓ personas_produccion completado CORRECTAMENTE")
            
        except Exception as e:
            print(f"✗ Error procesando crew: {e}")
            try:
                cursor.execute("DROP TEMPORARY TABLE IF EXISTS writers_directors")
                cursor.close()
            except:
                pass
    
    # metodo para parsear personajes
    def parse_characters(self, chars_str):
        if not chars_str or chars_str == '\\N':
            return []
        try:
            if chars_str.startswith('[') and chars_str.endswith(']'):
                content = chars_str[1:-1].replace('","', '\t').replace('"', '')
                return [c.strip() for c in content.split('\t') if c.strip()]
            return [chars_str]
        except:
            return [chars_str] if chars_str else []
    
    # metodo para cargar la tabla de personajes
    def load_personajes(self):
        try:
            df = pd.read_csv(f"{self.tsv_path}/title.principals.tsv", 
                           delimiter='\t', dtype=str, na_values=['\\N'],
                           usecols=['tconst', 'nconst', 'characters'])
            
            data = []
            for _, row in df.iterrows():
                title_id = self.extract_id(row['tconst'])
                person_id = self.extract_id(row['nconst'])
                
                if title_id and person_id and pd.notna(row['characters']):
                    characters = self.parse_characters(row['characters'])
                    for char in characters:
                        if char and char != '\\N':
                            data.append((title_id, person_id, char[:100]))
            
            self.insert_fast("INSERT IGNORE INTO personajes (id_produccion, persona_id, personaje) VALUES (%s, %s, %s)", data)
        except:
            pass
    
    # metodo para cargar la tabla de episodios
    def load_episodios(self):
        try:
            df = pd.read_csv(f"{self.tsv_path}/title.episode.tsv", 
                           delimiter='\t', dtype=str, na_values=['\\N'])
            
            data = []
            for _, row in df.iterrows():
                episode_id = self.extract_id(row['tconst'])
                parent_id = self.extract_id(row['parentTconst'])
                
                if episode_id and parent_id:
                    season = int(row['seasonNumber']) if pd.notna(row['seasonNumber']) else None
                    episode_num = int(row['episodeNumber']) if pd.notna(row['episodeNumber']) else None
                    data.append((episode_id, parent_id, season, episode_num))
            
            self.insert_fast("INSERT IGNORE INTO episodios (id_episodio, id_serie, temporada, episodio) VALUES (%s, %s, %s, %s)", data)
        except:
            pass
    
    # metodo para actualizar votos y ratings en produccion
    def update_ratings(self):
        try:
            df = pd.read_csv(f"{self.tsv_path}/title.ratings.tsv", 
                           delimiter='\t', dtype=str, na_values=['\\N'])
            
            self.keep_alive()
            cursor = self.connection.cursor()
            
            for i in range(0, len(df), 100000):
                batch = df.iloc[i:i+100000]
                
                for _, row in batch.iterrows():
                    title_id = self.extract_id(row['tconst'])
                    if title_id:
                        votos = int(row['numVotes']) if pd.notna(row['numVotes']) else None
                        rating = float(row['averageRating']) if pd.notna(row['averageRating']) else None
                        
                        cursor.execute("""UPDATE produccion 
                                       SET votos = %s, promedio_rating = %s 
                                       WHERE id_titulo = %s""", (votos, rating, title_id))
                
                self.connection.commit()
            
            cursor.close()
        except:
            pass
    
    # metodo para actualizar conocido_por en personas_produccion
    def update_conocido_por(self):
        try:
            df = pd.read_csv(f"{self.tsv_path}/name.basics.tsv", 
                           delimiter='\t', dtype=str, na_values=['\\N'],
                           usecols=['nconst', 'knownForTitles'])
            
            self.keep_alive()
            cursor = self.connection.cursor()
            
            for i, row in df.iterrows():
                person_id = self.extract_id(row['nconst'])
                if person_id and pd.notna(row['knownForTitles']) and row['knownForTitles'] != '\\N':
                    
                    for ordinal, title in enumerate(row['knownForTitles'].split(','), 1):
                        if title.strip():
                            title_id = self.extract_id(title.strip())
                            if title_id:
                                cursor.execute("""UPDATE personas_produccion 
                                               SET conocido_por = %s 
                                               WHERE id_persona = %s AND id_produccion = %s""",
                                             (ordinal, person_id, title_id))
                
                if i % 100000 == 0:
                    self.connection.commit()
            
            self.connection.commit()
            cursor.close()
        except:
            pass

    # método principal para cargar todos los datos
    def load_all_data(self):
        start_time = datetime.now()
        
        try:
            self.connect_db()
            
            # Cargar datos en orden lógico
            self.load_professions()
            self.load_genres()
            self.load_title_types()
            self.load_attributes()
            
            self.load_personas()
            self.load_produccion()
            
            self.load_top_profesiones()
            self.load_genero_produccion()
            self.load_nombres_produccion()
            self.load_nombres_titulos_atributos()
            self.load_personas_produccion()
            self.load_personajes()
            self.load_episodios()
            
            self.update_ratings()
            self.update_conocido_por()
            
            end_time = datetime.now()
            duration = end_time - start_time
            print(f"Completado en: {duration}")
            
        except Exception as e:
            print(f"Error: {e}")
        finally:
            self.disconnect_db()