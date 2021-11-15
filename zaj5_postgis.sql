--Tworzenie obiektów w tabeli

CREATE TABLE obiekty (ID_obiektu INTEGER NOT NULL PRIMARY KEY, nazwa VARCHAR(10), geom geometry);

INSERT INTO obiekty 
VALUES
(1, 'obiekt1', ST_GeomFromEWKT('MULTICURVE(COMPOUNDCURVE((0 1, 1 1), CIRCULARSTRING(1 1, 2 0, 3 1), 
							CIRCULARSTRING(3 1, 4 2, 5 1), (5 1, 6 1)))'));
							
INSERT INTO obiekty
VALUES
(2, 'obiekt2', ST_GeomFromEWKT('CURVEPOLYGON(COMPOUNDCURVE((10 6, 14 6), CIRCULARSTRING(14 6, 16 4, 14 2, 12 0, 10 2),
							 (10 2, 10 6)), CIRCULARSTRING(11 2, 13 2, 11 2))'));
							
INSERT INTO obiekty
VALUES
(3, 'obiekt3', ST_GeomFromEWKT('POLYGON((10 17, 12 13, 7 15, 10 17))'));

INSERT INTO obiekty
VALUES
(4, 'obiekt4', ST_GeomFromEWKT('MULTILINESTRING((20 20, 25 25), (25 25, 27 24), (27 24, 25 22), 
											 (25 22, 26 21), (26 21, 22 19), (22 19, 20.5 19.5))'));

INSERT INTO obiekty
VALUES
(5, 'obiekt5', ST_GeomFromEWKT('MULTIPOINT((30 30.59), (38 32.234))'));

INSERT INTO obiekty
VALUES
(6, 'obiekt6', ST_GeomFromEWKT('GEOMETRYCOLLECTION(LINESTRING(1 1, 3 2), POINT(4 2))'));


--1. Wyznacz pole powierzchni bufora o wielkości 5 jednostek, który został utworzony
--   wokół najkrótszej linii łączącej obiekt 3 i 4.

SELECT ST_Area(ST_Buffer(ST_ShortestLine( (SELECT geom FROM obiekty WHERE nazwa = 'obiekt3'),
										  (SELECT geom FROM obiekty WHERE nazwa = 'obiekt4')), 5))
										  
--2. Zamień obiekt 4 na poligon. Jaki warunek musi być spełniony, aby można było wykonać to zadanie?
--   Zapewnij te warunki.

DELETE FROM obiekty WHERE nazwa = 'obiekt4'

INSERT INTO obiekty
VALUES
(4, 'obiekt4', ST_GeomFromEWKT('POLYGON((20 20, 25 25, 27 24, 25 22, 
							          26 21, 22 19, 20.5 19.5, 20 20))'))											 
											 
--3. W tabeli obiekty, jako obiekt7 zapisz obiekt złożony z obiektu 3 i obiektu 4.

INSERT INTO obiekty
VALUES
(7, 'obiekt7', ST_Union( (SELECT geom FROM obiekty WHERE nazwa = 'obiekt3'),
					  (SELECT geom FROM obiekty WHERE nazwa = 'obiekt4') ))

--4. Wyznacz pole powierzchni wszystkich buforów o wielkości 5 jednostek, które zostały utworzone
--	 wokół obiektów nie zawierających łuków.

SELECT SUM(ST_Area(ST_Buffer(geom, 5))) FROM obiekty
WHERE NOT ST_HasArc(geom)

--ST_LineToCurve - converts a LINESTRING/POLYGON to a CIRCULARSTRING, CURVED POLYGON
--ST_CurveToLine - converts a CIRCULARSTRING/CURVED POLYGON to a LINESTRING/POLYGON
--ST_LineInterpolatePoint
--ST_GeometryType - return the geometry type of the ST_Geometry value
--ST_LineFromMultiPoint - creates a LineString from a MultiPoint geometry
--ST_HasArc - returns true if a geometry or geometry collection contains a circular string
--ST_ShortestLine - returns the 2D shortest line between two geometries