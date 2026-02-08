-- Top 5 Populous Countries in 2020
use live_project;
select * from europecsv
where indicatorCode = 'SP.POP.TOTL' and year = 2020
order by value desc
limit 5;
-- 4. Countries with Literacy Rate Above 90%

SELECT c.country_code AS countrycode, e.indicatorname AS indicatorname, e.indicatorcode AS indicatorcode, e.year,
round(e.value,2) as`Literacy Rate` FROM wdi_country c JOIN europecsv e ON e.countrycode = c.country_code
WHERE e.IndicatorCode IN ('SE.ADT.LITR.ZS' , 'SE.ADT.1524.LT.ZS') AND value > 90;

 -- GDP Growth Percentage by Decade        
SELECT c.country_code AS countrycode, c.short_name AS countryname, e.indicatorname AS indicatorname, e.indicatorcode AS indicatorcode,
ROUND(e.year / 10) * 10 AS Decade, CONCAT(ROUND(e.value, 2), '%') AS GDP_Growth
FROM wdi_country c JOIN europecsv e ON e.countrycode = c.country_code
WHERE e.indicatorcode = 'NY.GDP.MKTP.KD.ZG';
    
-- Average Life Expectancy by Continent  
select c.country_code AS country_code, c.short_name AS country_name, e.indicatorcode AS indicator, c.region AS continent, e.indicatorname AS indicator_name,
round(AVG(e.value)) AS life_expectancy
FROM wdi_country c JOIN europecsv e ON c.country_code = e.countrycode
WHERE e.indicatorcode = 'SP.DYN.LE00.IN'
GROUP BY c.country_code , c.short_name , c.region , e.indicatorcode , e.indicatorname
ORDER BY life_expectancy DESC;

-- YoY Growth % (GDP / Population / any indicator) gdp= NY.GDP.MKTP.KD.ZG, population= SP.POP.TOTL

SELECT CountryName, Year, Indicatorcode, value as gdp, LAG(value) OVER (PARTITION BY CountryName ORDER BY year) AS previous_year_gdp, 
round (((value- lag(value) over (partition by CountryName order by year)) / lag(value) over (partition by CountryName order by year )) 
    , 2 ) as yoy_growth_percentage from europecsv where indicatorcode = 'NY.GDP.MKTP.KD.ZG'
order by CountryName, year;

-- Rank countries by latest available value

SELECT CountryName, Year, value, ROW_NUMBER() OVER (PARTITION BY CountryName ORDER BY Year DESC) AS rn
FROM europecsv
WHERE IndicatorCode = 'NY.GDP.MKTP.KD.ZG';

WITH latest AS (SELECT CountryName, Year, value, ROW_NUMBER() OVER (PARTITION BY CountryName ORDER BY Year DESC) AS rn
FROM europecsv
WHERE IndicatorCode = 'NY.GDP.MKTP.KD.ZG')
SELECT CountryName, Year AS latest_year, value AS latest_value, RANK() OVER (ORDER BY value DESC) AS value_rank
FROM latest
WHERE rn = 1
ORDER BY value_rank;

-- Coverage analysis (% missing by country) population

SELECT CountryName, COUNT(Year) AS available_years,(MAX(Year) - MIN(Year) ) AS expected_years, (MAX(Year) - MIN(Year) ) - COUNT(Year) AS missing_years,
ROUND((( (MAX(Year) - MIN(Year)) - COUNT(Year) ) / (MAX(Year) - MIN(Year) )), 2) AS percentage_missing
FROM europecsv
WHERE IndicatorCode = 'SE.ADT.1524.LT.ZS'
GROUP BY CountryName
ORDER BY percentage_missing DESC;

SELECT CountryName, COUNT(Year) AS available_years, (MAX(Year) - MIN(Year) + 1) AS expected_years, (MAX(Year) - MIN(Year) + 1) - COUNT(Year) AS missing_years,
ROUND((( (MAX(Year) - MIN(Year) + 1) - COUNT(Year) ) / (MAX(Year) - MIN(Year) + 1)) , 2) AS pct_missing
FROM europecsv
GROUP BY CountryName
ORDER BY pct_missing DESC;

--  Income-group benchmarking
SELECT e.CountryName, w.Income_Group, e.indicatorName, e.value AS country_value, e.indicatorCode, AVG(value) OVER (PARTITION BY Income_Group) AS income_group_avg,
ROUND(value - AVG(value) OVER (PARTITION BY Income_group), 2) AS above_below_group
FROM wdi_country w join europecsv e on e.countrycode = w.country_code
WHERE IndicatorCode = 'NY.GDP.MKTP.KD.ZG';

-- CAGR

SELECT CountryCode, countryname, Year, ROUND( POWER(value / NULLIF( FIRST_VALUE(value) OVER ( PARTITION BY countrycode
ORDER BY year), 0), 1.0 / ( year - FIRST_VALUE(year) OVER (PARTITION BY countrycode ORDER BY year))) - 1,4) AS cagr
FROM europecsv
WHERE indicatorcode = 'NY.GDP.MKTP.KD'
ORDER BY countrycode, year;

-- composite dev Zscore

with stats as (select indicatorname, avg(value) as mean, STDDEV(value) as stddev
from europecsv
where indicatorname in ( 
          'GDP per capita (constant 2015 US$)',
          'Life expectancy at birth, total (years)',
          'CO2 emissions (metric tons per capita)')
    group by indicatorname),

z_scores as (select a.countryname, a.indicatorname, (a.value - s.mean) / s.stddev as z
    from europecsv a
    join stats s on a.indicatorname = s.indicatorname
    where a.indicatorname in (
          'GDP per capita (constant 2015 US$)',
          'Life expectancy at birth, total (years)',
          'CO2 emissions (metric tons per capita)'))
select countryname, avg(z) as country_z_score
from z_scores
group by countryname
order by country_z_score desc;

-- rolling

SELECT e1.CountryName,e1.indicatorcode,
    e1.Year, round((e1.value/1000000),2) AS gdp_million,
    ROUND((SELECT AVG(e2.value/1000000) FROM europecsv e2
	WHERE e2.CountryName = e1.CountryName AND e2.indicatorcode = e1.indicatorcode
              AND e2.Year BETWEEN e1.Year - 4 AND e1.Year ),2 ) AS gdp_5yr_moving_avg_million
FROM europecsv e1
WHERE e1.indicatorcode = 'NY.GDP.MKTP.KD'
ORDER BY e1.CountryName, e1.Year;

