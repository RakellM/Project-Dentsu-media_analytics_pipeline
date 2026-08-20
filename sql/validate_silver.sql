-- VALIDATION: Silver Layer Checks
-- Run after each silver transformation to verify data quality
-- ----------------------------------------------------------------------------

-- Check Meta Ads silver table
SELECT 'META_ADS_SILVER' AS check_name,
       COUNT(*) AS total_records,
       SUM(CASE WHEN spend_usd IS NULL THEN 1 ELSE 0 END) AS null_spend,
       SUM(CASE WHEN spend_usd < 0 THEN 1 ELSE 0 END) AS negative_spend,
       SUM(CASE WHEN currency_used = 'USD' THEN 1 ELSE 0 END) AS usd_records,
       SUM(CASE WHEN currency_conversion_note LIKE 'Converted%' THEN 1 ELSE 0 END) AS converted_records,
       SUM(CASE WHEN currency_conversion_note LIKE 'Assumed%' THEN 1 ELSE 0 END) AS assumed_records
FROM stg_meta_ads;


-- Check Google Ads silver table (if exists)
SELECT 'GOOGLE_ADS_SILVER' AS check_name,
       COUNT(*) AS total_records,
       SUM(CASE WHEN spend_usd IS NULL THEN 1 ELSE 0 END) AS null_spend,
       ROUND(SUM(spend_usd), 2) AS total_spend_usd
FROM stg_google_ads;


-- Check unified table (Meta + Google Ads)
SELECT 
    platform,
    COUNT(*) AS record_count,
    ROUND(SUM(spend_usd), 2) AS total_spend,
    ROUND(SUM(conversions), 2) AS total_conversions
FROM stg_daily_performance
GROUP BY platform;


-- Check store visits silver
SELECT 
    COUNT(*) AS total_records,
    SUM(CASE WHEN is_zero_filled = 1 THEN 1 ELSE 0 END) AS zero_filled,
    SUM(CASE WHEN is_zero_filled = 0 THEN 1 ELSE 0 END) AS actual_records,
    MIN(date) AS min_date,
    MAX(date) AS max_date
FROM stg_store_visits;


-- Check pipeline tracking
SELECT 'PIPELINE_TRACKING' AS check_name,
       COUNT(*) AS tracked_tables,
       MIN(last_processed_load_timestamp) AS oldest_timestamp,
       MAX(last_processed_load_timestamp) AS newest_timestamp
FROM _pipeline_tracking;



