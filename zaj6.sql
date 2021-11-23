--Pierwszym krokiem warsztatów jest stworzenie nowej bazy oraz załadowanie kopii bazy danych zawierającej
--niezbędną strukturę wraz z danymi.

CREATE DATABASE postgis_raster

--PPM na postgis_raster  -> restore

--Pracujemy w CMD (wiersz poleceń Windows):
--Przechodzimy do folderu bin postgresa:
--cd ..\..\Program Files\PostgreSQL\13\bin

CREATE EXTENSION postgis;
CREATE EXTENSION postgis_raster;

--Tworzymy rozszerzenie po to, by uniknąć tego błędu:
--DROP TABLE
--ERROR:  type "raster" does not exist
--LINE 1: ...LE "rasters"."dem" ("rid" serial PRIMARY KEY,"rast" raster);

------------------

--Przykład 1 - ST_Intersects
--Przecięcie rastra z wektorem.
CREATE TABLE schema_name.intersects AS
SELECT a.rast, b.municipality
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE ST_Intersects(a.rast, b.geom) AND b.municipality ilike 'porto';

SELECT * FROM schema_name.intersects

--ilike - case insensitive pattern matching


--W przypadku tworzenia tabel zawierających dane rastrowe sugeruje się wykonanie poniższych
--kroków:
--1. dodanie serial primary key:
ALTER TABLE schema_name.intersects
ADD COLUMN rid SERIAL PRIMARY KEY;

--2. utworzenie indeksu przestrzennego:

CREATE INDEX idx_intersects_rast_gist ON schema_name.intersects
USING gist(ST_ConvexHull(rast));

--3. dodanie raster constraints:
--schema::name table_name::name raster_column::name
SELECT AddRasterConstraints('schema_name'::name, 'intersects'::name, 'rast'::name);

--Przykład 2 - ST_Clip
--Obcinanie rastra na podstawie wektora.
CREATE TABLE schema_name.clip AS
SELECT ST_Clip(a.rast, b.geom, true), b.municipality
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE ST_Intersects(a.rast, b.geom) AND b.municipality like 'PORTO';

SELECT * FROM schema_name.clip

--Przykład 3 - ST_Union
--Połączenie wielu kafelków w jeden raster.
CREATE TABLE schema_name.union AS
SELECT ST_Union(ST_Clip(a.rast, b.geom, TRUE))
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE b.municipality ILIKE 'porto' AND ST_Intersects(b.geom, a.rast);

SELECT * FROM  schema_name.union


--Poniższe przykłady pokazują rastrowanie wektoru.
--Przykład 1 - ST_AsRaster
--Przykład pokazuje użycie funkcji ST_AsRaster w celu rastrowania tabeli z parafiami o takiej samej
--charakterystyce przestrzennej tj.: wielkość piksela, zakresy itp.
CREATE TABLE schema_name.porto_parishes AS
WITH r AS (
	SELECT rast FROM rasters.dem
	LIMIT 1
)
SELECT ST_AsRaster(a.geom,r.rast,'8BUI',a.id,-32767) AS rast
FROM vectors.porto_parishes AS a, r
WHERE a.municipality ilike 'porto';

SELECT * FROM schema_name.porto_parishes


--Przykład 2 - ST_Union
--Wynikowy raster z poprzedniego zadania to jedna parafia na rekord, na wiersz tabeli. 
--Drugi przykład łączy rekordy z poprzedniego przykładu przy użyciu funkcji ST_UNION w pojedynczy raster.
DROP TABLE schema_name.porto_parishes; --> drop table porto_parishes first
CREATE TABLE schema_name.porto_parishes AS
WITH r AS (
	SELECT rast FROM rasters.dem
	LIMIT 1
)
SELECT st_union(ST_AsRaster(a.geom,r.rast,'8BUI',a.id,-32767)) AS rast
FROM vectors.porto_parishes AS a, r

