-- GOLD: Fact Tables
-------------------------------------------------------------------------------

-- Daily Campaign Performance Fact
-- Grain: one row per campaign per day per platform per ad
CREATE TABLE IF NOT EXISTS fact_daily_performance (
    date TEXT,
    campaign_id TEXT,
    platform TEXT,
    adset_id TEXT,
    ad_id TEXT,
    objective TEXT,
    placement TEXT,
    impressions INTEGER,
    clicks INTEGER,
    spend_usd REAL,
    conversions REAL,
    conversion_value_usd REAL,
    PRIMARY KEY (date, campaign_id, platform, adset_id, ad_id, objective, placement)
);

INSERT OR IGNORE INTO _pipeline_tracking (table_name, last_processed_load_timestamp)
VALUES ('fact_daily_performance', '1900-01-01');

INSERT OR REPLACE INTO fact_daily_performance (
    date, campaign_id, platform, adset_id, ad_id, objective, placement,
    impressions, clicks, spend_usd, conversions, conversion_value_usd
)
SELECT
    date,
    campaign_id,
    platform,
    adset_id,
    ad_id,
    objective,
    placement,
    impressions,
    clicks,
    spend_usd,
    conversions,
    conversion_value_usd
FROM stg_daily_performance
WHERE _load_timestamp > (
    SELECT COALESCE(last_processed_load_timestamp, '1900-01-01')
    FROM _pipeline_tracking
    WHERE table_name = 'fact_daily_performance'
);

UPDATE _pipeline_tracking
SET last_processed_load_timestamp = (
    SELECT MAX(_load_timestamp) FROM stg_daily_performance
)
WHERE table_name = 'fact_daily_performance'
AND (SELECT MAX(_load_timestamp) FROM stg_daily_performance) IS NOT NULL;


-- Store Visits Fact
-- Grain: one row per DMA per day
CREATE TABLE IF NOT EXISTS fact_store_visits (
    date TEXT,
    dma_code TEXT,
    dma_name TEXT,
    mapped_region TEXT,
    attributed_visits INTEGER,
    attribution_window_days INTEGER,
    is_zero_filled INTEGER,
    PRIMARY KEY (date, dma_code)
);

INSERT OR IGNORE INTO _pipeline_tracking (table_name, last_processed_load_timestamp)
VALUES ('fact_store_visits', '1900-01-01');

INSERT OR REPLACE INTO fact_store_visits (
    date, dma_code, dma_name, mapped_region,
    attributed_visits, attribution_window_days, is_zero_filled
)
SELECT
    sv.date,
    sv.dma_code,
    dm.dma_name,
    dm.mapped_region,
    sv.attributed_visits,
    sv.attribution_window_days,
    sv.is_zero_filled
FROM stg_store_visits AS sv
JOIN ref_dma_region_map AS dm
    ON sv.dma_code = dm.dma_code
WHERE sv._load_timestamp > (
    SELECT COALESCE(last_processed_load_timestamp, '1900-01-01')
    FROM _pipeline_tracking
    WHERE table_name = 'fact_store_visits'
);

UPDATE _pipeline_tracking
SET last_processed_load_timestamp = (
    SELECT MAX(_load_timestamp) FROM stg_store_visits
)
WHERE table_name = 'fact_store_visits'
AND (SELECT MAX(_load_timestamp) FROM stg_store_visits) IS NOT NULL;
