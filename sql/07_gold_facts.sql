-- GOLD: Fact Tables
-------------------------------------------------------------------------------

-- Daily Campaign Performance Fact
-- Grain: one row per campaign per day per platform per ad
CREATE TABLE IF NOT EXISTS fact_daily_performance AS
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
FROM stg_daily_performance;


-- Store Visits Fact
-- Grain: one row per DMA per day
CREATE TABLE IF NOT EXISTS fact_store_visits AS
SELECT
    date,
    dma_code,
    attributed_visits,
    attribution_window_days,
    is_zero_filled
FROM stg_store_visits;

