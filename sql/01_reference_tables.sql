-- REFERENCE TABLES
-- Calendar, Exchange Rates, DMA List
-- ----------------------------------------------------------------------------

-- Calendar Table (simple date dimension)
CREATE TABLE IF NOT EXISTS ref_calendar (
    date TEXT PRIMARY KEY,
    year INTEGER,
    month INTEGER,
    month_name TEXT,
    day_of_week INTEGER,
    is_weekend INTEGER
);

-- Generate calendar for date range covering all data (Jan 1 2026 to Jan 1 2027)
WITH RECURSIVE dates(date) AS (
    SELECT '2026-01-01'
    UNION ALL
    SELECT date(date, '+1 day')
    FROM dates
    WHERE date < '2027-01-01'
)
INSERT OR IGNORE INTO ref_calendar (date, year, month, month_name, day_of_week, is_weekend)
SELECT
    date,
    CAST(strftime('%Y', date) AS INTEGER) AS year,
    CAST(strftime('%m', date) AS INTEGER) AS month,
    CASE strftime('%m', date)
        WHEN '01' THEN 'January'
        WHEN '02' THEN 'February'
        WHEN '03' THEN 'March'
        WHEN '04' THEN 'April'
        WHEN '05' THEN 'May'
        WHEN '06' THEN 'June'
        WHEN '07' THEN 'July'
        WHEN '08' THEN 'August'
        WHEN '09' THEN 'September'
        WHEN '10' THEN 'October'
        WHEN '11' THEN 'November'
        WHEN '12' THEN 'December'
    END AS month_name,
    CAST(strftime('%w', date) AS INTEGER) AS day_of_week,
    CASE WHEN strftime('%w', date) IN ('0', '6') THEN 1 ELSE 0 END AS is_weekend
FROM dates;



-- Exchange Rates (simulation, production would use API)
CREATE TABLE IF NOT EXISTS ref_exchange_rates (
    year INTEGER,
    month INTEGER,
    from_currency TEXT,
    to_currency TEXT,
    rate REAL,
    source TEXT,
    PRIMARY KEY (year, month, from_currency, to_currency)
);

-- Simulated monthly rates for 2026
INSERT OR IGNORE INTO ref_exchange_rates (year, month, from_currency, to_currency, rate, source)
VALUES
    (2026, 1, 'USD', 'USD', 1.0, 'simulation'),
    (2026, 2, 'USD', 'USD', 1.0, 'simulation'),
    (2026, 3, 'USD', 'USD', 1.0, 'simulation'),
    (2026, 4, 'USD', 'USD', 1.0, 'simulation'),
    (2026, 5, 'USD', 'USD', 1.0, 'simulation'),
    (2026, 6, 'USD', 'USD', 1.0, 'simulation'),
    
    (2026, 1, 'CAD', 'USD', 0.74, 'simulation'),
    (2026, 2, 'CAD', 'USD', 0.74, 'simulation'),
    (2026, 3, 'CAD', 'USD', 0.73, 'simulation'),
    (2026, 4, 'CAD', 'USD', 0.73, 'simulation'),
    (2026, 5, 'CAD', 'USD', 0.72, 'simulation'),
    (2026, 6, 'CAD', 'USD', 0.72, 'simulation'),
    
    (2026, 1, 'GBP', 'USD', 1.27, 'simulation'),
    (2026, 2, 'GBP', 'USD', 1.27, 'simulation'),
    (2026, 3, 'GBP', 'USD', 1.26, 'simulation'),
    (2026, 4, 'GBP', 'USD', 1.26, 'simulation'),
    (2026, 5, 'GBP', 'USD', 1.25, 'simulation'),
    (2026, 6, 'GBP', 'USD', 1.25, 'simulation');



-- DMA List (reference for store visits)
CREATE TABLE IF NOT EXISTS ref_dma_list AS
SELECT DISTINCT
    dma_code,
    dma_name
FROM raw_store_visits;


-- Campaign List (reference for Campaign metadata)
CREATE TABLE IF NOT EXISTS ref_campaign_list AS
SELECT DISTINCT
    campaign_id,
    brand,
    product_line,
    region,
    -- Standardized name (source of truth)
    brand || '_' || product_line || '_' || region AS campaign_name_standardized
FROM raw_campaign_metadata;

