CREATE DATABASE based_tarea;
USE based_tarea;

CREATE TABLE category (
    id_category INT AUTO_INCREMENT PRIMARY KEY ,
    name VARCHAR(50)
);

CREATE TABLE country (
    id_country INT AUTO_INCREMENT primary key ,
    name VARCHAR(50)
);

CREATE TABLE director (
    id_director INT AUTO_INCREMENT PRIMARY KEY ,
    name VARCHAR(50)
);
CREATE TABLE  actor (
    id_actor INT AUTO_INCREMENT PRIMARY KEY ,
    name VARCHAR(50)
);
CREATE TABLE  show_type(
    id_show_type INT AUTO_INCREMENT PRIMARY KEY ,
    name VARCHAR(50)
);
CREATE TABLE  show_rating (
    id_show_rating INT AUTO_INCREMENT PRIMARY KEY ,
    name VARCHAR(50)
);
CREATE TABLE show_tv(
    id_show INT AUTO_INCREMENT PRIMARY KEY ,
    title VARCHAR(50),
    date_added DATE,
    release_year YEAR,
    duration VARCHAR(20),
    description VARCHAR(70),
    id_category INT,
    id_country INT,
    id_director INT,
    id_show_type INT,
    id_rating INT,
    FOREIGN KEY (id_category) REFERENCES category(id_category),
    FOREIGN KEY (id_country) REFERENCES country(id_country),
    FOREIGN KEY (id_director) REFERENCES director(id_director),
    FOREIGN KEY (id_show_type) REFERENCES show_type(id_show_type),
    FOREIGN KEY (id_rating) REFERENCES show_rating(id_show_rating)


);

CREATE TABLE show_actor(
  id_show_actor  INT AUTO_INCREMENT PRIMARY KEY,
  id_show INT,
  id_actor INT,
  FOREIGN KEY (id_show) REFERENCES show_tv(id_show),
  FOREIGN KEY (id_actor) REFERENCES actor(id_actor)
);
