-- List of sql statements as samples to understand sql statements better
-- Liste von sql Beispielbefehlen die helfen sql besser zu verstehen
-- (C) 2011, www.linux-tips-and-tricks.de

--
-- First line of SQL statement description is in English
-- Zweite Zeile der SQL Befehlsbeschreibung ist in Deutsch
--

--
-- Sample DB is a simplificated model of facebook
-- Beispielsdatenbank ist eine vereinfachte Modelierung von Facebook
--

-- select sample database
-- Auswahl der Beispielsdatenbank
use frampSQLByExample;

-- *******************
-- Simple queries
-- Einfache Queries
-- *******************

-- Query persons
-- Abfrage nach allen Personen
select * from Person;

-- Query Sibling
-- Abfrage nach Geschwistern
select * from Sibling;

-- Query City
-- Abfrage nach Stadt
select * from City;

-- Query address
-- Abfrage nach Adresse
select * from Address;

-- Query message
-- Abfrage nach Messages
select * from Message;

-- Query Friend
-- Abfrage nach allen Freunden
select * from Friend;

-- Select some columns from the table of all persons
-- Anzeige von bestimmten Spalten alle Personen
select LastName, Firstname from Person;

-- Query persons and sort by firstname
-- Abfrage aller Personen sortiert nach Vorname
select LastName, FirstName from Person order by FirstName;

-- Query persons and sort by lastname and firstname
-- Abfrage aller Personen sortiert nach Nachnamen und Vornamen
select LastName, FirstName from Person order by LastName, FirstName;

-- Query persons and sort by lastname descending and firstname ascending
-- Abfrage aller Personen sortiert nach Nachnamen abfallend und Vornamen abfallend
select LastName, FirstName from Person order by LastName desc, FirstName asc;

-- Select only persons with a given LastName
-- Abfrage nach Personen die einen bestimmten Nachnamen haben
select LastName, Firstname from Person
	where LastName = 'Turner';

-- Select some columns from the table and give the column names German descriptions
-- Abfrage der Personen wobei bestimmte Spalten deutsche Überschriften bekommen
select LastName as Nachname, Firstname as Vorname from Person;

-- *******************
-- NULL values
-- NULL Werte
-- *******************

-- NULL values are NOT identical
-- NULL Werte sind NICHT gleich
select NULL = NULL;

-- NULL values are identical if special operator <=> is used
-- NULL Werte sind gleich wenn der spezielle Operator <=> benutzt wird
select NULL <=> NULL;

-- tests for NULL equality
-- Tests auf NULL Gleichheit
select NULL is null,NULL is not null;

-- count(*) counts all rows whereas count(columnName) counts rows which don't have NULL in the column
-- count(*) zählt alle Zeilen einer Tabelle während count(SpaltenName) nur Zeilen zählt, die kein NULL in der Spalte haben
select count(*) as 'Total # of Persons', count(Father_Id) as 'Person has father' from Person;

-- Select persons which don't have a known father
-- Auswahl der Personen, für die kein Vater bekannt ist
select LastName, FirstName from Person
	where Father_Id is null;

-- Select persons which know their father
-- Auswahl der Personen, die ihren Vater kennen
select LastName, FirstName from Person
	where Father_Id is not null;

-- Select persons which down't know both parents
-- Auswahl der Personen, die nicht beide Eltern kennen
select LastName, FirstName from Person
	where (Father_Id is not null
		and Mother_Id is null)
	or
		(Father_Id is null
		and Mother_Id is not null);

-- NULL does not match any like statement
-- NULL wird niemals bei einem like Vergleich gefunden
select NULL like '%', NULL not like '%';
select 'art' like 'a%', 'art' not like '%';

-- *******************
-- views to simplify queries
-- views um Abfragen zu vereinfachen
-- *******************

-- Create view which returns persons which have a father only
-- Erstellung einer view die nur Personen liefert, die nur einen Vater haben
create or replace view motherOnly as
	select LastName, FirstName from Person
		where (Father_Id is not null
			and Mother_Id is null);

-- Create view which returns persons which have a mother only
-- Erstellung einer view die nur Personen liefert, die nur eine Mutter haben
create or replace view fatherOnly as
	select LastName, FirstName from Person
		where (Father_Id is null
			and Mother_Id is not null);

-- Select persons which either know father or mother
-- Auswahl der Personen, die entweder den Vater oder die Mutter kennen
select * from fatherOnly
union
select * from motherOnly;

-- *******************
-- group queries
-- Gruppen Abfragen
-- *******************

-- Count number of women and men with the same lastname
-- Abfrage der Anzahl von Frauen und Männern mit demselben Nachnamen
select LastName, Gender, count(*) as Count from Person
	group by LastName,Gender;

-- Count number of persons with a given name and give the result column another name
-- Abfrage der Anzahl von Leuten mit einem bestimmten Nachnamen
select count(*) as 'Number of people' from Person
	where LastName = 'Turner';

-- Count number of men an women
-- Abfrage der Anzahl von Frauen und Männern
select Gender,count(*) as 'Number of people' from Person
	group by Gender;
-- Count number of men an women and give gender a better name
-- Abfrage der Anzahl von Frauen und Männern und Ändern der Spaltenüberschriften
select If(Gender = 'M',"Men","Woman") as Gender ,count(*) as 'Number of people' from Person
	group by Gender;

