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
-- Recreate fact_store_visits with region
-- DROP TABLE IF EXISTS fact_store_visits;
CREATE TABLE IF NOT EXISTS fact_store_visits AS
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
    ON sv.dma_code = dm.dma_code;
