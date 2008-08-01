CREATE TABLE meals (
       meal_id INTEGER NOT NULL AUTO_INCREMENT PRIMARY KEY,
       name VARCHAR(255) NOT NULL
);

CREATE TABLE groups (
       group_id INTEGER NOT NULL AUTO_INCREMENT PRIMARY KEY,
       street_name varchar(4000) NOT NULL
);
CREATE INDEX idx_street_name ON groups (street_name);

CREATE TABLE people (
       person_id INTEGER NOT NULL AUTO_INCREMENT PRIMARY KEY,
       group_id INTEGER NOT NULL,
       INDEX (group_id),
       name VARCHAR(255) NOT NULL,
       attending BOOLEAN NOT NULL,
       meal INTEGER NULL
);
