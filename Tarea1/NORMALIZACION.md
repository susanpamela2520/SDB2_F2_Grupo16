*Universidad de San Carlos de Guatemala*  
*Facultad de Ingenieria*  
*Escuela de Ciencias y Sistemas*  
*Bases de Datos 2*  
*Segundo Semestre 2025*  
___
**202202481 - JOSUÉ NABÍ HURTARTE PINTO**  
**2202001814 - NAOMI RASHEL YOS CUJCUJ**  
**201612218 - SUSAN PAMELA HERRERA MONZON**  


show_id,type,title,director,cast,country,date_added,release_year,rating,duration,listed_in,description

## Entidades

* category

|Field|Data Type|
|-|-|
|id_category `PK`|INT|
|name|VARCHAR|

Se realizo una tabla de categoria, porque se repetian algunos datos en este aspecto por eso era conveniente crear una tabla a la que se hiciera referencia desde la tabla de show. 

* country

|Field|Data Type|
|-|-|
|id_country `PK`|INT|
|name|VARCHAR|

Se realizo una tabla de paises, porque se repetian algunos datos en este aspecto por eso era conveniente crear una tabla a la que se hiciera referencia desde la tabla de show. 

* director

|Field|Data Type|
|-|-|
|id_director `PK`|INT|
|name|VARCHAR|

Se realizo una tabla de director, porque el director pudo haber dirigido una o mas peliculas por eso era conveniente crear una tabla a la que se hiciera referencia desde la tabla de show. 

* actor

|Field|Data Type|
|-|-|
|id_actor `PK`|INT|
|name|VARCHAR|

Se realizo una tabla de actor, porque el actor pudo haber actuado en una o mas peliculas por eso era conveniente crear una tabla a la que se hiciera referencia desde la tabla de show_actor. 

* show_type

|Field|Data Type|
|-|-|
|id_show_type `PK`|INT|
|name|VARCHAR|

Se realizo una tabla de tipo, porque se repetian algunos datos en este aspecto por eso era conveniente crear una tabla a la que se hiciera referencia desde la tabla de show. 

* show_rating

|Field|Data Type|
|-|-|
|id_rating `PK`|INT|
|name|VARCHAR|

Se realizo una tabla de raiting, porque se repetian algunos datos en este aspecto por eso era conveniente crear una tabla a la que se hiciera referencia desde la tabla de show. 

* show

|Field|Data Type|
|-|-|
|id_show `PK`|INT|
|title|VARCHAR|
|date_added|DATE|
|release_year|DATE|
|duration|VARCHAR|
|description|VARCHAR|
|id_category `FK`|INT|
|id_country `FK`|INT|
|id_director `FK`|INT|
|id_show_type `FK`|INT|
|id_rating `FK`|INT|

Es la entidad principal, en esta se hace referencia a las tablas anteriormente descritas mediante sus llaves foraneas.

* show_actor

|Field|Data Type|
|-|-|
|id_show_actor `PK`|INT|
|id_show `FK`|INT|
|id_actor `FK`|INT|

Se realizo una tabla de show_actor, porque ademas de que el actor pudo haber actuado en una o mas peliculas tambien en una pelicual pudieron actuar uno o mas actores por eso era conveniente crear una tabla a la que se hiciera referencia la tabla de show y actor. 