-- Show women and men which with the same lastname if there are more than 2
-- Abfrage der Anzahl von Frauen und Männern mit demselben Nachnamen sofern es mehr als 2 sind
select LastName, Gender, count(*) as Count from Person
	group by LastName,Gender
	having count(*) > 2;

-- *******************
-- calculations
-- Berechnungen
-- *******************

-- Show height of persons
-- Abfrage der Größe der Personen
select LastName, FirstName, height as Avg from Person
	order by height;

-- Show smallest person
-- Abfrage der kleinsten Person
select LastName, FirstName, height as Avg from Person
	order by height
	limit 1;

-- Show biggest person
-- Abfrage der größten Person
select LastName, FirstName, height as Avg from Person
	order by height desc
	limit 1;

-- Count min, max, avg of height of persons
-- Abfrage der minimalen, maximalen und mittleren Größe der Personen
select Min(height) as Min, Max(height) as Max, Avg(height) as Avg from Person;

-- Select person with the maximum and minimum height
-- Abfrage der kleinsten und größten Person
select LastName, FirstName, Height from Person
	where height = (select max(height) from Person)
		or height = (select min(height) from Person);

-- Select persons with a height above average
-- Abfrage der Personen, die Größer als das Mittelmass sind
set @avg = (select Avg(height) from Person);
select LastName, FirstName, Height as Avg from Person
	where Height > @avg
	order by height desc;

-- or
-- oder
select LastName, FirstName, Height as Avg from Person
	where Height > (select avg(height) from Person)
	order by height desc;

-- *******************
-- Joins
-- Zusammenfassungen
-- *******************

-- Query parents of persons
-- Abfrage der Eltern von Personen
select p1.FirstName,p2.LastName as ParentLastName,
		p2.FirstName as ParentFirstName
	from Person as p1
		inner join Person as p2
	on (p1.Father_Id = p2.id or p1.Mother_Id = p2.id);

-- Query which persons are parents and remove duplicates
-- Abfrage welche Personen Eltern sind und Entfernung von doppelten Zeilen
select distinct p2.LastName as ParentLastName,
		p2.FirstName as ParentFirstName
	from Person as p1
		inner join Person as p2
	on (p1.Father_Id = p2.id or p1.Mother_Id = p2.id);

-- Query sibling of a person
-- Abfrage der Geschwister einer Person
select p1.LastName, p1.FirstName
	from Person as p1
		inner join Sibling as s
		inner join Person as p2
	on p1.id = s.from_Id and s.to_Id = p2.id
		and p1.FirstName != 'Marvin';

-- Query message send by one person
-- Abfrage der Meldungen, die von einer Person geschickt wurden
select p1.FirstName as 'From',
		p2.FirstName as 'To',
		m.message
	from Person as p1
		inner join Message as m
		inner join Person as p2
	on p1.id = m.from_Id
		and m.to_Id = p2.id
	where (select id from Person where FirstName = 'Marvin');

-- Query messages replied to one person
-- Abfrage der Meldungen, die an eine Person geschickt wurden
select p2.FirstName as 'From',
		p1.FirstName as 'To',
		m.message
	from Person as p1
		inner join Message as m
		inner join Person as p2
	on p1.id = m.to_Id
		and m.from_Id = p2.id
	where (select id from Person where FirstName = 'Marvin');

-- Query messages sent and replied from one person
-- Abfrage der Meldungen, die von einer Person geschickt und gesendet wurden
select p1.FirstName,
		If(m.from_Id = p1.id,'Sent to','Received from') 'S/R',
		p2.Firstname,
		m.message
	from Person as p1
		inner join Message as m
		inner join Person as p2
	on p1.id = m.to_Id
		and m.from_Id = p2.id
		or p2.id = m.to_Id
		and m.from_Id = p1.id
	where (select id from Person where FirstName = 'Marvin')
	order by p1.LastName, p1.FirstName;

-- Query number of messages sent and replied from all persons
-- Abfrage der Anzahl von Meldungen, die von allen Personen gesendet oder empfangen wurden
select p1.FirstName,
		If(m.from_Id = p1.id,'Sent','Received') 'S/R',
		count(*) as 'Messages'
	from Person as p1
		inner join Message as m
		inner join Person as p2
	on p1.id = m.to_Id
		and m.from_Id = p2.id
		or p2.id = m.to_Id
		and m.from_Id = p1.id
	group by p1.FirstName,p1.LastName,m.from_Id = p1.id
	order by p1.LastName, p1.FirstName;

-- Query persons with their full address
-- Abfrage der Personen mit ihrer vollständigen Adresse
select LastName, FirstName, c.Name, c.ZIP, a.Street, a.No
	from Person as p
		inner join City as c
		inner join Address as a
	on p.Address_Id = a.id and a.City_Id = c.id
	order by LastName, FirstName;

-- Query siblings which have the same friends
-- Abfrage welche Geschwister dieselben Freunde haben
select concat(L1,' ',F1) as person,concat(L2,' ',F2) as sibling, concat(p.LastName,' ',p.FirstName) as 'common friend' from Friend as f
	inner join ( /* subselect to select all siblings */
		select p1.Lastname as L1, p1.FirstName as F1, p2.LastName as L2, p2.FirstName as F2,s.*
		from Person as p1
			inner join Sibling as s
			inner join Person as p2
		on p1.id = s.from_Id
			and p2.id = s.to_Id
			and p1.id > p2.id) as s /* remove duplicates */
	inner join Person as p /* join to get name of common friend */
		where f.from_Id = s.from_Id and p.id = f.to_Id;
