DROP PROCEDURE IF EXISTS buscar_produccion;
DELIMITER //
CREATE PROCEDURE buscar_produccion(IN p_id INT, IN p_nombre VARCHAR(100))
BEGIN
    /* Validación de entrada */
    IF p_id IS NULL AND (p_nombre IS NULL OR LENGTH(TRIM(p_nombre)) = 0) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Debe proporcionar p_id o p_nombre';
    END IF;

    /* Candidatos: materializamos los ids que participan en la consulta */
    DROP TEMPORARY TABLE IF EXISTS tmp_ids;
    CREATE TEMPORARY TABLE tmp_ids (
        id INT PRIMARY KEY,
        matched_nombre VARCHAR(100) NULL,
        matched_orden INT NULL
    ) ENGINE=InnoDB;

    IF p_nombre IS NOT NULL AND LENGTH(TRIM(p_nombre)) > 0 THEN
        IF p_id IS NOT NULL THEN
            /* Ambos: ese ID debe tener EXACTAMENTE ese nombre */
            INSERT INTO tmp_ids(id, matched_nombre, matched_orden)
            SELECT np.id_produccion, TRIM(p_nombre), MIN(np.orden)
            FROM nombres_produccion np
            WHERE np.id_produccion = p_id
              AND (np.nombres_produccion COLLATE utf8mb4_0900_ai_ci)
                    = TRIM(p_nombre) COLLATE utf8mb4_0900_ai_ci
            GROUP BY np.id_produccion;
        ELSE
            /* Solo nombre: todos los IDs que tienen EXACTAMENTE ese nombre */
            INSERT INTO tmp_ids(id, matched_nombre, matched_orden)
            SELECT np.id_produccion, TRIM(p_nombre), MIN(np.orden)
            FROM nombres_produccion np
            WHERE (np.nombres_produccion COLLATE utf8mb4_0900_ai_ci)
                    = TRIM(p_nombre) COLLATE utf8mb4_0900_ai_ci
            GROUP BY np.id_produccion;
        END IF;
    ELSE
        /* Solo ID */
        INSERT INTO tmp_ids(id) VALUES (p_id);
    END IF;

    /* Nombre canónico de respaldo (para búsqueda por ID, u otra si no hay matched_nombre) */
    DROP TEMPORARY TABLE IF EXISTS best_name;
    CREATE TEMPORARY TABLE best_name (
        id INT PRIMARY KEY,
        best_name VARCHAR(100),
        best_orden INT
    ) ENGINE=InnoDB;

    INSERT INTO best_name (id, best_name, best_orden)
    SELECT np1.id_produccion, np1.nombres_produccion, np1.orden
    FROM nombres_produccion np1
    JOIN (
        SELECT
            id_produccion,
            MIN(CASE WHEN esOriginal = 1 THEN orden END) AS min_ord_original,
            MIN(orden) AS min_orden
        FROM nombres_produccion
        WHERE id_produccion IN (SELECT id FROM tmp_ids)
        GROUP BY id_produccion
    ) pk ON pk.id_produccion = np1.id_produccion
    WHERE (np1.esOriginal = 1 AND np1.orden = pk.min_ord_original)
       OR (pk.min_ord_original IS NULL AND np1.orden = pk.min_orden);

    /* Resultado final:
       - nombre: exacto si se buscó por nombre; si no, canónico.
       - tambien_conocido_como: SOLO otros nombres del MISMO id_produccion. */
    SELECT
        p.id_titulo                                     AS id_produccion,
        COALESCE(t.matched_nombre, bn.best_name)        AS nombre,
        tp.tipo_produccion                              AS tipo,
        p.minutos_duracion                               AS duracion,
        CASE
            WHEN p.minutos_duracion IS NULL THEN NULL
            ELSE TIME_TO_SEC(p.minutos_duracion)/60
        END                                             AS minutos_de_duracion,
        p.promedio_rating,
        p.adultos                                       AS adulto,
        (
            SELECT GROUP_CONCAT(DISTINCT np2.nombres_produccion
                                 ORDER BY np2.orden
                                 SEPARATOR ' | ')
            FROM nombres_produccion np2
            WHERE np2.id_produccion = p.id_titulo
              AND (np2.nombres_produccion COLLATE utf8mb4_0900_ai_ci)
                    <> COALESCE(t.matched_nombre, bn.best_name) COLLATE utf8mb4_0900_ai_ci
        )                                               AS tambien_conocido_como
    FROM produccion p
    JOIN tmp_ids t           ON t.id = p.id_titulo
    JOIN tipo_produccion tp  ON tp.id_tipo_produccion = p.id_tipo_titulo
    LEFT JOIN best_name bn   ON bn.id = p.id_titulo
    ORDER BY COALESCE(t.matched_orden, bn.best_orden), p.id_titulo;

  
END //
DELIMITER ;
CALL buscar_produccion(NULL, 'A Dip in the Sea');