--Przykład 3 - ST_Tile
--Po uzyskaniu pojedynczego rastra można generować kafelki za pomocą funkcji ST_Tile.
DROP TABLE schema_name.porto_parishes; --> drop table porto_parishes first
CREATE TABLE schema_name.porto_parishes AS
WITH r AS (
	SELECT rast FROM rasters.dem
	LIMIT 1 
)
SELECT st_tile(st_union(ST_AsRaster(a.geom,r.rast,'8BUI',a.id,-32767)),128,128,true,-32767) AS rast
FROM vectors.porto_parishes AS a, r
WHERE a.municipality ilike 'porto';


--Konwertowanie rastrów na wektory (wektoryzowanie)
create table schema_name.intersection as
SELECT a.rid,(ST_Intersection(b.geom,a.rast)).geom,(ST_Intersection(b.geom,a.rast)).val
FROM rasters.landsat8 AS a, vectors.porto_parishes AS b
WHERE b.parish ilike 'paranhos' and ST_Intersects(b.geom,a.rast);

--Przykład 2 - ST_DumpAsPolygons
--ST_DumpAsPolygons konwertuje rastry w wektory (poligony).

CREATE TABLE schema_name.dumppolygons AS
SELECT a.rid,(ST_DumpAsPolygons(ST_Clip(a.rast,b.geom))).geom,(ST_DumpAsPolygons(ST_Clip(a.rast,b.geom))).val
FROM rasters.landsat8 AS a, vectors.porto_parishes AS b
WHERE b.parish ilike 'paranhos' and ST_Intersects(b.geom,a.rast);
-----------------------------
--Analiza rastrów
--Przykład 1 - ST_Band
--Funkcja ST_Band służy do wyodrębniania pasm z rastra
CREATE TABLE schema_name.landsat_nir AS
SELECT rid, ST_Band(rast,4) AS rast
FROM rasters.landsat8;

SELECT * FROM schema_name.landsat_nir
LIMIT 10;

--Przykład 2 - ST_Clip
--ST_Clip może być użyty do wycięcia rastra z innego rastra. 
--Poniższy przykład wycina jedną parafię z tabeli vectors.porto_parishes. 
--Wynik będzie potrzebny do wykonania kolejnych przykładów.

CREATE TABLE schema_name.paranhos_dem AS
SELECT a.rid,ST_Clip(a.rast, b.geom,true) as rast
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE b.parish ilike 'paranhos' and ST_Intersects(b.geom,a.rast);

--Przykład 3 - ST_Slope
--Poniższy przykład użycia funkcji ST_Slope wygeneruje nachylenie przy użyciu poprzednio 
--wygenerowanej tabeli (wzniesienie).
CREATE TABLE schema_name.paranhos_slope AS
SELECT a.rid,ST_Slope(a.rast,1,'32BF','PERCENTAGE') as rast
FROM schema_name.paranhos_dem AS a;

--Przykład 4 - ST_Reclass
--Aby zreklasyfikować raster należy użyć funkcji ST_Reclass.
CREATE TABLE schema_name.paranhos_slope_reclass AS
SELECT a.rid,ST_Reclass(a.rast,1,']0-15]:1, (15-30]:2, (30-9999:3', '32BF',0)
FROM schema_name.paranhos_slope AS a;

--Przykład 5 - ST_SummaryStats
--Aby obliczyć statystyki rastra można użyć funkcji ST_SummaryStats. 
--Poniższy przykład wygeneruje statystyki dla kafelka.
SELECT st_summarystats(a.rast) AS stats
FROM schema_name.paranhos_dem AS a;

--Przykład 6 - ST_SummaryStats oraz Union
--Przy użyciu UNION można wygenerować jedną statystykę wybranego rastra.
SELECT st_summarystats(ST_Union(a.rast))
FROM schema_name.paranhos_dem AS a;

--Przykład 7 - ST_SummaryStats z lepszą kontrolą złożonego typu danych
WITH t AS (
	SELECT st_summarystats(ST_Union(a.rast)) AS stats
	FROM schema_name.paranhos_dem AS a
)
SELECT (stats).min,(stats).max,(stats).mean FROM t;

