-- ANALYSIS QUERIES
-- Business questions answered using gold layer
-- ----------------------------------------------------------------------------


-- QUERY 1: Blended CPA by brand and month, across both platforms
SELECT
    dc.brand,
    dd.year,
    dd.month,
    dd.month_name,
    ROUND(SUM(f.spend_usd) / NULLIF(SUM(f.conversions), 0), 2) AS blended_cpa,
    ROUND(SUM(f.spend_usd), 2) AS total_spend,
    ROUND(SUM(f.conversions), 2) AS total_conversions
FROM fact_daily_performance AS f
JOIN dim_campaign AS dc 
    ON f.campaign_id = dc.campaign_id
JOIN dim_date AS dd 
    ON f.date = dd.date
GROUP BY dc.brand, dd.year, dd.month, dd.month_name
ORDER BY dd.year, dd.month;



-- QUERY 2: Campaigns with highest week-over-week spend growth (top 10)
-- Most recent 4 weeks of data
WITH weekly_spend AS (
    SELECT
        f.campaign_id,
        dc.campaign_name_standardized,
        strftime('%Y-%W', f.date) AS week,
        SUM(f.spend_usd) AS weekly_spend
    FROM fact_daily_performance AS f
    JOIN dim_campaign AS dc 
        ON f.campaign_id = dc.campaign_id
    WHERE f.date >= DATE((SELECT MAX(date) FROM fact_daily_performance), '-28 days')
    GROUP BY f.campaign_id, dc.campaign_name_standardized, strftime('%Y-%W', f.date)
),
spend_with_growth AS (
    SELECT
        campaign_id,
        campaign_name_standardized,
        week,
        weekly_spend,
        LAG(weekly_spend) OVER (PARTITION BY campaign_id ORDER BY week) AS prev_week_spend,
        CASE 
            WHEN LAG(weekly_spend) OVER (PARTITION BY campaign_id ORDER BY week) IS NULL 
                 OR LAG(weekly_spend) OVER (PARTITION BY campaign_id ORDER BY week) = 0
            THEN NULL
            ELSE ROUND(((weekly_spend - LAG(weekly_spend) OVER (PARTITION BY campaign_id ORDER BY week)) 
                  / LAG(weekly_spend) OVER (PARTITION BY campaign_id ORDER BY week)) * 100, 2)
        END AS week_over_week_growth_pct
    FROM weekly_spend
)
SELECT
    campaign_id,
    campaign_name_standardized,
    week,
    ROUND(weekly_spend, 2) AS weekly_spend_usd,
    ROUND(prev_week_spend, 2) AS prev_week_spend_usd,
    week_over_week_growth_pct
FROM spend_with_growth
WHERE week_over_week_growth_pct IS NOT NULL
ORDER BY week_over_week_growth_pct DESC
LIMIT 10;



-- QUERY 3: Relationship between weekly spend and attributed store visits
-- Campaigns in DMAs with store visit data
SELECT
    strftime('%Y-%W', f.date) AS week,
    ROUND(SUM(f.spend_usd), 2) AS total_spend_usd,
    SUM(fsv.attributed_visits) AS total_store_visits,
    ROUND(SUM(f.spend_usd) / NULLIF(SUM(fsv.attributed_visits), 0), 2) AS cost_per_visit
FROM fact_daily_performance AS f
JOIN dim_campaign AS dc 
    ON f.campaign_id = dc.campaign_id
JOIN fact_store_visits AS fsv 
    ON f.date = fsv.date
WHERE dc.region != 'National'  -- Only campaigns with regional targeting
GROUP BY strftime('%Y-%W', f.date)
ORDER BY week;


-- Query 3: Spend vs Store Visits (with DMA mapping)
SELECT
    strftime('%Y-%W', f.date) AS week,
    dc.region AS campaign_region,
    ROUND(SUM(f.spend_usd), 2) AS total_spend_usd,
    SUM(fsv.attributed_visits) AS total_store_visits,
    ROUND(SUM(f.spend_usd) / NULLIF(SUM(fsv.attributed_visits), 0), 2) AS cost_per_visit
FROM fact_daily_performance f
JOIN dim_campaign dc ON f.campaign_id = dc.campaign_id
JOIN fact_store_visits fsv ON f.date = fsv.date
    AND (dc.region = 'National' OR dc.region = fsv.mapped_region)
GROUP BY strftime('%Y-%W', f.date), dc.region
ORDER BY week, campaign_region;



-- QUERY 4: Flag campaigns where reported spend exceeded budget
SELECT
    dc.campaign_id,
    dc.campaign_name_standardized,
    dc.brand,
    ROUND(SUM(f.spend_usd), 2) AS total_spend_usd,
    cm.budget_usd,
    CASE
        WHEN cm.budget_usd IS NULL THEN 'NO BUDGET'
        WHEN SUM(f.spend_usd) > cm.budget_usd THEN 'OVER BUDGET'
        ELSE 'WITHIN BUDGET'
    END AS budget_status,
    ROUND(SUM(f.spend_usd) - cm.budget_usd, 2) AS over_budget_amount
FROM fact_daily_performance f
JOIN dim_campaign AS dc 
    ON f.campaign_id = dc.campaign_id
LEFT JOIN raw_campaign_metadata AS cm 
    ON f.campaign_id = cm.campaign_id
GROUP BY dc.campaign_id, dc.campaign_name_standardized, dc.brand, cm.budget_usd
HAVING budget_status = 'OVER BUDGET'
ORDER BY over_budget_amount DESC;
