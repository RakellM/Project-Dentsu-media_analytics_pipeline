-- Query 3: Spend vs Store Visits (with DMA mapping)
SELECT
    strftime('%Y-W%W', f.date) AS week,
    MIN(f.date) AS week_start,
    dc.region AS campaign_region,
    ROUND(SUM(f.spend_usd), 2) AS total_spend_usd,
    SUM(fsv.attributed_visits) AS total_store_visits,
    ROUND(SUM(f.spend_usd) / NULLIF(SUM(fsv.attributed_visits), 0), 2) AS cost_per_visit
FROM fact_daily_performance AS f
JOIN dim_campaign AS dc 
    ON f.campaign_id = dc.campaign_id
JOIN fact_store_visits AS fsv 
    ON f.date = fsv.date
    AND (dc.region = 'National' OR dc.region = fsv.mapped_region)
WHERE fsv.is_zero_filled = 0
GROUP BY strftime('%Y-W%W', f.date), dc.region
ORDER BY week, campaign_region;


-- Answer: 
-- Cost per store visit ranges from $2.61 to $4.63. 
-- Efficient spend-to-visit relationship, with Q1 showing lower cost per visit.

