-- ROI ANALYSIS
-- Return on Ad Spend (ROAS) by product line and platform

-- ROI by Product Line
SELECT
    dc.product_line,
    ROUND(SUM(f.spend_usd), 2) AS total_spend,
    ROUND(SUM(f.conversion_value_usd), 2) AS total_conversion_value,
    ROUND(SUM(f.conversion_value_usd) / NULLIF(SUM(f.spend_usd), 0), 2) AS roi,
    ROUND(SUM(f.conversions), 2) AS total_conversions,
    ROUND(SUM(f.spend_usd) / NULLIF(SUM(f.conversions), 0), 2) AS cpa
FROM fact_daily_performance AS f
JOIN dim_campaign AS dc 
    ON f.campaign_id = dc.campaign_id
GROUP BY dc.product_line
ORDER BY roi DESC;

-- ROI by Platform
SELECT
    f.platform,
    ROUND(SUM(f.spend_usd), 2) AS total_spend,
    ROUND(SUM(f.conversion_value_usd), 2) AS total_conversion_value,
    ROUND(SUM(f.conversion_value_usd) / NULLIF(SUM(f.spend_usd), 0), 2) AS roi
FROM fact_daily_performance f
GROUP BY f.platform;

-- ROI by Individual Campaign
SELECT
    f.campaign_id,
    dc.campaign_name_standardized,
    dc.product_line,
    ROUND(SUM(f.spend_usd), 2) AS total_spend,
    ROUND(SUM(f.conversion_value_usd), 2) AS total_conversion_value,
    ROUND(SUM(f.conversion_value_usd) / NULLIF(SUM(f.spend_usd), 0), 2) AS roi,
    ROUND(SUM(f.spend_usd) / NULLIF(SUM(f.conversions), 0), 2) AS cpa
FROM fact_daily_performance AS f
JOIN dim_campaign AS dc 
    ON f.campaign_id = dc.campaign_id
GROUP BY f.campaign_id, dc.campaign_name_standardized, dc.product_line
ORDER BY roi DESC;

