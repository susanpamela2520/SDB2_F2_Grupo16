-- ===============================================
-- 1. CATÁLOGOS INDEPENDIENTES (sin FK)
-- ===============================================

CREATE TABLE IF NOT EXISTS profesiones (
    id_profesion INT PRIMARY KEY,
    profesion VARCHAR(100) NOT NULL  -- 🔧 Aumentado de 60 a 100
);

CREATE TABLE IF NOT EXISTS generos (
    id_genero SMALLINT PRIMARY KEY,
    genero VARCHAR(100) NOT NULL
);

CREATE TABLE IF NOT EXISTS tipo_produccion (
    id_tipo_produccion SMALLINT PRIMARY KEY,
    tipo_produccion VARCHAR(100) NOT NULL
);

CREATE TABLE IF NOT EXISTS atributos (
    id_atributo INT PRIMARY KEY,
    class VARCHAR(100) NOT NULL,
    atributo VARCHAR(200) NOT NULL  -- 🔧 Aumentado de 100 a 200
);

-- ===============================================
-- 2. ENTIDADES PRINCIPALES
-- ===============================================

CREATE TABLE IF NOT EXISTS personas (
    id_persona INT PRIMARY KEY,
    nombre VARCHAR(200) NOT NULL,  -- 🔧 Aumentado de 100 a 200
    ahno_nacimiento DATE NULL,
    ahno_muerte DATE NULL
);

CREATE TABLE IF NOT EXISTS produccion (
    id_titulo INT PRIMARY KEY,
    id_tipo_titulo SMALLINT NOT NULL,
    adultos BOOLEAN NOT NULL,
    ahno_inicio DATE NULL,
    ahno_finalizacion DATE NULL,
    minutos_duracion INT NULL,  -- 🔧 CAMBIADO: INTERVAL → INT
    votos INT NULL,
    promedio_rating NUMERIC(4,2) NULL,
    CONSTRAINT fk_tipo_titulo FOREIGN KEY (id_tipo_titulo) REFERENCES tipo_produccion (id_tipo_produccion)
);

-- ===============================================
-- 3. TABLAS DE RELACIÓN (con FK)
-- ===============================================

CREATE TABLE IF NOT EXISTS top_profesiones (
    id_persona INT NOT NULL,
    id_profesion INT NOT NULL,
    ordinal SMALLINT NOT NULL,
    PRIMARY KEY (id_persona, id_profesion),
    FOREIGN KEY (id_persona) REFERENCES personas (id_persona),
    FOREIGN KEY (id_profesion) REFERENCES profesiones (id_profesion)
);

CREATE TABLE IF NOT EXISTS genero_produccion (
    id_produccion INT NOT NULL,
    id_genero SMALLINT NOT NULL,
    PRIMARY KEY (id_produccion, id_genero),
    FOREIGN KEY (id_produccion) REFERENCES produccion (id_titulo),
    FOREIGN KEY (id_genero) REFERENCES generos (id_genero)
);

CREATE TABLE IF NOT EXISTS nombres_produccion (
    id_produccion INT NOT NULL,
    orden INT NOT NULL,
    nombres_produccion VARCHAR(500) NOT NULL,  -- 🔧 Aumentado de 100 a 500
    region VARCHAR(100) NOT NULL,
    lenguaje VARCHAR(100) NOT NULL,
    esOriginal BOOLEAN NOT NULL,
    PRIMARY KEY (id_produccion, orden),
    FOREIGN KEY (id_produccion) REFERENCES produccion (id_titulo)
);

CREATE TABLE IF NOT EXISTS nombres_titulos_atributos (
    id_titulo INT NOT NULL,
    orden INT NOT NULL,
    id_atributo INT NOT NULL,
    PRIMARY KEY (id_titulo, orden, id_atributo),
    FOREIGN KEY (id_titulo, orden) REFERENCES nombres_produccion (id_produccion, orden),
    FOREIGN KEY (id_atributo) REFERENCES atributos (id_atributo)
);

CREATE TABLE IF NOT EXISTS personas_produccion (
    id_produccion INT NOT NULL,
    orden INT NOT NULL,
    id_persona INT NOT NULL,
    id_profesion INT NOT NULL,
    conocido_por INT DEFAULT NULL,
    PRIMARY KEY (id_produccion, orden),
    FOREIGN KEY (id_produccion) REFERENCES produccion (id_titulo),
    FOREIGN KEY (id_persona) REFERENCES personas (id_persona),
    FOREIGN KEY (id_profesion) REFERENCES profesiones (id_profesion)
);

CREATE TABLE IF NOT EXISTS personajes (
    id_personajes SERIAL PRIMARY KEY,
    id_produccion INT NOT NULL,
    persona_id INT NOT NULL,
    personaje VARCHAR(200) NOT NULL,  -- 🔧 Aumentado de 100 a 200
    FOREIGN KEY (id_produccion) REFERENCES produccion (id_titulo),
    FOREIGN KEY (persona_id) REFERENCES personas (id_persona)
);

CREATE TABLE IF NOT EXISTS episodios (
    id_episodio INT PRIMARY KEY,
    id_serie INT NOT NULL,
    temporada INT NULL,      -- 🔧 CAMBIADO: NOT NULL → NULL
    episodio INT NULL,       -- 🔧 CAMBIADO: NOT NULL → NULL
    FOREIGN KEY (id_serie) REFERENCES produccion (id_titulo),
    FOREIGN KEY (id_episodio) REFERENCES produccion (id_titulo)
);

-- ===============================================
-- 4. CONFIGURACIÓN PARA REPLICACIÓN LÓGICA
-- ===============================================

ALTER TABLE profesiones REPLICA IDENTITY FULL;
ALTER TABLE generos REPLICA IDENTITY FULL;
ALTER TABLE tipo_produccion REPLICA IDENTITY FULL;
ALTER TABLE atributos REPLICA IDENTITY FULL;
ALTER TABLE personas REPLICA IDENTITY FULL;
ALTER TABLE produccion REPLICA IDENTITY FULL;
ALTER TABLE top_profesiones REPLICA IDENTITY FULL;
ALTER TABLE genero_produccion REPLICA IDENTITY FULL;
ALTER TABLE nombres_produccion REPLICA IDENTITY FULL;
ALTER TABLE nombres_titulos_atributos REPLICA IDENTITY FULL;
ALTER TABLE personas_produccion REPLICA IDENTITY FULL;
ALTER TABLE personajes REPLICA IDENTITY FULL;
ALTER TABLE episodios REPLICA IDENTITY FULL;