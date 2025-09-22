import pandas as pd
import mysql.connector
from mysql.connector import Error
import hashlib
import os
from datetime import datetime

class IMDBDataLoader:
    def __init__(self, db_config, tsv_path):
        self.db_config = db_config
        self.tsv_path = tsv_path
        self.connection = None
        
        self.profession_ids = {}
        self.genre_ids = {}
        self.titletype_ids = {}
        self.attribute_ids = {}
    
    def connect_db(self):
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
    
    def keep_alive(self):
        try:
            if self.connection and self.connection.is_connected():
                self.connection.ping(reconnect=True, attempts=1, delay=0)
            else:
                self.connect_db()
        except:
            self.connect_db()

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
    
    def read_tsv_safely(self, file_path, usecols=None):
        try:
            if not os.path.exists(file_path):
                print(f"Archivo no encontrado: {file_path}")
                return None
                
            print(f"Leyendo: {os.path.basename(file_path)}")
            
            read_params = {
                'delimiter': '\t',
                'dtype': str,
                'na_values': ['\\N'],
                'keep_default_na': False,
                'encoding': 'utf-8',
                'quoting': 3,
            }
            
            if usecols:
                read_params['usecols'] = usecols
                
            df = pd.read_csv(file_path, **read_params)
            print(f"Leido: {len(df):,} filas")
            return df
            
        except Exception as e:
            print(f"Error leyendo {file_path}: {e}")
            return None
    
    def extract_id(self, imdb_id):
        if not imdb_id or imdb_id == '\\N':
            return None
        try:
            return int(imdb_id[2:])
        except:
            return None
    
    def format_text(self, text):
        if not text or text == '\\N':
            return None
        return text.replace('_', ' ').capitalize()
    
    def year_to_date(self, year, is_end=False):
        if not year or year == '\\N':
            return None
        try:
            y = int(year)
            return f"{y}-12-31" if is_end else f"{y}-01-01"
        except:
            return None
    
    def minutes_to_time(self, minutes):
        if not minutes or minutes == '\\N':
            return None
        try:
            m = int(minutes)
            return f"{m//60:02d}:{m%60:02d}:00"
        except:
            return None

    def load_professions(self):
        """CORREGIDO: IDs secuenciales para evitar colisiones"""
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
            df = self.read_tsv_safely(f"{self.tsv_path}/title.principals.tsv", usecols=['category'])
            if df is not None:
                for cat in df['category'].dropna().unique():
                    if cat != '\\N':
                        professions.add(self.format_text(cat))
        except:
            pass
        
        # CORREGIDO: IDs secuenciales
        data = []
        prof_id = 1  # Empezar en 1
        
        for prof in sorted(professions):  # sorted para consistencia
            if prof:
                self.profession_ids[prof] = prof_id
                data.append((prof_id, prof))
                prof_id += 1
        
        self.insert_fast("INSERT IGNORE INTO profesiones (id_profesion, profesion) VALUES (%s, %s)", data)
        print(f"Profesiones: {len(data)} registros")
    
    def load_genres(self):
        """CORREGIDO: IDs secuenciales para evitar colisiones"""
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
            
            # CORREGIDO: IDs secuenciales
            data = []
            genre_id = 1  # Empezar en 1
            
            for genre in sorted(genres):  # sorted para consistencia
                if genre:
                    self.genre_ids[genre] = genre_id
                    data.append((genre_id, genre))
                    genre_id += 1
            
            self.insert_fast("INSERT IGNORE INTO generos (id_genero, genero) VALUES (%s, %s)", data)
            print(f"Generos: {len(data)} registros")
        except:
            pass
    
    def load_title_types(self):
        """YA CORREGIDO: IDs secuenciales"""
        try:
            df = self.read_tsv_safely(f"{self.tsv_path}/title.basics.tsv", usecols=['titleType'])
            if df is None:
                return
            
            types = set(df['titleType'].dropna().unique())
            types.discard('\\N')
            types.add('Unknown')
            
            data = []
            type_id = 0  # Empezar en 0
            
            # Asegurar que Unknown tenga ID 0
            self.titletype_ids['Unknown'] = 0
            data.append((0, 'Unknown'))
            type_id = 1
            
            # Asignar IDs secuenciales al resto
            for t_type in sorted(types):  # sorted para consistencia
                if t_type != 'Unknown':  # Ya procesamos Unknown
                    self.titletype_ids[t_type] = type_id
                    data.append((type_id, t_type))
                    type_id += 1
            
            self.insert_fast("INSERT IGNORE INTO tipo_produccion (id_tipo_produccion, tipo_produccion) VALUES (%s, %s)", data)
            print(f"Tipos produccion: {len(data)} registros")
        except:
            pass
    
    def load_attributes(self):
        """CORREGIDO: IDs secuenciales para evitar colisiones"""
        attributes = set()
        
        try:
            df = self.read_tsv_safely(f"{self.tsv_path}/title.akas.tsv", usecols=['attributes', 'types'])
            if df is None:
                return
                
            for attr_str in df['attributes'].dropna():
                if attr_str != '\\N':
                    try:
                        for attr in str(attr_str).replace('\x02', '|').split('|'):
                            if attr.strip():
                                attributes.add(('Title attribute', attr.strip()[:100]))
                    except:
                        continue
            
            for type_str in df['types'].dropna():
                if type_str != '\\N':
                    try:
                        for t in str(type_str).replace('\x02', '|').split('|'):
                            if t.strip() and t.strip() not in ['imdbDisplay', 'original']:
                                attributes.add(('Title types', t.strip()[:100]))
                    except:
                        continue
            
            # CORREGIDO: IDs secuenciales
            data = []
            attr_id = 1  # Empezar en 1
            
            # Ordenar por class y atributo para consistencia
            for class_name, attribute in sorted(attributes):
                self.attribute_ids[(class_name, attribute)] = attr_id
                data.append((attr_id, class_name, attribute))
                attr_id += 1
            
            self.insert_fast("INSERT IGNORE INTO atributos (id_atributo, class, atributo) VALUES (%s, %s, %s)", data)
            print(f"Atributos: {len(data)} registros")
        except:
            pass

    def load_personas(self):
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
                        name = row.get('primaryName', 'Unknown') if pd.notna(row.get('primaryName')) else 'Unknown'
                        
                        personas_data.append((person_id, name, birth, death))
                        existing_ids.add(person_id)
        except:
            pass
        
        try:
            df = self.read_tsv_safely(f"{self.tsv_path}/title.principals.tsv", usecols=['nconst'])
            if df is not None:
                for _, row in df.iterrows():
                    person_id = self.extract_id(row.get('nconst'))
                    if person_id and person_id not in existing_ids:
                        personas_data.append((person_id, 'Unknown', None, None))
                        existing_ids.add(person_id)
        except:
            pass
        
        self.insert_fast("INSERT IGNORE INTO personas (id_persona, nombre, ahno_nacimiento, ahno_muerte) VALUES (%s, %s, %s, %s)", personas_data)
        print(f"Personas: {len(personas_data)} registros")

    def load_produccion(self):
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
                        runtime = self.minutes_to_time(row.get('runtimeMinutes'))
                        is_adult = 1 if row.get('isAdult') == '1' else 0
                        
                        produccion_data.append((title_id, type_id, is_adult, start_date, end_date, runtime, None, None))
                        existing_ids.add(title_id)
        except:
            pass
        
        try:
            df = self.read_tsv_safely(f"{self.tsv_path}/title.akas.tsv", usecols=['titleId'])
            if df is not None:
                for _, row in df.iterrows():
                    title_id = self.extract_id(row.get('titleId'))
                    if title_id and title_id not in existing_ids:
                        produccion_data.append((title_id, 0, 0, None, None, None, None, None))
                        existing_ids.add(title_id)
        except:
            pass
        
        try:
            df = self.read_tsv_safely(f"{self.tsv_path}/title.principals.tsv", usecols=['tconst'])
            if df is not None:
                for _, row in df.iterrows():
                    title_id = self.extract_id(row.get('tconst'))
                    if title_id and title_id not in existing_ids:
                        produccion_data.append((title_id, 0, 0, None, None, None, None, None))
                        existing_ids.add(title_id)
        except:
            pass
        
        self.insert_fast("""INSERT IGNORE INTO produccion 
                           (id_titulo, id_tipo_titulo, adultos, ahno_inicio, ahno_finalizacion, 
                            minutos_duracion, votos, promedio_rating) 
                           VALUES (%s, %s, %s, %s, %s, %s, %s, %s)""", produccion_data)
        print(f"Produccion: {len(produccion_data)} registros")

    def load_top_profesiones(self):
        try:
            df = self.read_tsv_safely(f"{self.tsv_path}/name.basics.tsv", usecols=['nconst', 'primaryProfession'])
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
            
            self.insert_fast("INSERT IGNORE INTO top_profesiones (id_persona, id_profesion, ordinal) VALUES (%s, %s, %s)", data)
            print(f"Top profesiones: {len(data)} registros")
        except:
            pass
    
    def load_genero_produccion(self):
        try:
            df = self.read_tsv_safely(f"{self.tsv_path}/title.basics.tsv", usecols=['tconst', 'genres'])
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
            
            self.insert_fast("INSERT IGNORE INTO genero_produccion (id_produccion, id_genero) VALUES (%s, %s)", data)
            print(f"Genero produccion: {len(data)} registros")
        except:
            pass
    
    def load_nombres_produccion(self):
        try:
            df = self.read_tsv_safely(f"{self.tsv_path}/title.akas.tsv")
            if df is None:
                return
                
            data = []
            for _, row in df.iterrows():
                title_id = self.extract_id(row.get('titleId'))
                if title_id:
                    is_original = 1 if pd.notna(row.get('isOriginalTitle')) and str(row.get('isOriginalTitle')) == '1' else 0
                    
                    title = str(row.get('title', 'Unknown'))[:255] if pd.notna(row.get('title')) else 'Unknown'
                    region = str(row.get('region', ''))[:10] if pd.notna(row.get('region')) else ''
                    language = str(row.get('language', ''))[:10] if pd.notna(row.get('language')) else ''
                    ordering = int(row.get('ordering', 1)) if pd.notna(row.get('ordering')) else 1
                    
                    data.append((title_id, ordering, title, region, language, is_original))

            self.insert_fast("""INSERT IGNORE INTO nombres_produccion 
                               (id_produccion, orden, nombres_produccion, region, lenguaje, esOriginal) 
                               VALUES (%s, %s, %s, %s, %s, %s)""", data)
            print(f"Nombres produccion: {len(data)} registros")
        except:
            pass
    
    def load_nombres_titulos_atributos(self):
        try:
            df = self.read_tsv_safely(f"{self.tsv_path}/title.akas.tsv")
            if df is None:
                return
                
            data = []
            for _, row in df.iterrows():
                title_id = self.extract_id(row.get('titleId'))
                if title_id:
                    ordering = int(row.get('ordering', 1)) if pd.notna(row.get('ordering')) else 1
                    
                    if pd.notna(row.get('attributes')) and row.get('attributes') != '\\N':
                        try:
                            for attr in str(row.get('attributes')).replace('\x02', '|').split('|'):
                                if attr.strip():
                                    attr_id = self.attribute_ids.get(('Title attribute', attr.strip()))
                                    if attr_id:
                                        data.append((title_id, ordering, attr_id))
                        except:
                            continue
                    
                    if pd.notna(row.get('types')) and row.get('types') != '\\N':
                        try:
                            for attr_type in str(row.get('types')).replace('\x02', '|').split('|'):
                                if attr_type.strip() and attr_type.strip() not in ['imdbDisplay', 'original']:
                                    attr_id = self.attribute_ids.get(('Title types', attr_type.strip()))
                                    if attr_id:
                                        data.append((title_id, ordering, attr_id))
                        except:
                            continue

            self.insert_fast("INSERT IGNORE INTO nombres_titulos_atributos (id_titulo, orden, id_atributo) VALUES (%s, %s, %s)", data)
            print(f"Nombres titulos atributos: {len(data)} registros")
        except:
            pass
    
    def load_personas_produccion(self):
        
        try:
            df = self.read_tsv_safely(f"{self.tsv_path}/title.principals.tsv")
            if df is None:
                return
            
            principals_data = []
            for _, row in df.iterrows():
                title_id = self.extract_id(row.get('tconst'))
                person_id = self.extract_id(row.get('nconst'))
                
                if title_id and person_id:
                    ordering = int(row.get('ordering')) if pd.notna(row.get('ordering')) else 1
                    formatted_cat = self.format_text(row.get('category'))
                    prof_id = self.profession_ids.get(formatted_cat)
                    
                    if prof_id:
                        principals_data.append((title_id, ordering, person_id, prof_id, None))
            
            self.insert_fast("""INSERT IGNORE INTO personas_produccion 
                            (id_produccion, orden, id_persona, id_profesion, conocido_por) 
                            VALUES (%s, %s, %s, %s, %s)""", principals_data)
            
        except Exception as e:
            return
        
        try:
            df_crew = self.read_tsv_safely(f"{self.tsv_path}/title.crew.tsv")
            if df_crew is None:
                print(f"Personas produccion: {len(principals_data)} registros")
                return
            
            self.keep_alive()
            cursor = self.connection.cursor()
            
            cursor.execute("""CREATE TEMPORARY TABLE writers_directors (
                                titleId INT,
                                principalId INT,
                                professionId INT,
                                INDEX idx_wd (titleId, principalId)
                            )""")
            
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
                
                self.insert_fast("""INSERT IGNORE INTO personas_produccion 
                                (id_produccion, orden, id_persona, id_profesion, conocido_por) 
                                VALUES (%s, %s, %s, %s, %s)""", final_crew_data)
                
                total_records = len(principals_data) + len(final_crew_data)
            else:
                total_records = len(principals_data)
            
            cursor.execute("DROP TEMPORARY TABLE writers_directors")
            cursor.close()
            
            print(f"Personas produccion: {total_records} registros")
            
        except Exception as e:
            try:
                cursor.execute("DROP TEMPORARY TABLE IF EXISTS writers_directors")
                cursor.close()
            except:
                pass
            print(f"Personas produccion: {len(principals_data)} registros")
    
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
    
    def load_personajes(self):
        try:
            df = self.read_tsv_safely(f"{self.tsv_path}/title.principals.tsv", usecols=['tconst', 'nconst', 'characters'])
            if df is None:
                return
            
            data = []
            for _, row in df.iterrows():
                title_id = self.extract_id(row.get('tconst'))
                person_id = self.extract_id(row.get('nconst'))
                
                if title_id and person_id and pd.notna(row.get('characters')):
                    characters = self.parse_characters(row.get('characters'))
                    for char in characters:
                        if char and char != '\\N':
                            data.append((title_id, person_id, char[:100]))
            
            self.insert_fast("INSERT IGNORE INTO personajes (id_produccion, persona_id, personaje) VALUES (%s, %s, %s)", data)
            print(f"Personajes: {len(data)} registros")
        except:
            pass
    
    def load_episodios(self):
        try:
            df = self.read_tsv_safely(f"{self.tsv_path}/title.episode.tsv")
            if df is None:
                return
            
            data = []
            for _, row in df.iterrows():
                episode_id = self.extract_id(row.get('tconst'))
                parent_id = self.extract_id(row.get('parentTconst'))
                
                if episode_id and parent_id:
                    season = int(row.get('seasonNumber')) if pd.notna(row.get('seasonNumber')) else None
                    episode_num = int(row.get('episodeNumber')) if pd.notna(row.get('episodeNumber')) else None
                    data.append((episode_id, parent_id, season, episode_num))
            
            self.insert_fast("INSERT IGNORE INTO episodios (id_episodio, id_serie, temporada, episodio) VALUES (%s, %s, %s, %s)", data)
            print(f"Episodios: {len(data)} registros")
        except:
            pass
    
    def update_ratings(self):
        try:
            df = self.read_tsv_safely(f"{self.tsv_path}/title.ratings.tsv")
            if df is None:
                return
            
            self.keep_alive()
            cursor = self.connection.cursor()
            
            updated_count = 0
            for i in range(0, len(df), 100000):
                batch = df.iloc[i:i+100000]
                
                for _, row in batch.iterrows():
                    title_id = self.extract_id(row.get('tconst'))
                    if title_id:
                        votos = int(row.get('numVotes')) if pd.notna(row.get('numVotes')) else None
                        rating = float(row.get('averageRating')) if pd.notna(row.get('averageRating')) else None
                        
                        cursor.execute("""UPDATE produccion 
                                       SET votos = %s, promedio_rating = %s 
                                       WHERE id_titulo = %s""", (votos, rating, title_id))
                        updated_count += 1
                
                self.connection.commit()
            
            cursor.close()
            print(f"Ratings actualizados: {updated_count} registros")
        except:
            pass
    
    def update_conocido_por(self):
        try:
            df = self.read_tsv_safely(f"{self.tsv_path}/name.basics.tsv", usecols=['nconst', 'knownForTitles'])
            if df is None:
                return
            
            self.keep_alive()
            cursor = self.connection.cursor()
            
            updated_count = 0
            for i, row in df.iterrows():
                person_id = self.extract_id(row.get('nconst'))
                if person_id and pd.notna(row.get('knownForTitles')) and row.get('knownForTitles') != '\\N':
                    
                    for ordinal, title in enumerate(row.get('knownForTitles').split(','), 1):
                        if title.strip():
                            title_id = self.extract_id(title.strip())
                            if title_id:
                                cursor.execute("""UPDATE personas_produccion 
                                               SET conocido_por = %s 
                                               WHERE id_persona = %s AND id_produccion = %s""",
                                             (ordinal, person_id, title_id))
                                updated_count += 1
                
                if i % 100000 == 0:
                    self.connection.commit()
            
            self.connection.commit()
            cursor.close()
            print(f"Conocido por actualizado: {updated_count} registros")
        except:
            pass

    def load_all_data(self):
        start_time = datetime.now()
        
        try:
            self.connect_db()
            
            print("=== CARGANDO CATÁLOGOS (IDs SECUENCIALES) ===")
            self.load_professions()
            self.load_genres()
            self.load_title_types()
            self.load_attributes()
            
            print("=== CARGANDO ENTIDADES PRINCIPALES ===")
            self.load_personas()
            self.load_produccion()
            
            print("=== CARGANDO RELACIONES ===")
            self.load_top_profesiones()
            self.load_genero_produccion()
            self.load_nombres_produccion()
            self.load_nombres_titulos_atributos()
            self.load_personas_produccion()
            self.load_personajes()
            self.load_episodios()
            
            print("=== ACTUALIZACIONES FINALES ===")
            self.update_ratings()
            self.update_conocido_por()
            
            end_time = datetime.now()
            duration = end_time - start_time
            print(f"COMPLETADO en: {duration}")
            
        except Exception as e:
            print(f"Error: {e}")
        finally:
            self.disconnect_db()