--Przykład 8 - ST_SummaryStats w połączeniu z GROUP BY
--Aby wyświetlić statystykę dla każdego poligonu "parish" można użyć polecenia GROUP BY

WITH t AS (
	SELECT b.parish AS parish, st_summarystats(ST_Union(ST_Clip(a.rast, b.geom,true))) AS stats
	FROM rasters.dem AS a, vectors.porto_parishes AS b
	WHERE b.municipality ilike 'porto' and ST_Intersects(b.geom,a.rast)
	group by b.parish
)
SELECT parish,(stats).min,(stats).max,(stats).mean FROM t;

--Przykład 9 - ST_Value
--Funkcja ST_Value pozwala wyodrębnić wartość piksela z punktu lub zestawu punktów. 
--Poniższy przykład wyodrębnia punkty znajdujące się w tabeli vectors.places.
--Ponieważ geometria punktów jest wielopunktowa, a funkcja ST_Value wymaga geometrii jednopunktowej, 
--należy przekonwertować geometrię wielopunktową na geometrię jednopunktową za pomocą funkcji (ST_Dump(b.geom)).geom.
SELECT b.name,st_value(a.rast,(ST_Dump(b.geom)).geom)
FROM rasters.dem a, vectors.places AS b
WHERE ST_Intersects(a.rast,b.geom)
ORDER BY b.name;

--Przykład 10 - ST_TPI
--
create table schema_name.tpi30 as
select ST_TPI(a.rast,1) as rast
from rasters.dem a;
--Poniższa kwerenda utworzy indeks przestrzenny:
CREATE INDEX idx_tpi30_rast_gist ON schema_name.tpi30
USING gist (ST_ConvexHull(rast));
--Dodanie constraintów:
SELECT AddRasterConstraints('schema_name'::name, 'tpi30'::name,'rast'::name);
--CZAS WYKONANIA = 38 secs 895 msecs

--Problem do samodzielnego rozwiązania
--Przetwarzanie poprzedniego zapytania może potrwać dłużej niż minutę, a niektóre zapytania mogą potrwać zbyt długo. 
--W celu skrócenia czasu przetwarzania czasami można ograniczyć obszar zainteresowania i obliczyć mniejszy region. 
--Dostosuj zapytanie z przykładu 10, aby przetwarzać tylko gminę Porto. 
--Musisz użyć ST_Intersects, sprawdź Przykład 1 - ST_Intersects w celach informacyjnych. 
--Porównaj różne czasy przetwarzania. Na koniec sprawdź wynik w QGIS.
DROP TABLE schema_name.tpi30 ;
CREATE TABLE schema_name.tpi30
AS
SELECT ST_TPI(a.rast, 1) AS rast
FROM rasters.dem a, vectors.porto_parishes b
WHERE ST_Intersects(a.rast, b.geom) AND b.municipality ILIKE 'porto';

--CZAS WYK = 1 secs 688 msecs

CREATE INDEX idx_tpi30_porto_rast_gist ON schema_name.tpi30_portoUSING gist (ST_ConvexHull(rast));
SELECT AddRasterConstraints('schema_name'::name, 'tpi30_porto'::name,'rast'::name);

-------------------------------------------------------------------------------


----Przykład 1 - Wyrażenie Algebry Map
CREATE TABLE schema_name.porto_ndvi AS
WITH r 
AS (
	SELECT a.rid,ST_Clip(a.rast, b.geom,true) AS rast
	FROM rasters.landsat8 AS a, vectors.porto_parishes AS b
	WHERE b.municipality ilike 'porto' and ST_Intersects(b.geom,a.rast)
)
SELECT r.rid,ST_MapAlgebra(
r.rast, 1,
r.rast, 4,
'([rast2.val] - [rast1.val]) / ([rast2.val] + [rast1.val])::float','32BF'
) AS rast
FROM r;
--Poniższe zapytanie utworzy indeks przestrzenny na wcześniej stworzonej tabeli:
CREATE INDEX idx_porto_ndvi_rast_gist ON schema_name.porto_ndvi
USING gist (ST_ConvexHull(rast));
--Dodanie constraintów:
SELECT AddRasterConstraints('schema_name'::name, 'porto_ndvi'::name,'rast'::name);

