
DELIMITER //

CREATE PROCEDURE actualizar_rating(
    IN p_id_rating INT,
    IN p_name VARCHAR(10)
)
BEGIN
    UPDATE show_rating
    SET name = p_name
    WHERE id_rating = p_id_rating;
END //

DELIMITER ;

DELIMITER //
CREATE PROCEDURE actualizar_titulo_show(
    IN p_id_show INT,
    IN p_nuevo_titulo VARCHAR(255)
)
BEGIN
    UPDATE show_tv
    SET title = p_nuevo_titulo
    WHERE id_show = p_id_show;
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE cambiar_categoria_show(
    IN p_id_show INT,
    IN p_id_nueva_categoria INT
)
BEGIN
    UPDATE show_tv
    SET id_category = p_id_nueva_categoria
    WHERE id_show = p_id_show;
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE actualizar_nombre_actor(
    IN p_id_actor INT,
    IN p_nuevo_nombre VARCHAR(255)
)
BEGIN
    UPDATE actor
    SET name = p_nuevo_nombre
    WHERE id_actor = p_id_actor;
END //
DELIMITER ;

CALL actualizar_titulo_show(1, 'Dick Johnson Is Alive');
CALL cambiar_categoria_show(2, 6);
CALL actualizar_nombre_actor(5, 'Amy Qamata');
CALL actualizar_rating(1, 'GA');