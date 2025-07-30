import pandas as pd
import mysql.connector
from mysql.connector import Error
from datetime import datetime
import logging

# Configurar logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class NetflixDataNormalizer:
    def __init__(self, db_config):
        self.db_config = db_config
        self.connection = None
        self.cursor = None
        
        # Cachés para evitar consultas repetidas
        self.categories_cache = {}
        self.countries_cache = {}
        self.directors_cache = {}
        self.actors_cache = {}
        self.show_types_cache = {}
        self.ratings_cache = {}

    # Establece conexión con la base de datos MySQL
    def connect_to_database(self):
        try:
            self.connection = mysql.connector.connect(**self.db_config)
            self.cursor = self.connection.cursor()
            logger.info("Conexión exitosa a la base de datos")
            return True
        except Error as e:
            logger.error(f"Error conectando a la base de datos: {e}")
            return False

    # Cierra la conexión con la base de datos
    def close_connection(self):
        if self.cursor:
            self.cursor.close()
        if self.connection:
            self.connection.close()
        logger.info("Conexión cerrada")

    # Asegura que los datos maestros existan en la base de datos
    def ensure_master_data(self):
        try:
            # Verificar y crear tipos de show
            self.cursor.execute("SELECT COUNT(*) FROM show_type")
            if self.cursor.fetchone()[0] == 0:
                logger.info("Insertando tipos de show...")
                self.cursor.execute("INSERT INTO show_type (name) VALUES ('Movie'), ('TV Show')")
            
            # Verificar y crear ratings
            self.cursor.execute("SELECT COUNT(*) FROM show_rating")
            if self.cursor.fetchone()[0] == 0:
                logger.info("Insertando ratings...")
                ratings_data = [
                    ('G', 'General Audiences'),
                    ('PG', 'Parental Guidance Suggested'),
                    ('PG-13', 'Parents Strongly Cautioned'),
                    ('R', 'Restricted'),
                    ('NC-17', 'Adults Only'),
                    ('TV-Y', 'All Children'),
                    ('TV-Y7', 'Directed to Older Children'),
                    ('TV-G', 'General Audience'),
                    ('TV-PG', 'Parental Guidance Suggested'),
                    ('TV-14', 'Parents Strongly Cautioned'),
                    ('TV-MA', 'Mature Audience Only'),
                    ('NR', 'Not Rated'),
                    ('UR', 'Unrated')
                ]
                for rating_name, description in ratings_data:
                    self.cursor.execute("INSERT INTO show_rating (name, description) VALUES (%s, %s)", 
                                      (rating_name, description))
            
            # Commit los cambios
            self.connection.commit()
            logger.info("Datos maestros verificados/creados exitosamente")
            
        except Error as e:
            logger.error(f"Error creando datos maestros: {e}")
            raise

    # Carga datos existentes en caché para evitar duplicados
    def load_cache_data(self):
        try:
            # Cargar tipos de show
            self.cursor.execute("SELECT id_show_type, name FROM show_type")
            rows = self.cursor.fetchall()
            self.show_types_cache = {row[1]: row[0] for row in rows}
            logger.info(f"Tipos de show cargados: {self.show_types_cache}")

            # Cargar ratings
            self.cursor.execute("SELECT id_rating, name FROM show_rating")
            rows = self.cursor.fetchall()
            self.ratings_cache = {row[1]: row[0] for row in rows}
            logger.info(f"Ratings cargados: {len(self.ratings_cache)} registros")

            # Cargar categorías existentes
            self.cursor.execute("SELECT id_category, name FROM category")
            rows = self.cursor.fetchall()
            self.categories_cache = {row[1]: row[0] for row in rows}
            logger.info(f"Categorías cargadas: {len(self.categories_cache)} registros")

            # Cargar países existentes
            self.cursor.execute("SELECT id_country, name FROM country")
            rows = self.cursor.fetchall()
            self.countries_cache = {row[1]: row[0] for row in rows}
            logger.info(f"Países cargados: {len(self.countries_cache)} registros")

            # Cargar directores existentes
            self.cursor.execute("SELECT id_director, name FROM director")
            rows = self.cursor.fetchall()
            self.directors_cache = {row[1]: row[0] for row in rows}
            logger.info(f"Directores cargados: {len(self.directors_cache)} registros")

            # Cargar actores existentes
            self.cursor.execute("SELECT id_actor, name FROM actor")
            rows = self.cursor.fetchall()
            self.actors_cache = {row[1]: row[0] for row in rows}
            logger.info(f"Actores cargados: {len(self.actors_cache)} registros")

            logger.info("Cache cargado exitosamente")
        except Error as e:
            logger.error(f"Error cargando cache: {e}")
            raise

    # Limpia y divide strings multivaluados
    def clean_and_split_string(self, value, separator=','):
        if pd.isna(value) or value == '':
            return []
        
        # Limpiar y dividir
        items = [item.strip() for item in str(value).split(separator) if item.strip()]
        return list(set(items))  # Eliminar duplicados

    # Obtiene o crea una categoría y retorna su ID
    def get_or_create_category(self, category_name):
        if not category_name or category_name.strip() == '':
            return None
            
        category_name = category_name.strip()
        
        if category_name in self.categories_cache:
            return self.categories_cache[category_name]
        
        try:
            query = "INSERT INTO category (name) VALUES (%s)"
            self.cursor.execute(query, (category_name,))
            category_id = self.cursor.lastrowid
            self.categories_cache[category_name] = category_id
            logger.debug(f"Categoría creada: {category_name} (ID: {category_id})")
            return category_id
        except Error as e:
            logger.error(f"Error creando categoría {category_name}: {e}")
            return None

    # Obtiene o crea un país y retorna su ID
    def get_or_create_country(self, country_name):
        if not country_name or country_name.strip() == '':
            return None
            
        country_name = country_name.strip()
        
        if country_name in self.countries_cache:
            return self.countries_cache[country_name]
        
        try:
            query = "INSERT INTO country (name) VALUES (%s)"
            self.cursor.execute(query, (country_name,))
            country_id = self.cursor.lastrowid
            self.countries_cache[country_name] = country_id
            logger.debug(f"País creado: {country_name} (ID: {country_id})")
            return country_id
        except Error as e:
            logger.error(f"Error creando país {country_name}: {e}")
            return None

    # Obtiene o crea un director y retorna su ID
    def get_or_create_director(self, director_name):
        if not director_name or director_name.strip() == '':
            return None
            
        director_name = director_name.strip()
        
        if director_name in self.directors_cache:
            return self.directors_cache[director_name]
        
        try:
            query = "INSERT INTO director (name) VALUES (%s)"
            self.cursor.execute(query, (director_name,))
            director_id = self.cursor.lastrowid
            self.directors_cache[director_name] = director_id
            logger.debug(f"Director creado: {director_name} (ID: {director_id})")
            return director_id
        except Error as e:
            logger.error(f"Error creando director {director_name}: {e}")
            return None

    # Obtiene o crea un actor y retorna su ID
    def get_or_create_actor(self, actor_name):
        if not actor_name or actor_name.strip() == '':
            return None
            
        actor_name = actor_name.strip()
        
        if actor_name in self.actors_cache:
            return self.actors_cache[actor_name]
        
        try:
            query = "INSERT INTO actor (name) VALUES (%s)"
            self.cursor.execute(query, (actor_name,))
            actor_id = self.cursor.lastrowid
            self.actors_cache[actor_name] = actor_id
            logger.debug(f"Actor creado: {actor_name} (ID: {actor_id})")
            return actor_id
        except Error as e:
            logger.error(f"Error creando actor {actor_name}: {e}")
            return None

    # Obtiene o crea un rating y retorna su ID
    def get_or_create_rating(self, rating_name):
        if not rating_name or rating_name.strip() == '':
            return None
            
        rating_name = rating_name.strip()
        
        if rating_name in self.ratings_cache:
            return self.ratings_cache[rating_name]
        
        try:
            query = "INSERT INTO show_rating (name, description) VALUES (%s, %s)"
            self.cursor.execute(query, (rating_name, f"Rating {rating_name}"))
            rating_id = self.cursor.lastrowid
            self.ratings_cache[rating_name] = rating_id
            logger.debug(f"Rating creado: {rating_name} (ID: {rating_id})")
            return rating_id
        except Error as e:
            logger.error(f"Error creando rating {rating_name}: {e}")
            return None

    # Parsea la fecha de adición
    def parse_date(self, date_str):
        if pd.isna(date_str) or date_str == '':
            return None
        
        try:
            # Formato esperado: "September 25, 2021"
            date_obj = datetime.strptime(str(date_str).strip(), "%B %d, %Y")
            return date_obj.date()
        except ValueError:
            try:
                # Formato alternativo: "2021-09-25"
                date_obj = datetime.strptime(str(date_str).strip(), "%Y-%m-%d")
                return date_obj.date()
            except ValueError:
                logger.warning(f"No se pudo parsear la fecha: {date_str}")
                return None

    # Inserta un show y sus relaciones
    def insert_show(self, row):
        try:
            # Obtener IDs de las entidades relacionadas
            show_type_id = self.show_types_cache.get(row['type'])
            if not show_type_id:
                logger.error(f"Tipo de show no encontrado: {row['type']}")
                return None

            # Obtener o crear rating
            rating_id = self.get_or_create_rating(row['rating']) if pd.notna(row['rating']) else None
            
            # Obtener o crear director (solo el primero si hay múltiples)
            directors = self.clean_and_split_string(row['director'])
            director_id = None
            if directors:
                director_id = self.get_or_create_director(directors[0])
            
            # Obtener o crear país (solo el primero si hay múltiples)
            countries = self.clean_and_split_string(row['country'])
            country_id = None
            if countries:
                country_id = self.get_or_create_country(countries[0])
            
            # Obtener o crear categoría (solo la primera si hay múltiples)
            categories = self.clean_and_split_string(row['listed_in'])
            category_id = None
            if categories:
                category_id = self.get_or_create_category(categories[0])
            
            # Parsear fecha
            date_added = self.parse_date(row['date_added'])
            
            # Parsear año de lanzamiento
            release_year = int(row['release_year']) if pd.notna(row['release_year']) else None

            # Insertar show_tv principal
            show_query = """
INSERT INTO show_tv (show_id, title, date_added, release_year, duration, 
                   description, id_category, id_country, id_director, 
                   id_show_type, id_rating)
VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
"""
            
            show_data = (
                row['show_id'],
                row['title'],
                date_added,
                release_year,
                row['duration'] if pd.notna(row['duration']) else None,
                row['description'] if pd.notna(row['description']) else None,
                category_id,
                country_id,
                director_id,
                show_type_id,
                rating_id
            )
            
            self.cursor.execute(show_query, show_data)
            show_id = self.cursor.lastrowid
            
            logger.debug(f"Show insertado: {row['title']} (ID: {show_id})")
            
            # Insertar actores
            self.insert_show_actors(show_id, row)
            
            return show_id
            
        except Error as e:
            logger.error(f"Error insertando show {row['title']}: {e}")
            return None

    # Inserta las relaciones del show con actores
    def insert_show_actors(self, show_id, row):
        # Insertar actores
        actors = self.clean_and_split_string(row['cast'])
        for actor_name in actors:
            actor_id = self.get_or_create_actor(actor_name)
            if actor_id:
                try:
                    query = "INSERT IGNORE INTO show_actor (id_show, id_actor) VALUES (%s, %s)"
                    self.cursor.execute(query, (show_id, actor_id))
                except Error as e:
                    logger.warning(f"Error insertando relación actor: {e}")

    # Procesa el archivo CSV completo
    def process_csv(self, csv_file_path):
        try:
            # Leer CSV
            logger.info(f"Leyendo archivo CSV: {csv_file_path}")
            df = pd.read_csv(csv_file_path)
            logger.info(f"Total de registros en CSV: {len(df)}")
            
            # Conectar a la base de datos
            if not self.connect_to_database():
                return False
            
            # Asegurar que los datos maestros existan
            self.ensure_master_data()
            
            # Cargar cache
            self.load_cache_data()
            
            # Procesar cada fila
            successful_inserts = 0
            failed_inserts = 0
            
            for index, row in df.iterrows():
                try:
                    if self.insert_show(row):
                        successful_inserts += 1
                    else:
                        failed_inserts += 1
                    
                    # Commit cada 50 registros
                    if (index + 1) % 50 == 0:
                        self.connection.commit()
                        logger.info(f"Procesados {index + 1} registros...")
                        
                except Exception as e:
                    logger.error(f"Error procesando fila {index}: {e}")
                    failed_inserts += 1
                    continue
            
            # Commit final
            self.connection.commit()
            
            logger.info(f"Procesamiento completado:")
            logger.info(f"  - Inserciones exitosas: {successful_inserts}")
            logger.info(f"  - Inserciones fallidas: {failed_inserts}")
            
            return True
            
        except Exception as e:
            logger.error(f"Error procesando CSV: {e}")
            return False
        finally:
            self.close_connection()

def main():
    # Configuración de la base de datos
    db_config = {
        'host': 'localhost',
        'database': 'based_tarea',
        'user': 'root',
        'password': 'root',
        'charset': 'utf8mb4',
        'autocommit': False
    }
    
    # Ruta del csv
    csv_file_path = 'Tarea1/netflix_titles.csv'
    
    # Crear instancia del normalizador
    normalizer = NetflixDataNormalizer(db_config)
    
    # Procesar el archivo
    logger.info("Iniciando normalización de datos de Netflix...")
    success = normalizer.process_csv(csv_file_path)
    
    if success:
        logger.info("¡Normalización completada exitosamente!")
    else:
        logger.error("La normalización falló")

if __name__ == "__main__":
    main()