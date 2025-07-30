DELIMITER //

-- Eliminar un show por su id
CREATE PROCEDURE EliminarShow (
    IN p_id_show INT
)
BEGIN
    DELETE FROM show_tv 
    WHERE id_show = p_id_show;
END //

-- Eliminar un actor por su id
CREATE PROCEDURE EliminarActor (
    IN p_id_actor INT
)
BEGIN
    DELETE FROM actor 
    WHERE id_actor = p_id_actor;
END //

-- Eliminar una categoría por su id
CREATE PROCEDURE EliminarCategoria (
    IN p_id_category INT
)
BEGIN
    DELETE FROM category 
    WHERE id_category = p_id_category;
END //

-- Eliminar un director por su id
CREATE PROCEDURE EliminarDirector (
    IN p_id_director INT
)
BEGIN
    DELETE FROM director 
    WHERE id_director = p_id_director;
END //

DELIMITER ;


CALL EliminarShow(1); 
CALL EliminarActor(5);
CALL EliminarCategoria(3);
CALL EliminarDirector(2);