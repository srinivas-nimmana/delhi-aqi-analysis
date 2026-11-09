-- ============================================================
-- Delhi AQI vs 25 Indian Cities (2015-2020)
-- 01_load_city_day.sql: load city_day.csv into MySQL as a typed table
-- Source: Kaggle "Air Quality Data in India" (rohanrao)
--
-- Approach: load the CSV as text into a staging table (city_day_raw),
-- then copy into a typed table (city_day), converting blanks to NULL.
-- Missing readings stay NULL (not 0) so coverage checks and averages stay correct.
-- ============================================================

-- 1. Database
CREATE DATABASE IF NOT EXISTS indian_air_quality;
USE indian_air_quality;

-- 2. Final table: typed columns, two decimal places for readings
CREATE TABLE city_day (
  city        VARCHAR(50),
  date        DATE,
  pm25        DECIMAL(10,2),
  pm10        DECIMAL(10,2),
  no          DECIMAL(10,2),
  no2         DECIMAL(10,2),
  nox         DECIMAL(10,2),
  nh3         DECIMAL(10,2),
  co          DECIMAL(10,2),
  so2         DECIMAL(10,2),
  o3          DECIMAL(10,2),
  benzene     DECIMAL(10,2),
  toluene     DECIMAL(10,2),
  xylene      DECIMAL(10,2),
  aqi         DECIMAL(10,2),
  aqi_bucket  VARCHAR(30)
);

-- 3. Staging table: all text, so blank cells load without errors
CREATE TABLE city_day_raw (
  city        VARCHAR(50),
  date        VARCHAR(20),
  pm25        VARCHAR(20),
  pm10        VARCHAR(20),
  no          VARCHAR(20),
  no2         VARCHAR(20),
  nox         VARCHAR(20),
  nh3         VARCHAR(20),
  co          VARCHAR(20),
  so2         VARCHAR(20),
  o3          VARCHAR(20),
  benzene     VARCHAR(20),
  toluene     VARCHAR(20),
  xylene      VARCHAR(20),
  aqi         VARCHAR(20),
  aqi_bucket  VARCHAR(30)
);

-- 4. Load the CSV (LOAD DATA, as the Import Wizard was too slow for this file)
-- Requires OPT_LOCAL_INFILE=1 in the connection's Advanced settings.
TRUNCATE TABLE city_day_raw;
SET GLOBAL local_infile = 1;

LOAD DATA LOCAL INFILE 'C:/Users/Sri Gowrav Srinivas/Downloads/archive/city_day.csv'
INTO TABLE city_day_raw
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

SELECT COUNT(*) AS rows_in_raw FROM city_day_raw;   -- 29,531 expected

-- 5. Copy to the typed table: blanks become NULL, text becomes DATE/DECIMAL
TRUNCATE TABLE city_day;

INSERT INTO city_day
SELECT TRIM(city),
       STR_TO_DATE(date, '%Y-%m-%d'),
       NULLIF(TRIM(pm25), ''),    NULLIF(TRIM(pm10), ''),
       NULLIF(TRIM(no), ''),      NULLIF(TRIM(no2), ''),
       NULLIF(TRIM(nox), ''),     NULLIF(TRIM(nh3), ''),
       NULLIF(TRIM(co), ''),      NULLIF(TRIM(so2), ''),
       NULLIF(TRIM(o3), ''),      NULLIF(TRIM(benzene), ''),
       NULLIF(TRIM(toluene), ''), NULLIF(TRIM(xylene), ''),
       NULLIF(TRIM(aqi), ''),
       NULLIF(TRIM(REPLACE(aqi_bucket, '\r', '')), '')
FROM city_day_raw;
-- Expect 29531 rows affected and 0 warnings.

-- 6. Verify the typed table
DESCRIBE city_day;                                              -- decimal(10,2), date
SELECT city, date, no, no2, co, so2 FROM city_day LIMIT 5;      -- decimals preserved

SELECT COUNT(*)             AS total_rows,
       MIN(date)            AS first_date,
       MAX(date)            AS last_date,
       COUNT(DISTINCT city) AS cities
FROM city_day;

SELECT aqi_bucket, COUNT(*) AS days FROM city_day GROUP BY aqi_bucket;

-- 7. Clean up after the checks pass (analysis uses city_day only)
DROP TABLE city_day_raw;

-- ## Q1. How much AQI data does each city have, and over what period?
-- Why first: every comparison later depends on whether cities have comparable coverage.
SELECT city,
       MIN(date) AS first_date,
       MAX(date) AS last_date,
       COUNT(*) AS total_days,
       COUNT(aqi) AS days_with_aqi,
       ROUND(100.0 * COUNT(aqi) / COUNT(*), 1) AS pct_available
FROM city_day
GROUP BY city
ORDER BY pct_available;
-- Key finding: Delhi has the highest AQI data availability at 99.5%, while Mumbai has only 38.6%, 
-- highlighting significant differences in monitoring-data coverage across cities.

