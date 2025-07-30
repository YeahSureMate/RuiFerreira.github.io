SELECT *
FROM animal_data_dirty;

CREATE TABLE animal_data_clean AS
SELECT *
FROM animal_data_dirty;

-- Rename columns to facilitate
ALTER TABLE animal_data_clean
RENAME COLUMN `ï»¿Animal type` TO animal_type;

ALTER TABLE animal_data_clean
RENAME COLUMN `Weight kg` TO weight_kg;

ALTER TABLE animal_data_clean
RENAME COLUMN `Animal code` TO animal_code;

ALTER TABLE animal_data_clean
RENAME COLUMN `Animal name` TO animal_name;

ALTER TABLE animal_data_clean
RENAME COLUMN `Body Length cm` TO body_length_cm;


-- Look for duplicates
WITH cte_duplicates AS (
  SELECT *,
         ROW_NUMBER() OVER (PARTITION BY animal_type, Country, weight_kg,body_length_cm, gender, animal_code,latitude,longitude, animal_name, `Observation date`,`Data compiled by` ) AS rn
  FROM animal_data_clean
)
SELECT *
FROM cte_duplicates
WHERE rn > 1;


-- Create a table without the duplicates
CREATE TABLE `animal_data_clean2` (
  `animal_type` text,
  `Country` text,
  `weight_kg` text,
  `body_length_cm` text,
  `Gender` text,
  `animal_code` text,
  `Latitude` text,
  `Longitude` text,
  `animal_name` text,
  `Observation date` text,
  `Data compiled by` text,
  `rn` int
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;



-- Insert the data into the new table to later delete duplicates
INSERT INTO animal_data_clean2
SELECT *,
         ROW_NUMBER() OVER (PARTITION BY animal_type, Country, weight_kg,body_length_cm, gender, animal_code,latitude,longitude, animal_name, `Observation date`,`Data compiled by` ) AS rn
  FROM animal_data_clean;

-- Delete duplicates
DELETE
FROM animal_data_clean2
WHERE rn > 1;

-- rn column is no longer necessary
ALTER TABLE animal_data_clean2
DROP COLUMN rn;


SELECT DISTINCT Gender
FROM animal_data_clean2;

-- Set empty values to 'not determined' in gender
UPDATE animal_data_clean2
SET gender = 'not determined'
WHERE gender IS NULL OR gender = '';


-- Normalize various animal_type typos to standard values
UPDATE animal_data_clean2
SET animal_type = CASE
  WHEN animal_type IN ('red squirel', 'red squirrell','red squirrel') THEN 'Red squirrel'
  WHEN animal_type IN ('European bisonâ„¢', 'European bisson', 'European buster') THEN 'European bison'
  WHEN animal_type IN ('lynx?', 'lynx') THEN 'Lynx'
  WHEN animal_type IN ('ledgehod', 'wedgehod', 'hedgehog') THEN 'Hedgehog'
  ELSE animal_type
END;

-- Normalize country names and codes to standard country names
UPDATE animal_data_clean2
SET Country = CASE
  WHEN Country IN ('CC') THEN 'Czech Republic'
  WHEN Country IN ('CZ', 'Czech') THEN 'Czech Republic'
  WHEN Country = 'Czech Republic' THEN 'Czech Republic'  -- keep as is
  WHEN Country IN ('PL') THEN 'Poland'
  WHEN Country IN ('DE') THEN 'Germany'
  WHEN Country IN ('HU', 'Hungry') THEN 'Hungary'
  ELSE Country
END;



-- If this columns (animal_type, Country, weight, latitude, longitude) together have missing values
-- they cannot be used for analysis or imputation
DELETE FROM animal_data_clean2
WHERE (animal_type IS NULL OR animal_type = '')
  AND (Country IS NULL OR Country = '')
  AND (weight_kg IS NULL OR weight_kg = '')
  AND (Latitude IS NULL OR Latitude = '')
  AND (Longitude IS NULL OR Longitude = '');

-- Set Longitude/Latitude to NULL
-- Only for rows where Longitude is NOT NULL 
-- AND Longitude does NOT match the regular expression for a valid number
UPDATE animal_data_clean2
SET Latitude = NULL
WHERE Latitude IS NOT NULL AND Latitude NOT REGEXP '^-?[0-9]+(\.[0-9]+)?$';

UPDATE animal_data_clean2
SET Longitude = NULL
WHERE Longitude IS NOT NULL AND Longitude NOT REGEXP '^-?[0-9]+(\.[0-9]+)?$';

-- Convert blanks to NULL's
UPDATE animal_data_clean2
SET weight_kg = NULL
WHERE weight_kg = '';

-- Convert negatives to positives
UPDATE animal_data_clean2
SET weight_kg = ABS(CAST(weight_kg AS DECIMAL))
WHERE weight_kg LIKE '-%';


UPDATE animal_data_clean2
SET body_length_cm = ABS(CAST(body_length_cm AS DECIMAL))
WHERE body_length_cm LIKE '-%';

-- Convert blanks to NULL's
UPDATE animal_data_clean2
SET body_length_cm = NULL
WHERE body_length_cm = '';

-- Convert 0 to NULL's on weight_kg
UPDATE animal_data_clean2
SET weight_kg = NULL
WHERE weight_kg = '0';


-- Now I can convert datatypes from Text to double
ALTER TABLE animal_data_clean2
MODIFY COLUMN weight_kg double,
MODIFY COLUMN Latitude DOUBLE,
MODIFY COLUMN Longitude DOUBLE,
MODIFY COLUMN body_length_cm DOUBLE;

-- Looking to see how I can fill missing values on animal_type
SELECT animal_type,
MIN(weight_kg) as min_w,
MAX(weight_kg) as max_w,
MIN(body_length_cm) as min_l,
MAX(body_length_cm) as max_l
FROM animal_data_clean2
GROUP BY animal_type;

-- Found that the max length of hedgehog is set to 151, so I will update it to NULL
UPDATE animal_data_clean2
SET body_length_cm = NULL
WHERE animal_type = 'hedgehog' AND body_length_cm = 151;

-- Also found minimum weight corresponding to 24 on "European Bison" which I find unrealistic
-- It's safe to say that it's impossible that bisons could weight 30-35kg at body lengths equal to 100-125, even for juveniles
SELECT animal_type, weight_kg, body_length_cm
FROM animal_data_clean2
WHERE animal_type = 'European Bison'
ORDER BY weight_kg;


-- First rows show weights betwen 24-35kg so I will set them as NULL
UPDATE animal_data_clean2
SET weight_kg = NULL
WHERE animal_type = 'European Bison' AND weight_kg < 36;

-- Also max weight for Lynx at 171 is unrealistic
SELECT animal_type, weight_kg, body_length_cm
FROM animal_data_clean2
WHERE animal_type = 'Lynx'
ORDER BY weight_kg DESC;

-- Only one row with unusual weight returned
-- Setting to NULL
UPDATE animal_data_clean2
SET weight_kg = NULL
WHERE animal_type = 'Lynx' AND weight_kg = 171;

-- Now I want to fill empty columns based on the weight and body length of the animal
-- For instance, on average "Red squirrels" weight around 0.25-36 and the body length is 19-22
UPDATE animal_data_clean2
SET animal_type = CASE
    WHEN (animal_type IS NULL OR animal_type = '') AND weight_kg BETWEEN 0.2 AND 0.36 AND body_length_cm BETWEEN 19 AND 23 THEN 'Red squirrel'
    WHEN (animal_type IS NULL OR animal_type = '') AND weight_kg BETWEEN 0.4 AND 1.2 AND body_length_cm BETWEEN 11 AND 32 THEN 'hedgehog'
    WHEN (animal_type IS NULL OR animal_type = '') AND weight_kg BETWEEN 11 AND 30 AND body_length_cm BETWEEN 52 AND 131 THEN 'Lynx'
    WHEN (animal_type IS NULL OR animal_type = '') AND weight_kg BETWEEN 130 AND 1100 AND body_length_cm BETWEEN 100 AND 350 THEN 'European bison'
    
    ELSE animal_type 
END
WHERE animal_type IS NULL OR animal_type = '';

-- Finding out if there is any values in animal_code to find a way to populate to remaining
SELECT animal_code
FROM animal_data_clean2
WHERE animal_code IS NOT NULL AND animal_code <> '';

-- Since the column "animal_code" is completely empty, I will drop it
ALTER TABLE animal_data_clean2
DROP COLUMN Animal_code;

-- Checking animal names
-- Assuming these might be pet names
-- Found some names that match the person who compiled the data ("Bob Bobson")
SELECT *
FROM animal_data_clean2
WHERE animal_name IS NOT NULL AND animal_name <> '';

-- I will just set "bob bobson" animal names to blank
UPDATE animal_data_clean2
SET animal_name = ''
WHERE animal_name = 'Bob Bobson';

-- Checking date format consistency
SELECT DISTINCT `Observation date`
FROM animal_data_clean2;

-- Convert text strings to date format
UPDATE animal_data_clean2
SET `Observation date` = STR_TO_DATE(`Observation date`, '%d.%m.%Y')
WHERE `Observation date` REGEXP '^[0-9]{2}\\.[0-9]{2}\\.[0-9]{4}$';

-- Convert the column to date (Now it has consistent date format)
ALTER TABLE animal_data_clean2
MODIFY COLUMN `Observation date` DATE;


-- Data is ready for exploration





