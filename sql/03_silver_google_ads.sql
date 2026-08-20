-- SILVER: Google Ads with micros conversion
--------------------------------------------------------------------------------

-- Converts cost_micros and conversions_value_micros to USD
CREATE TABLE IF NOT EXISTS stg_google_ads (
    date TEXT,
    timestamp_utc TEXT,
    campaign_id TEXT,
    campaign_name TEXT,
    advertising_channel_type TEXT,
    impressions INTEGER,
    clicks INTEGER,
    spend_usd REAL,
    currency_used TEXT,
    currency_conversion_note TEXT,
    conversions REAL,
    conversion_value_usd REAL,
    platform TEXT,
    duplicate_combined INTEGER DEFAULT 0,
    duplicate_count INTEGER DEFAULT 1,
    _load_timestamp TEXT,
    _staged_timestamp TEXT DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (date, campaign_id, campaign_name, advertising_channel_type)
);

-- Initialize tracking for stg_google_ads
INSERT OR IGNORE INTO _pipeline_tracking (table_name, last_processed_load_timestamp)
VALUES ('stg_google_ads', '1900-01-01');

-- Insert or replace records
INSERT OR REPLACE INTO stg_google_ads
SELECT
    g.date,
    g.timestamp_utc,
    g.campaign_id,
    g.campaign_name,
    g.advertising_channel_type,
    g.impressions,
    g.clicks,
    ROUND(g.cost_micros / 1000000.0, 2) AS spend_usd,
    'USD' AS currency_used,
    'USD (native, micros converted)' AS currency_conversion_note,
    g.conversions,
    ROUND(g.conversions_value_micros / 1000000.0, 2) AS conversion_value_usd,
    g.platform,
    g.duplicate_combined,
    g.duplicate_count,
    g._load_timestamp,
    CURRENT_TIMESTAMP AS _staged_timestamp
FROM raw_google_ads AS g
WHERE g._load_timestamp >= (
    SELECT COALESCE(last_processed_load_timestamp, '1900-01-01')
    FROM _pipeline_tracking
    WHERE table_name = 'stg_google_ads'
);

-- Update tracking table
UPDATE _pipeline_tracking
SET last_processed_load_timestamp = (
    SELECT MAX(_load_timestamp) FROM raw_google_ads
)
WHERE table_name = 'stg_google_ads';





-- -- Reset Google tracking
-- UPDATE _pipeline_tracking
-- SET last_processed_load_timestamp = '1900-01-01'
-- WHERE table_name = 'stg_google_ads';

-- -- Verify reset
-- SELECT * FROM _pipeline_tracking WHERE table_name = 'stg_google_ads';
