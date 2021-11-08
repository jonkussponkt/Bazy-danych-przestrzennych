--1.  Podaj pole powierzchni wszystkich lasów o charakterze mieszanym. 

SELECT SUM(ST_Area(trees.geom)) / 10.764 AS  Area FROM trees 
WHERE trees.vegdesc = 'Mixed Trees'

--1km^2 = 1 000 000 m^2

--2.	Podziel warstwę trees na trzy warstwy. Na każdej z nich umieść inny typ lasu.
SELECT * FROM public.trees;

CREATE TABLE deciduous_trees
AS SELECT * FROM public.trees
WHERE trees.vegdesc = 'Deciduous';

SELECT * FROM deciduous_trees

CREATE TABLE evergreen_trees
AS SELECT * FROM public.trees
WHERE trees.vegdesc = 'Evergreen';

CREATE TABLE mixed_trees
AS SELECT * FROM public.trees
WHERE trees.vegdesc = 'Mixed Trees';

--3.	Oblicz długość linii kolejowych dla regionu Matanuska-Susitna. 

SELECT SUM(ST_Length(ST_Intersection(railroads.geom, regions.geom))) / 3.281  AS Railroads_Length
FROM regions, railroads
WHERE regions.name_2 = 'Matanuska-Susitna'

--4. Oblicz, na jakiej średniej wysokości nad poziomem morza położone są lotniska o charakterze militarnym 
--Ile jest takich lotnisk? 

SELECT * FROM airports

SELECT AVG(elev) AS Mean, COUNT(*) AS Ilosc FROM airports
WHERE use = 'Military'

--Usuń z warstwy airports lotniska o charakterze militarnym, które są dodatkowo położone 
--powyżej 1400 m n.p.m. Ile było takich lotnisk?

DELETE FROM airports
WHERE use = 'Military' AND elev > 1400

SELECT COUNT(*) FROM airports
WHERE use ='Military' AND elev > 1400

--5.	Utwórz warstwę, na której znajdować się będą jedynie budynki położone w regionie Bristol Bay
--(wykorzystaj warstwę popp).  Podaj liczbę budynków. 
DROP TABLE buildings;
CREATE TABLE buildings
AS
SELECT popp.* FROM popp,regions WHERE F_CODEDESC = 'Building' AND regions.name_2 = 'Bristol Bay' AND ST_Intersects(popp.geom, regions.geom)

SELECT * FROM buildings

--Na warstwie zostaw tylko te budynki, które są położone nie dalej niż 100 km od rzek (rivers).

SELECT buildings.* FROM buildings, rivers
WHERE ST_Distance(rivers.geom, buildings.geom) <= 100000

DELETE FROM buildings
WHERE buildings.geom IN (SELECT buildings.geom FROM rivers, buildings WHERE ST_Distance(rivers.geom, buildings.geom) < 70000)

--ERROR:  subquery has too many columns
--LINE 3: WHERE buildings.geom IN (SELECT * FROM rivers, buildings WHE...

--6.	Sprawdź w ilu miejscach przecinają się rzeki (majrivers) z liniami kolejowymi (railroads).

SELECT COUNT(*) FROM 
	(SELECT ST_DumpPoints(ST_Intersection(majrivers.geom, railroads.geom)) FROM majrivers, railroads) AS Points

--aggregate function calls cannot contain set-returning function calls
--You might be able to move the set-returning function into a LATERAL FROM item.

--7.	Wydobądź węzły dla warstwy railroads. Ile jest takich węzłów?

SELECT COUNT(*) FROM (SELECT ST_DumpPoints(railroads.geom) FROM railroads) AS Nodes

--8.	Wyszukaj  najlepsze  lokalizacje do budowy hotelu. Hotel powinien być oddalony od lotniska nie więcej niż 100 km
--      i nie mniej niż 50km od linii kolejowych. Powinien leżeć także w pobliżu sieci drogowej (trails.shp).

SELECT SUM(ST_Area(ST_Intersection(
	ST_Buffer(trails.geom, 20000  * 3.281), --20000 m = 20km
	ST_Difference(ST_Buffer(airports.geom, 100000 * 3.281),   --100000m=100km
				  ST_Buffer(railroads.geom, 50000 * 3.281))))) AS Area  --50000m=50km
FROM airports, railroads, trails

--CZAS = 16 min, 24 sekundy

--9.	Uprość geometrię warstwy przedstawiającej bagna (swamps). Ustaw tolerancję na 100.

SELECT ST_Area(swamp.geom), ST_Area(ST_Simplify(swamp.geom, 100)) FROM swamp;
(SELECT COUNT(*) FROM (SELECT ST_DumpPoints(ST_Simplify(swamp.geom, 100)) FROM swamp) AS Simplified)
UNION
(SELECT COUNT(*) FROM (SELECT ST_DumpPoints(swamp.geom) FROM swamp) AS Not_Simplified);

