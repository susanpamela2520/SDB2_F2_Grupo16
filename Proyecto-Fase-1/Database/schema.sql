-- creación de base de datos
CREATE DATABASE IF NOT EXISTS imdb_fase1;
USE imdb_fase1;

-- ===============================================
-- 1. CATÁLOGOS INDEPENDIENTES (sin FK)
-- ===============================================

-- tabla profesiones
CREATE TABLE IF NOT EXISTS profesiones (
    id_profesion INT PRIMARY KEY,
    profesion VARCHAR(60) NOT NULL
);

-- tabla generos
CREATE TABLE IF NOT EXISTS generos (
    id_genero SMALLINT PRIMARY KEY,  -- CAMBIADO A SMALLINT
    genero VARCHAR(100) NOT NULL
);

-- tabla tipo_produccion
CREATE TABLE IF NOT EXISTS tipo_produccion (
    id_tipo_produccion TINYINT PRIMARY KEY,  -- CAMBIADO A TINYINT
    tipo_produccion VARCHAR(100) NOT NULL
);

-- tabla atributos
CREATE TABLE IF NOT EXISTS atributos (
    id_atributo INT PRIMARY KEY,
    class VARCHAR(100) NOT NULL,
    atributo VARCHAR(100) NOT NULL
);

-- ===============================================
-- 2. ENTIDADES PRINCIPALES
-- ===============================================

-- tabla personas
CREATE TABLE IF NOT EXISTS personas (
    id_persona INT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    ahno_nacimiento DATE NULL,
    ahno_muerte DATE NULL
);

-- tabla produccion
CREATE TABLE IF NOT EXISTS produccion (
    id_titulo INT PRIMARY KEY,
    id_tipo_titulo TINYINT NOT NULL,
    adultos BOOLEAN NOT NULL,
    ahno_inicio DATE NULL,
    ahno_finalizacion DATE NULL,
    minutos_duracion TIME(0) NULL,
    votos INT NULL,
    promedio_rating DECIMAL(4,2) NULL,
    CONSTRAINT fk_tipo_titulo FOREIGN KEY (id_tipo_titulo) REFERENCES tipo_produccion (id_tipo_produccion)
);

-- ===============================================
-- 3. TABLAS DE RELACIÓN (con FK)
-- ===============================================

-- tabla top_profesiones
CREATE TABLE IF NOT EXISTS top_profesiones (
    id_persona INT NOT NULL,
    id_profesion INT NOT NULL,
    ordinal TINYINT NOT NULL,
    CONSTRAINT pk_top_profesiones PRIMARY KEY (id_persona, id_profesion),
    CONSTRAINT fk_tp_persona FOREIGN KEY (id_persona) REFERENCES personas (id_persona),
    CONSTRAINT fk_tp_profesion FOREIGN KEY (id_profesion) REFERENCES profesiones (id_profesion)
);

-- tabla genero_produccion
CREATE TABLE IF NOT EXISTS genero_produccion (
    id_produccion INT NOT NULL,
    id_genero SMALLINT NOT NULL,  -- SMALLINT para coincidir con generos
    CONSTRAINT pk_genero_produccion PRIMARY KEY (id_produccion, id_genero),
    CONSTRAINT fk_gp_produccion FOREIGN KEY (id_produccion) REFERENCES produccion (id_titulo),
    CONSTRAINT fk_gp_genero FOREIGN KEY (id_genero) REFERENCES generos (id_genero)
);

-- tabla nombres_produccion
CREATE TABLE IF NOT EXISTS nombres_produccion (
    id_produccion INT NOT NULL,
    orden INT NOT NULL,
    nombres_produccion VARCHAR(100) NOT NULL,
    region VARCHAR(100) NOT NULL,
    lenguaje VARCHAR(100) NOT NULL,
    esOriginal BOOLEAN NOT NULL,
    CONSTRAINT pk_nombres_produccion PRIMARY KEY (id_produccion, orden),
    CONSTRAINT fk_np_produccion FOREIGN KEY (id_produccion) REFERENCES produccion (id_titulo)
);

-- tabla nombres_titulos_atributos
CREATE TABLE IF NOT EXISTS nombres_titulos_atributos (
    id_titulo INT NOT NULL,
    orden INT NOT NULL,
    id_atributo INT NOT NULL,
    CONSTRAINT pk_nombres_titulos_atributos PRIMARY KEY (id_titulo, orden, id_atributo),  -- CORREGIDA PK
    CONSTRAINT fk_nombresTitulosAtributos_nombres_titulos FOREIGN KEY (id_titulo, orden) REFERENCES nombres_produccion (id_produccion, orden),
    CONSTRAINT fk_nombresTitulosAtributos_atributos FOREIGN KEY (id_atributo) REFERENCES atributos (id_atributo)
);

-- tabla personas_produccion
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

-- tabla personajes
CREATE TABLE IF NOT EXISTS personajes (
    id_personajes INT PRIMARY KEY AUTO_INCREMENT,
    id_produccion INT NOT NULL,
    persona_id INT NOT NULL,
    personaje VARCHAR(100) NOT NULL,
    CONSTRAINT fk_personajes_titulo FOREIGN KEY (id_produccion) REFERENCES produccion (id_titulo),
    CONSTRAINT fk_personajes_persona FOREIGN KEY (persona_id) REFERENCES personas (id_persona)
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