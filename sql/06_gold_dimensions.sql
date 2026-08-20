-- GOLD: Dimension Tables
-------------------------------------------------------------------------------

-- Campaign Dimension (attributes only)
CREATE TABLE IF NOT EXISTS dim_campaign (
    campaign_id TEXT PRIMARY KEY,
    brand TEXT,
    product_line TEXT,
    region TEXT,
    campaign_name_standardized TEXT
);

INSERT OR IGNORE INTO _pipeline_tracking (table_name, last_processed_load_timestamp)
VALUES ('dim_campaign', '1900-01-01');

INSERT OR REPLACE INTO dim_campaign (campaign_id, brand, product_line, region, campaign_name_standardized)
SELECT
    rcl.campaign_id,
    rcl.brand,
    rcl.product_line,
    rcl.region,
    rcl.campaign_name_standardized
FROM ref_campaign_list AS rcl
JOIN raw_campaign_metadata AS cm
    ON rcl.campaign_id = cm.campaign_id
WHERE cm._load_timestamp > (
    SELECT COALESCE(last_processed_load_timestamp, '1900-01-01')
    FROM _pipeline_tracking
    WHERE table_name = 'dim_campaign'
);

UPDATE _pipeline_tracking
SET last_processed_load_timestamp = (
    SELECT MAX(_load_timestamp) FROM raw_campaign_metadata
)
WHERE table_name = 'dim_campaign'
AND (SELECT MAX(_load_timestamp) FROM raw_campaign_metadata) IS NOT NULL;


-- DMA Dimension
CREATE TABLE IF NOT EXISTS dim_dma (
    dma_code TEXT PRIMARY KEY,
    dma_name TEXT
);

INSERT OR IGNORE INTO _pipeline_tracking (table_name, last_processed_load_timestamp)
VALUES ('dim_dma', '1900-01-01');

INSERT OR REPLACE INTO dim_dma (dma_code, dma_name)
SELECT DISTINCT
    rdl.dma_code,
    rdl.dma_name
FROM ref_dma_list AS rdl
JOIN raw_store_visits AS sv
    ON rdl.dma_code = sv.dma_code
WHERE sv._load_timestamp > (
    SELECT COALESCE(last_processed_load_timestamp, '1900-01-01')
    FROM _pipeline_tracking
    WHERE table_name = 'dim_dma'
);

UPDATE _pipeline_tracking
SET last_processed_load_timestamp = (
    SELECT MAX(_load_timestamp) FROM raw_store_visits
)
WHERE table_name = 'dim_dma'
AND (SELECT MAX(_load_timestamp) FROM raw_store_visits) IS NOT NULL;


-- Date Dimension
-- ref_calendar is generated once for the full year and doesn't carry a
-- _load_timestamp to track against, so this stays a plain keyed upsert
-- (INSERT OR REPLACE on `date`) rather than a tracked incremental load.
-- It's a 366-row table and the upsert is idempotent, so this is cheap and
-- safe to run in full every time it just isn't "large-table incremental."
CREATE TABLE IF NOT EXISTS dim_date (
    date TEXT PRIMARY KEY,
    year INTEGER,
    month INTEGER,
    month_name TEXT,
    day_of_week INTEGER,
    is_weekend INTEGER
);

INSERT OR REPLACE INTO dim_date (date, year, month, month_name, day_of_week, is_weekend)
SELECT
    date,
    year,
    month,
    month_name,
    day_of_week,
    is_weekend
FROM ref_calendar;