- ## Q2. Which 5 cities have the highest average AQI, and where does Delhi rank?
-- Leads on from Q1: now that coverage is known, see who is most polluted overall.
WITH ranked AS (
  SELECT city,
         ROUND(AVG(aqi), 1) AS avg_aqi,
         RANK() OVER (ORDER BY AVG(aqi) DESC) AS pollution_rank
  FROM city_day
  WHERE aqi IS NOT NULL
  GROUP BY city
)
SELECT *
FROM ranked
WHERE pollution_rank <= 5 OR city = 'Delhi'
ORDER BY pollution_rank;
-- Key Finding Ahmedabad ranks first in average AQI (452.1), followed by Delhi (259.5), 
-- Patna (240.8), Gurugram (225.1), and Lucknow (218.0), indicating substantial differences in average pollution levels across cities.

- ## Q3. How has Delhi's average AQI changed year over year?
-- Leads on from Q2: Delhi is high, but is it getting worse or just staying high?
WITH delhi_yearly AS (
  SELECT YEAR(date) AS yr,
         ROUND(AVG(aqi), 1) AS avg_aqi,
         COUNT(aqi) AS days_with_aqi
  FROM city_day
  WHERE city = 'Delhi' AND aqi IS NOT NULL
  GROUP BY YEAR(date)
)
SELECT yr, avg_aqi, days_with_aqi,
       ROUND(avg_aqi - LAG(avg_aqi) OVER (ORDER BY yr), 1) AS change_vs_prev_year,
       ROUND(100.0 * (avg_aqi - LAG(avg_aqi) OVER (ORDER BY yr))
             / LAG(avg_aqi) OVER (ORDER BY yr), 1) AS pct_change
FROM delhi_yearly
ORDER BY yr;
-- Note: 2020 is a partial year (data ends mid-2020), so read it with care.
-- Key Finding: Delhi's average AQI increased slightly from 297.0 in 2015 to 301.4 in 2016, before declining 
-- consistently to 181.7 in 2020, although 2020 contains only 183 days of observations

-- ## Q4. Which months are the most polluted in Delhi?
-- Leads on from Q3: yearly averages hide a strong seasonal pattern, so look inside the year.
SELECT MONTH(date) AS month_no,
       DATE_FORMAT(date, '%b') AS month_name,
       ROUND(AVG(aqi), 1) AS avg_aqi
FROM city_day
WHERE city = 'Delhi' AND aqi IS NOT NULL
GROUP BY MONTH(date), DATE_FORMAT(date, '%b')
ORDER BY month_no;
-- Key Finding:November records the highest average AQI (402.0), followed by December (371.2) and January (360.0), 
-- while August has the lowest average AQI (134.4), indicating a strong seasonal variation in Delhi's air pollution.

-- ## Q5. How many Very Poor or Severe days did Delhi record each year?
-- Leads on from Q4: winter spikes matter most, so count the worst days directly.
SELECT YEAR(date) AS yr,
       SUM(CASE WHEN aqi_bucket IN ('Very Poor', 'Severe') THEN 1 ELSE 0 END) AS bad_days,
       COUNT(aqi) AS days_with_aqi,
       ROUND(100.0 * SUM(CASE WHEN aqi_bucket IN ('Very Poor', 'Severe') THEN 1 ELSE 0 END)
             / NULLIF(COUNT(aqi), 0), 1) AS pct_bad_days
FROM city_day
WHERE city = 'Delhi'
GROUP BY YEAR(date)
ORDER BY yr;
-- Key Finding:Delhi's Very Poor/Severe AQI days declined from 183 days (50.1%) in 2015 to 95 days (26.0%) in 2019, 
-- while 2020 recorded 25 days (13.7%) across only 183 observed days.

-- ## Q6. How far above the other cities is Delhi each month?
-- Leads on from Q5: bad days are high in absolute terms, but how does Delhi compare to peers?
WITH monthly AS (
  SELECT city,
         DATE_FORMAT(date, '%Y-%m-01') AS month,
         AVG(aqi) AS avg_aqi
  FROM city_day
  WHERE aqi IS NOT NULL
  GROUP BY city, DATE_FORMAT(date, '%Y-%m-01')
)
SELECT d.month,
       ROUND(d.avg_aqi, 1) AS delhi_aqi,
       ROUND(AVG(o.avg_aqi), 1) AS other_cities_avg,
       ROUND(d.avg_aqi - AVG(o.avg_aqi), 1) AS gap
FROM monthly d
JOIN monthly o ON o.month = d.month AND o.city <> 'Delhi'
WHERE d.city = 'Delhi'
GROUP BY d.month, d.avg_aqi
ORDER BY d.month;
-- Key Finding:Monthly AQI Comparison: Delhi recorded higher average AQI than the other cities in many observed months, 
-- particularly during late 2018 and 2019, although some months such as February 2015 showed substantially higher pollution levels across the other cities.

