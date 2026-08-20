-- SILVER: Unified Daily Campaign Performance (Meta + Google)
-------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS stg_daily_performance (
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
    _load_timestamp TEXT,
    _staged_timestamp TEXT DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (date, campaign_id, platform, adset_id, ad_id, objective, placement)
);

-- Initialize tracking
INSERT OR IGNORE INTO _pipeline_tracking (table_name, last_processed_load_timestamp)
VALUES ('stg_daily_performance', '1900-01-01');

-- Insert Meta records
INSERT OR REPLACE INTO stg_daily_performance
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
    m.spend_usd,
    m.currency_used,
    m.currency_conversion_note,
    m.conversions,
    m.conversion_value_usd,
    m.platform,
    m._load_timestamp,
    CURRENT_TIMESTAMP AS _staged_timestamp
FROM stg_meta_ads AS m
WHERE m._load_timestamp > (
    SELECT COALESCE(last_processed_load_timestamp, '1900-01-01')
    FROM _pipeline_tracking
    WHERE table_name = 'stg_daily_performance'
);

-- Insert Google records
INSERT OR REPLACE INTO stg_daily_performance
SELECT
    g.date,
    g.timestamp_utc,
    g.campaign_id,
    g.campaign_name,
    '' AS adset_id,
    '' AS ad_id,
    '' AS objective,
    g.advertising_channel_type AS placement,
    g.impressions,
    g.clicks,
    g.spend_usd,
    g.currency_used,
    g.currency_conversion_note,
    g.conversions,
    g.conversion_value_usd,
    g.platform,
    g._load_timestamp,
    CURRENT_TIMESTAMP AS _staged_timestamp
FROM stg_google_ads AS g
WHERE g._load_timestamp > (
    SELECT COALESCE(last_processed_load_timestamp, '1900-01-01')
    FROM _pipeline_tracking
    WHERE table_name = 'stg_daily_performance'
);

-- Update tracking
UPDATE _pipeline_tracking
SET last_processed_load_timestamp = (
    SELECT MAX(_load_timestamp) FROM stg_daily_performance
)
WHERE table_name = 'stg_daily_performance';
