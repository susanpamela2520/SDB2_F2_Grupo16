-- creación de base de datos
CREATE DATABASE IF NOT EXISTS imdb_fase1;
USE imdb_fase1;

-- tabla personas
CREATE TABLE IF NOT EXISTS personas (
    id_persona INT PRIMARY KEY,
    id_nombre VARCHAR(100) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    ahno_nacimiento YEAR NOT NULL,
    ahno_muerte YEAR NOT NULL
);

-- tabla profesiones
CREATE TABLE IF NOT EXISTS profesiones (
    id_profesion INT PRIMARY KEY,
    profesion VARCHAR(60) NOT NULL
);

-- tabla top_profesiones
CREATE TABLE IF NOT EXISTS top_profesiones (
    id_persona INT NOT NULL,
    id_profesion INT NOT NULL,
    ordinal INT NOT NULL,
    CONSTRAINT pk_top_profesiones PRIMARY KEY (id_profesion, ordinal),
    CONSTRAINT fk_id_persona FOREIGN KEY (id_persona) REFERENCES personas (id_persona),
    CONSTRAINT fk_id_profesion FOREIGN KEY (id_profesion) REFERENCES profesiones (id_profesion)
);

-- tabla nombres_produccion
CREATE TABLE IF NOT EXISTS nombres_produccion (
    id_produccion INT NOT NULL,
    orden INT NOT NULL,
    nombres_produccion VARCHAR(100) NOT NULL,
    region VARCHAR(100) NOT NULL,
    lenguaje VARCHAR(100) NOT NULL,
    esOriginal BOOLEAN NOT NULL,
    CONSTRAINT pk_nombres_produccion PRIMARY KEY (id_produccion, orden)
);

-- tabla atributos
CREATE TABLE IF NOT EXISTS atributos (
    id_atributo INT PRIMARY KEY,
    class VARCHAR(100) NOT NULL,
    atributo VARCHAR(100) NOT NULL
);

-- tabla nombres_titulos_atributos
CREATE TABLE IF NOT EXISTS nombres_titulos_atributos (
    id_titulo INT NOT NULL,
    orden INT NOT NULL,
    id_atributo INT NOT NULL,
    CONSTRAINT pk_nombres_titulos_atributos PRIMARY KEY (id_titulo, orden),
    CONSTRAINT fk_nombresTitulosAtributos_nombres_titulos FOREIGN KEY (id_titulo, orden) REFERENCES nombres_produccion (id_produccion, orden),
    CONSTRAINT fk_nombresTitulosAtributos_atributos FOREIGN KEY (id_atributo) REFERENCES atributos (id_atributo)
);

-- tabla generos
CREATE TABLE IF NOT EXISTS generos (
    id_genero INT PRIMARY KEY,
    genero VARCHAR(100) NOT NULL
);

-- tabla tipo_produccion
CREATE TABLE IF NOT EXISTS tipo_produccion (
    id_tipo_produccion INT PRIMARY KEY,
    tipo_produccion VARCHAR(100) NOT NULL
);


-- tabla genero_produccion

CREATE TABLE if not exists genero_produccion(
    id_genero INT PRIMARY KEY,
    id_produccion int not null
);

-- tabla produccion
CREATE TABLE IF NOT EXISTS produccion (
    id_titulo INT PRIMARY KEY,
    id_tipo_titulo INT NOT NULL,
    adultos BOOLEAN NOT NULL,
    ahno_inicio YEAR NOT NULL,
    ahno_finalizacion YEAR NOT NULL,
    minutos_duracion INT NOT NULL,
    votos INT NOT NULL,
    promedio_rating DECIMAL(4,2) NOT NULL,
    CONSTRAINT fk_id_tipo_titulo FOREIGN KEY (id_tipo_titulo) REFERENCES tipo_produccion (id_tipo_produccion)
);



-- tabla personajes
CREATE TABLE IF NOT EXISTS personajes (
    id_personajes INT PRIMARY KEY AUTO_INCREMENT,
    id_produccion INT NOT NULL,
    persona_id INT NOT NULL,
    personaje VARCHAR(100) NOT NULL,
    CONSTRAINT fk_id_titulo FOREIGN KEY (id_produccion) REFERENCES produccion (id_titulo),
    CONSTRAINT fk_id_persona_personajes FOREIGN KEY (persona_id) REFERENCES personas (id_persona)
);

-- tabla personas_produccion (antes principal titles)
CREATE TABLE IF NOT EXISTS personas_produccion (
    id_produccion INT NOT NULL,
    orden INT NOT NULL,
    id_persona INT NOT NULL,
    id_profesion INT NOT NULL,
    conocido_por INT DEFAULT NULL,
    CONSTRAINT pk_personas_produccion PRIMARY KEY (id_produccion, orden),
    CONSTRAINT fk_pp_id_produccion FOREIGN KEY (id_produccion) REFERENCES produccion (id_titulo),
    CONSTRAINT fk_pp_id_persona FOREIGN KEY (id_persona) REFERENCES personas (id_persona),
    CONSTRAINT fk_pp_id_profesion FOREIGN KEY (id_profesion) REFERENCES profesiones (id_profesion)
);

-- tabla episodios
CREATE TABLE IF NOT EXISTS episodios (
    id_episodio INT PRIMARY KEY,
    id_serie INT NOT NULL,
    temporada INT NOT NULL,
    episodio INT NOT NULL,
    CONSTRAINT fk_episodios_serie FOREIGN KEY (id_serie) REFERENCES produccion (id_titulo),
    CONSTRAINT fk_episodios_episodio FOREIGN KEY (id_episodio) REFERENCES produccion (id_titulo)
);