- ## Q7. Which cities worsened the most between 2016 and 2019, and where does Delhi stand?
-- Leads on from Q6: is Delhi deteriorating faster than others, or are many cities moving together?
-- Uses only years with at least 250 days of data. Adjust the years or threshold if too many cities drop out.
WITH yearly AS (
  SELECT city,
         YEAR(date) AS yr,
         AVG(aqi) AS avg_aqi,
         COUNT(aqi) AS n_days
  FROM city_day
  WHERE aqi IS NOT NULL
  GROUP BY city, YEAR(date)
)
SELECT a.city,
       ROUND(a.avg_aqi, 1) AS aqi_2016,
       ROUND(b.avg_aqi, 1) AS aqi_2019,
       ROUND(b.avg_aqi - a.avg_aqi, 1) AS change_in_aqi,
       RANK() OVER (ORDER BY b.avg_aqi - a.avg_aqi DESC) AS worsening_rank
FROM yearly a
JOIN yearly b ON a.city = b.city AND a.yr = 2016 AND b.yr = 2019
WHERE a.n_days >= 250 AND b.n_days >= 250
ORDER BY worsening_rank;
-- Key Finding: Delhi recorded the largest reduction in average AQI (69.3 points), 
-- while Bengaluru recorded the smallest reduction (14.0 points) among the six cities analyzed.

- ## Q8. Which pollutants are higher in Delhi than in the other cities each year?
-- Leads on from Q7: if Delhi differs, what is driving the difference? Start with particulate matter.
SELECT YEAR(date) AS yr,
       ROUND(AVG(CASE WHEN city = 'Delhi' THEN pm25 END), 1) AS delhi_pm25,
       ROUND(AVG(CASE WHEN city <> 'Delhi' THEN pm25 END), 1) AS others_pm25,
       ROUND(AVG(CASE WHEN city = 'Delhi' THEN pm10 END), 1) AS delhi_pm10,
       ROUND(AVG(CASE WHEN city <> 'Delhi' THEN pm10 END), 1) AS others_pm10
FROM city_day
GROUP BY YEAR(date)
ORDER BY yr;
-- Key Finding:Delhi recorded higher average PM2.5 and PM10 concentrations than the combined average of other cities 
-- in every year from 2015 to 2020, highlighting consistently higher particulate pollution levels.

- ## Q9. How much does Delhi's AQI jump around Diwali compared with the weeks before?
-- Leads on from Q8: one known driver of the autumn spike is fireworks, so test the Diwali effect.
-- Diwali dates (verify before publishing): 2015-11-11, 2016-10-30, 2017-10-19, 2018-11-07, 2019-10-27
WITH diwali (yr, d) AS (
  VALUES ROW(2015, DATE '2015-11-11'),
         ROW(2016, DATE '2016-10-30'),
         ROW(2017, DATE '2017-10-19'),
         ROW(2018, DATE '2018-11-07'),
         ROW(2019, DATE '2019-10-27')
),
windows AS (
  SELECT di.yr,
         AVG(CASE WHEN c.date BETWEEN di.d - INTERVAL 3 DAY AND di.d + INTERVAL 3 DAY
                  THEN c.aqi END) AS around_diwali,
         AVG(CASE WHEN c.date BETWEEN di.d - INTERVAL 24 DAY AND di.d - INTERVAL 4 DAY
                  THEN c.aqi END) AS three_weeks_before
  FROM diwali di
  JOIN city_day c
    ON c.city = 'Delhi'
   AND c.date BETWEEN di.d - INTERVAL 24 DAY AND di.d + INTERVAL 3 DAY
  GROUP BY di.yr
)
SELECT yr,
       ROUND(three_weeks_before, 1) AS before_aqi,
       ROUND(around_diwali, 1) AS diwali_aqi,
       ROUND(100.0 * (around_diwali - three_weeks_before) / three_weeks_before, 1) AS pct_jump
FROM windows
ORDER BY yr;
-- Key Finding:Delhi's AQI increased on Diwali in all five years analyzed (2015–2019), with the largest increase in 2017 (87.4%), followed by 2019 (75.1%).

-- ## Q10. How much did the 2020 lockdown cut AQI in Delhi compared with other cities?
-- Leads on from Q9: the lockdown is a natural experiment, so compare Mar 25 to Jun 30 in 2019 vs 2020.
WITH w AS (
  SELECT city,
         AVG(CASE WHEN date BETWEEN '2019-03-25' AND '2019-06-30' THEN aqi END) AS aqi_2019,
         AVG(CASE WHEN date BETWEEN '2020-03-25' AND '2020-06-30' THEN aqi END) AS aqi_2020
  FROM city_day
  GROUP BY city
)
SELECT city,
       ROUND(aqi_2019, 1) AS aqi_2019,
       ROUND(aqi_2020, 1) AS aqi_2020,
       ROUND(100.0 * (aqi_2020 - aqi_2019) / aqi_2019, 1) AS pct_change
FROM w
WHERE aqi_2019 IS NOT NULL AND aqi_2020 IS NOT NULL
ORDER BY pct_change;
-- Key Finding: AQI declined across most analyzed cities during the 2020 lockdown period compared with the same period in 2019, 
-- with Ahmedabad recording the largest reduction (76.1%), while Jorapokhar experienced a 4.2% increase. 
 