--Przykład 2 – Funkcja zwrotna
--W pierwszym kroku należy utworzyć funkcję, które będzie wywołana później:
create or replace function schema_name.ndvi(
		value double precision [] [] [],
		pos integer [][],
		VARIADIC userargs text []
	)
	RETURNS double precision AS
	$$
	BEGIN
	--RAISE NOTICE 'Pixel Value: %', value [1][1][1];-->For debug purposes
	RETURN (value [2][1][1] - value [1][1][1])/(value [2][1][1]+value [1][1][1]); --> NDVI calculation!
END;
$$
LANGUAGE 'plpgsql' IMMUTABLE COST 1000;

--W kwerendzie algebry map należy można wywołać zdefiniowaną wcześniej funkcję:
CREATE TABLE schema_name.porto_ndvi2 AS
WITH r AS (
	SELECT a.rid,ST_Clip(a.rast, b.geom,true) AS rast
	FROM rasters.landsat8 AS a, vectors.porto_parishes AS b
	WHERE b.municipality ilike 'porto' and ST_Intersects(b.geom,a.rast)
)
SELECT
	r.rid,ST_MapAlgebra(
	r.rast, ARRAY[1,4],
	'schema_name.ndvi(double precision[], integer[],text[])'::regprocedure, --> This is the function!
	'32BF'::text
) AS rast
FROM r;

--Dodanie indeksu przestrzennego:
CREATE INDEX idx_porto_ndvi2_rast_gist ON schema_name.porto_ndvi2
USING gist (ST_ConvexHull(rast));

--Dodanie constraintów:
SELECT AddRasterConstraints('schema_name'::name, 'porto_ndvi2'::name,'rast'::name);


------
--Eksport danych

--Przykład 1 - ST_AsTiff
--Funkcja ST_AsTiff tworzy dane wyjściowe jako binarną reprezentację pliku tiff, 
--może to być przydatne na stronach internetowych, skryptach itp., w których programista może kontrolować, 
--co zrobić z plikiem binarnym, na przykład zapisać go na dysku lub po prostu wyświetlić.

SELECT ST_AsTiff(ST_Union(rast))
FROM schema_name.porto_ndvi;


-----------------------
--Przykład 2 - ST_AsGDALRaster
--Podobnie do funkcji ST_AsTiff, ST_AsGDALRaster nie zapisuje danych wyjściowych bezpośrednio na dysku, 
--natomiast dane wyjściowe są reprezentacją binarną dowolnego formatu GDAL.

SELECT ST_AsGDALRaster(ST_Union(rast), 'GTiff', ARRAY['COMPRESS=DEFLATE', 'PREDICTOR=2', 'PZLEVEL=9'])
FROM schema_name.porto_ndvi;

--Uwaga:
--Funkcje ST_AsGDALRaster pozwalają nam zapisać raster w dowolnym formacie obsługiwanym przez gdal. 
--Aby wyświetlić listę formatów obsługiwanych przez bibliotekę uruchom:
SELECT ST_GDALDrivers();

--Przykład 3 - Zapisywanie danych na dysku za pomocą dużego obiektu (large object, lo)
CREATE TABLE tmp_out 
AS
SELECT lo_from_bytea(0,
	ST_AsGDALRaster(ST_Union(rast), 'GTiff', ARRAY['COMPRESS=DEFLATE', 'PREDICTOR=2', 'PZLEVEL=9'])
) AS loid
FROM schema_name.porto_ndvi;
----------------------------------------------
SELECT lo_export(loid, 'C:\Users\Admin\Desktop\rastry\PostGIS\rasters\myraster.tiff') 
--> Save the file in a place where the user postgres have access. 
--In windows a flash drive usualy works fine.
FROM tmp_out;
----------------------------------------------
SELECT lo_unlink(loid)
FROM tmp_out; --> Delete the large object.
