-- Copyright (c) 2011, www.linux-tips-and-tricks.de

CREATE DATABASE VENNSQL;

CREATE TABLE TableA (
  id int NOT NULL,
  name varchar(45) NOT NULL,
  nation varchar(45) NOT NULL,
  table char(1) NOT NULL,
  PRIMARY KEY (id)
);

INSERT INTO TableA (id, name, nation, table) VALUES
(1, 'Albert', 'Germany', 'A'),
(2, 'Elizabeth', 'England', 'A'),
(3, 'Paul', 'Spain', 'A'),
(4, 'Julia', 'Denmark', 'A');

CREATE TABLE TableB (
  id int NOT NULL,
  name varchar(45) NOT NULL,
  nation varchar(45) NOT NULL,
  table char(1) NOT NULL,
  PRIMARY KEY (id)
);

INSERT INTO TableB (id, name, nation, table) VALUES
(1, 'Marc', 'China', 'B'),
(2, 'Albert', 'France', 'B'),
(3, 'Peter', 'Japan', 'B'),
(4, 'Paul', 'Poland', 'B');

