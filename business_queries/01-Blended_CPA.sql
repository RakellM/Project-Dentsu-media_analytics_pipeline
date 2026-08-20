-- Query 1: Blended CPA by Brand and Month

SELECT
    dc.brand,
    dd.year,
    dd.month,
    dd.month_name,
    ROUND(SUM(f.spend_usd) / NULLIF(SUM(f.conversions), 0), 2) AS blended_cpa,
    ROUND(SUM(f.spend_usd), 2) AS total_spend,
    ROUND(SUM(f.conversions), 2) AS total_conversions
FROM fact_daily_performance f
JOIN dim_campaign AS dc 
    ON f.campaign_id = dc.campaign_id
JOIN dim_date AS dd 
    ON f.date = dd.date
GROUP BY dc.brand, dd.year, dd.month, dd.month_name
ORDER BY dd.year, dd.month;



-- Answer: 
-- Only HomeBase as Brand
-- HomeBase blended CPA ranges from $44.39 to $47.20 across Jan–Jun 2026. 
-- CPA is stable around $45 with February highest ($47.20) and January lowest ($44.39).

