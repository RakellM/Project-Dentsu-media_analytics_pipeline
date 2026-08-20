-- REFERENCE TABLES
-- Calendar, Exchange Rates, DMA List
-- ----------------------------------------------------------------------------

-- Pipeline tracking table (also created in 02_silver_meta_ads.sql; safe to
-- create here too since 01 runs first and gold-layer tracking below needs it).
CREATE TABLE IF NOT EXISTS _pipeline_tracking (
    table_name TEXT PRIMARY KEY,
    last_processed_load_timestamp TEXT
);

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
-- FIX: was `CREATE TABLE IF NOT EXISTS ... AS SELECT`, which only populates
-- the table on the very first run — after that it's a no-op and new DMAs
-- appearing in raw_store_visits are silently never picked up.
-- Now: real DDL + INSERT OR REPLACE (upsert on dma_code) gated by
-- _pipeline_tracking, same pattern as the silver tables. Only rows loaded
-- into raw_store_visits since the last tracked run are considered.
CREATE TABLE IF NOT EXISTS ref_dma_list (
    dma_code TEXT PRIMARY KEY,
    dma_name TEXT
);

INSERT OR IGNORE INTO _pipeline_tracking (table_name, last_processed_load_timestamp)
VALUES ('ref_dma_list', '1900-01-01');

INSERT OR REPLACE INTO ref_dma_list (dma_code, dma_name)
SELECT DISTINCT
    dma_code,
    dma_name
FROM raw_store_visits
WHERE _load_timestamp > (
    SELECT COALESCE(last_processed_load_timestamp, '1900-01-01')
    FROM _pipeline_tracking
    WHERE table_name = 'ref_dma_list'
);

UPDATE _pipeline_tracking
SET last_processed_load_timestamp = (
    SELECT MAX(_load_timestamp) FROM raw_store_visits
)
WHERE table_name = 'ref_dma_list'
AND (SELECT MAX(_load_timestamp) FROM raw_store_visits) IS NOT NULL;


-- Campaign List (reference for Campaign metadata)
-- FIX: same issue and same fix pattern as ref_dma_list above.
CREATE TABLE IF NOT EXISTS ref_campaign_list (
    campaign_id TEXT PRIMARY KEY,
    brand TEXT,
    product_line TEXT,
    region TEXT,
    campaign_name_standardized TEXT
);

INSERT OR IGNORE INTO _pipeline_tracking (table_name, last_processed_load_timestamp)
VALUES ('ref_campaign_list', '1900-01-01');

INSERT OR REPLACE INTO ref_campaign_list (campaign_id, brand, product_line, region, campaign_name_standardized)
SELECT DISTINCT
    campaign_id,
    brand,
    product_line,
    region,
    brand || '_' || product_line || '_' || region AS campaign_name_standardized
FROM raw_campaign_metadata
WHERE _load_timestamp > (
    SELECT COALESCE(last_processed_load_timestamp, '1900-01-01')
    FROM _pipeline_tracking
    WHERE table_name = 'ref_campaign_list'
);

UPDATE _pipeline_tracking
SET last_processed_load_timestamp = (
    SELECT MAX(_load_timestamp) FROM raw_campaign_metadata
)
WHERE table_name = 'ref_campaign_list'
AND (SELECT MAX(_load_timestamp) FROM raw_campaign_metadata) IS NOT NULL;



-- DMA to Region mapping (manual assignment)
CREATE TABLE IF NOT EXISTS ref_dma_region_map (
    dma_code TEXT PRIMARY KEY,
    dma_name TEXT,
    mapped_region TEXT,
    mapping_source TEXT DEFAULT 'manual'
);

INSERT OR IGNORE INTO ref_dma_region_map (dma_code, dma_name, mapped_region) VALUES
    -- East Coast
    ('501', 'New York', 'East'),
    ('504', 'Philadelphia', 'East'),
    ('505', 'Detroit', 'East'),
    ('506', 'Boston', 'East'),
    ('511', 'Washington DC', 'East'),
    ('524', 'Atlanta', 'East'),
    ('528', 'Miami-Ft. Lauderdale', 'East'),
    ('539', 'Tampa-St. Petersburg', 'East'),
    ('602', 'Chicago', 'East'),

    -- West Coast
    ('618', 'Houston', 'West'),
    ('623', 'Dallas-Ft. Worth', 'West'),
    ('753', 'Phoenix', 'West'),
    ('803', 'Los Angeles', 'West'),
    ('807', 'San Francisco-Oakland-San Jose', 'West'),
    ('819', 'Seattle-Tacoma', 'West');
