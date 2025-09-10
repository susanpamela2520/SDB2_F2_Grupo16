DELIMITER //

CREATE PROCEDURE AgregarActorReparto (
    IN actorname VARCHAR(255),
    IN showname VARCHAR(255)
)
BEGIN
    DECLARE v_id_show INT DEFAULT NULL;
    DECLARE v_id_actor INT DEFAULT NULL;
    DECLARE v_existente INT DEFAULT 0;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_id_actor = NULL;

    -- Etiqueta para el bloque principal
    main_block: BEGIN

        -- 1. Buscar show por título
        SELECT id_show INTO v_id_show
        FROM show_tv
        WHERE title = showname
        LIMIT 1;

        IF v_id_show IS NULL THEN
            SELECT CONCAT('El show "', showname, '" no existe.') AS mensaje;
            LEAVE main_block;
        END IF;

        -- 2. Buscar actor
        SET v_id_actor = NULL;
        SELECT id_actor INTO v_id_actor
        FROM actor
        WHERE name = actorname
        LIMIT 1;

        -- 3. Insertar actor si no existe
        IF v_id_actor IS NULL THEN
            INSERT INTO actor (name) VALUES (actorname);
            SET v_id_actor = LAST_INSERT_ID();
        END IF;

        -- 4. Verificar si ya existe relación actor-show
        SELECT COUNT(*) INTO v_existente
        FROM show_actor
        WHERE id_show = v_id_show AND id_actor = v_id_actor;

        IF v_existente > 0 THEN
            SELECT CONCAT('El actor "', actorname, '" ya está asignado al show "', showname, '".') AS mensaje;
        ELSE
            INSERT INTO show_actor (id_show, id_actor)
            VALUES (v_id_show, v_id_actor);

            SELECT CONCAT('El actor "', actorname, '" fue agregado al reparto del show "', showname, '".') AS mensaje;
        END IF;

    END main_block;
END //

-- Agregar Show--

CREATE PROCEDURE AgregarDirector (
    IN title VARCHAR(255),
    IN directorName VARCHAR(255)
)
BEGIN
    DECLARE v_id_show INT DEFAULT NULL;
    DECLARE v_id_director INT DEFAULT NULL;

    etiqueta: BEGIN
        SELECT id_show INTO v_id_show
        FROM show_tv
        WHERE title = title
        LIMIT 1;

        IF v_id_show IS NULL THEN
            SELECT CONCAT('La película "', title, '" no existe.') AS mensaje;
            LEAVE etiqueta;
        END IF;

        SELECT id_director INTO v_id_director
        FROM director
        WHERE name = directorName
        LIMIT 1;

        IF v_id_director IS NULL THEN
            INSERT INTO director (name) VALUES (directorName);
            SET v_id_director = LAST_INSERT_ID();
        END IF;

        UPDATE show_tv
        SET id_director = v_id_director
        WHERE id_show = v_id_show;

        SELECT CONCAT('Director "', directorName, '" asignado a la película "', title, '".') AS mensaje;
    END etiqueta;
END //

--- Agregar director a la pelicula ---
DELIMITER //

CREATE PROCEDURE AgregarShowTv (
    IN p_title VARCHAR(255), 
    IN p_timeShow VARCHAR(50), 
    IN p_descriptionshow TEXT, 
    IN p_categoryName VARCHAR(100),
    IN p_countryName VARCHAR(100),
    IN p_showType VARCHAR(50),
    IN p_showRating VARCHAR(10)
)
BEGIN
    DECLARE v_id_category INT DEFAULT NULL;
    DECLARE v_id_country INT DEFAULT NULL;
    DECLARE v_id_show_type INT DEFAULT NULL;
    DECLARE v_id_rating INT DEFAULT NULL;
    DECLARE v_show_id VARCHAR(10);

    -- 1. Buscar o insertar categoría
    SELECT id_category INTO v_id_category
    FROM category WHERE name = p_categoryName;

    IF v_id_category IS NULL THEN
        INSERT INTO category(name) VALUES (p_categoryName);
        SET v_id_category = LAST_INSERT_ID();
    END IF;

    -- 2. Buscar o insertar país
    SELECT id_country INTO v_id_country
    FROM country WHERE name = p_countryName;

    IF v_id_country IS NULL THEN
        INSERT INTO country(name) VALUES (p_countryName);
        SET v_id_country = LAST_INSERT_ID();
    END IF;

    -- 3. Buscar o insertar tipo de show
    SELECT id_show_type INTO v_id_show_type
    FROM show_type WHERE name = p_showType;

    IF v_id_show_type IS NULL THEN
        INSERT INTO show_type(name) VALUES (p_showType);
        SET v_id_show_type = LAST_INSERT_ID();
    END IF;

    -- 4. Buscar rating (no se inserta si no existe)
    SELECT id_rating INTO v_id_rating
    FROM show_rating WHERE name = p_showRating;

    -- 5. Generar show_id único (S00001, S00002, ...)
    SELECT CONCAT('S', LPAD(IFNULL(MAX(id_show), 0) + 1, 5, '0'))
    INTO v_show_id
    FROM show_tv;

    -- 6. Insertar el nuevo show
    INSERT INTO show_tv (
        show_id, title, duration, description,
        id_category, id_country, id_show_type, id_rating
    )
    VALUES (
        v_show_id, p_title, p_timeShow, p_descriptionshow,
        v_id_category, v_id_country, v_id_show_type, v_id_rating
    );

    SELECT CONCAT('Show "', p_title, '" agregado con show_id "', v_show_id, '".') AS mensaje;
END //

DELIMITER ;

DELIMITER //

CREATE PROCEDURE AgregarCategoria (

    IN nombre VARCHAR(100)
    
)BEGIN

    IF NOT EXISTS (
        SELECT 1 FROM category WHERE name = nombre
    )THEN
        INSERT INTO category (name)
        VALUES(nombre);
        SELECT CONCAT ('La categoria "', nombre, '" fue insertada existosamente') AS MENSAJE;
    ELSE
        SELECT CONCAT ('La categoria "', nombre, '" ya existe') AS ERROR;
    END IF;

END //

CALL AgregarShowTv(
    'Breaking Bad',
    '5 Seasons',
    'A chemistry teacher turned meth kingpin.',
    'Drama',
    'United States',
    'TV Show',
    'TV-MA'
);
CALL AgregarCategoria('Drama');
CALL AgregarDirector('Breaking Bad', 'Vince Gilligan');
CALL AgregarActorReparto('Bryan Cranston', 'Breaking Bad');