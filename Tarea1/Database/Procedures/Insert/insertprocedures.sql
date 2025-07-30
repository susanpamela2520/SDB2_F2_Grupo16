Delimiter // 

--Agregar Actor al repart--

CREATE PROCEDURE AgregarActorReparto (
    IN actorname VARCHAR (255),
    IN showname VARCHAR(255)
) BEGIN

END //


--Agregar Show--

CREATE PROCEDURE AgregarShowTv (
    IN title VARCHAR(255), 
    IN timeShow VARCHAR(50), 
    IN descriptionshow TEXT, 
    IN categoryName VARCHAR(100),
    IN countryName VARCHAR(100),
    IN showType VARCHAR(50),
    IN showRaiting VARCHAR(10)

)BEGIN

END //

--- Agregar director a la pelicula ---

CREATE PROCEDURE AgregarDirector (

    IN title VARCHAR(255),
    IN directorName VARCHAR (255),

)BEGIN

END //

--- Agregar categorias ---

CREATE PROCEDURE AgregarCategoria (

    IN nombre VARCHAR(100)
    
)BEGIN

END //


Delimiter;
