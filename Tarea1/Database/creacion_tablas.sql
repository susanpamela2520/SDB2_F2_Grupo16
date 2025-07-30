CREATE DATABASE based_tarea;
USE based_tarea;

CREATE TABLE category (
    id_category INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE country (
    id_country INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE director (
    id_director INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_director_name (name)
);
CREATE TABLE  actor (
    id_actor INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_actor_name (name)
);
CREATE TABLE  show_type(
    id_show_type INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE  show_rating (
    id_rating INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(10) NOT NULL UNIQUE,
    description VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE show_tv(
    id_show INT AUTO_INCREMENT PRIMARY KEY,
    show_id VARCHAR(10) NOT NULL UNIQUE,
    title VARCHAR(255) NOT NULL,
    date_added DATE,
    release_year INT,
    duration VARCHAR(50),
    description TEXT,
    id_category INT,
    id_country INT,
    id_director INT,
    id_show_type INT NOT NULL,
    id_rating INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (id_category) REFERENCES category (id_category) ON DELETE SET NULL,
    FOREIGN KEY (id_country) REFERENCES country (id_country) ON DELETE SET NULL,
    FOREIGN KEY (id_director) REFERENCES director (id_director) ON DELETE SET NULL,
    FOREIGN KEY (id_show_type) REFERENCES show_type (id_show_type) ON DELETE RESTRICT,
    FOREIGN KEY (id_rating) REFERENCES show_rating (id_rating) ON DELETE SET NULL,
    INDEX idx_show_id (show_id),
    INDEX idx_title (title),
    INDEX idx_release_year (release_year)
);

CREATE TABLE show_actor(
    id_content_actor INT AUTO_INCREMENT PRIMARY KEY,
    id_show INT NOT NULL,
    id_actor INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_show) REFERENCES show_tv (id_show) ON DELETE CASCADE,
    FOREIGN KEY (id_actor) REFERENCES actor (id_actor) ON DELETE CASCADE,
    UNIQUE KEY unique_content_actor (id_show, id_actor),
    INDEX idx_show (id_show),
    INDEX idx_actor (id_actor)
);
