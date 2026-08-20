-- Check dimensions
-- SELECT 'dim_campaign' AS table_name, COUNT(*) AS row_count FROM dim_campaign
-- UNION ALL
-- SELECT 'dim_dma', COUNT(*) FROM dim_dma
-- UNION ALL
-- SELECT 'dim_date', COUNT(*) FROM dim_date
-- UNION ALL
-- SELECT 'fact_daily_performance', COUNT(*) FROM fact_daily_performance
-- UNION ALL
-- SELECT 'fact_store_visits', COUNT(*) FROM fact_store_visits;

-- Check name changes
SELECT 
    campaign_id,
    COUNT(DISTINCT campaign_name) AS name_count,
    SUM(CASE WHEN is_current = 1 THEN 1 ELSE 0 END) AS current_names
FROM log_campaign_name_changes
GROUP BY campaign_id
HAVING name_count > 1
ORDER BY name_count DESC;

