-- SILVER: Meta Ads with USD conversion
--------------------------------------------------------------------------------

-- Converts CAD/GBP to USD using monthly exchange rates
-- Silver Meta Ads: Incremental
CREATE TABLE IF NOT EXISTS stg_meta_ads (
    date TEXT,
    timestamp_utc TEXT,
    campaign_id TEXT,
    campaign_name TEXT,
    adset_id TEXT,
    ad_id TEXT,
    objective TEXT,
    placement TEXT,
    impressions INTEGER,
    clicks INTEGER,
    spend_usd REAL,
    currency_used TEXT,
    currency_conversion_note TEXT,
    conversions REAL,
    conversion_value_usd REAL,
    platform TEXT,
    _load_timestamp TEXT,                              -- From raw (when data entered bronze)
    _staged_timestamp TEXT DEFAULT CURRENT_TIMESTAMP,  -- When transformed to silver
    PRIMARY KEY (date, campaign_id, adset_id, ad_id, objective, placement)
);

-- Create tracking table if not exists
CREATE TABLE IF NOT EXISTS _pipeline_tracking (
    table_name TEXT PRIMARY KEY,
    last_processed_load_timestamp TEXT
);

-- Initialize tracking for stg_meta_ads
INSERT OR IGNORE INTO _pipeline_tracking (table_name, last_processed_load_timestamp)
VALUES ('stg_meta_ads', '1900-01-01');

-- Insert or replace records
INSERT OR REPLACE INTO stg_meta_ads
SELECT
    m.date,
    m.timestamp_utc,
    m.campaign_id,
    m.campaign_name,
    m.adset_id,
    m.ad_id,
    m.objective,
    m.placement,
    m.impressions,
    m.clicks,
    ROUND(m.spend_amount * COALESCE(r.rate, 1.0), 2) AS spend_usd,
    COALESCE(m.original_currency, 'USD') AS currency_used,
    CASE
        WHEN m.currency_missing = 1 THEN 'Assumed USD (missing in source)'
        WHEN m.original_currency = 'USD' THEN 'USD (native)'
        ELSE 'Converted from ' || m.original_currency
    END AS currency_conversion_note,
    m.conversions,
    ROUND(m.conversion_value_amount * COALESCE(r.rate, 1.0), 2) AS conversion_value_usd,
    m.platform,
    m._load_timestamp,
    CURRENT_TIMESTAMP AS _staged_timestamp
FROM raw_meta_ads AS m
LEFT JOIN ref_calendar AS c 
    ON m.date = c.date
LEFT JOIN ref_exchange_rates AS r
    ON c.year = r.year AND c.month = r.month
    AND COALESCE(m.original_currency, 'USD') = r.from_currency
WHERE m._load_timestamp >= (
    SELECT COALESCE(last_processed_load_timestamp, '1900-01-01')
    FROM _pipeline_tracking
    WHERE table_name = 'stg_meta_ads'
);

-- Update tracking table
UPDATE _pipeline_tracking
SET last_processed_load_timestamp = (
    SELECT MAX(_load_timestamp) FROM raw_meta_ads
)
WHERE table_name = 'stg_meta_ads';



