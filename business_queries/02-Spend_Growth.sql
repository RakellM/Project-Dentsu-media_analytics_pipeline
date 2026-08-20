-- Query 2: Week-over-Week Spend Growth (Top 10)

WITH weekly_spend AS (
    SELECT
        f.campaign_id,
        dc.campaign_name_standardized,
        strftime('%Y-W%W', f.date) AS week,
        MIN(f.date) AS week_start,
        MAX(f.date) AS week_end,
        SUM(f.spend_usd) AS weekly_spend
    FROM fact_daily_performance AS f
    JOIN dim_campaign AS dc 
        ON f.campaign_id = dc.campaign_id
    WHERE f.date >= DATE((SELECT MAX(date) FROM fact_daily_performance), '-28 days')
    GROUP BY f.campaign_id, dc.campaign_name_standardized, strftime('%Y-w%W', f.date)
),
spend_with_growth AS (
    SELECT
        campaign_id,
        campaign_name_standardized,
        week,
        week_start,
        week_end,
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
    week_start || ' to ' || week_end AS week_range,
    ROUND(weekly_spend, 2) AS weekly_spend_usd,
    ROUND(prev_week_spend, 2) AS prev_week_spend_usd,
    week_over_week_growth_pct
FROM spend_with_growth
WHERE week_over_week_growth_pct IS NOT NULL
ORDER BY week_over_week_growth_pct DESC
LIMIT 10;


-- Answer:
-- Top growth campaign: HomeBase_Seasonal_National (1033) with +67.03% WoW growth in week 23.

