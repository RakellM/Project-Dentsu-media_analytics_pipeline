-- Query 4: Campaigns Exceeding Budget

-- Ignore Campaign when budget is missing
-- WITH campaign_spend AS (
--     SELECT
--         f.campaign_id,
--         dc.campaign_name_standardized,
--         dc.brand,
--         ROUND(SUM(f.spend_usd), 2) AS total_spend_usd,
--         COUNT(DISTINCT f.date) AS days_active
--     FROM fact_daily_performance AS f
--     JOIN dim_campaign AS dc 
--         ON f.campaign_id = dc.campaign_id
--     GROUP BY f.campaign_id, dc.campaign_name_standardized, dc.brand
-- )
-- SELECT
--     cs.campaign_id,
--     cs.campaign_name_standardized,
--     cs.brand,
--     cs.total_spend_usd,
--     cm.budget_usd,
--     cs.days_active,
--     CASE
--         WHEN cm.budget_usd IS NULL THEN 'NO BUDGET AVAILABLE'
--         WHEN cs.total_spend_usd > cm.budget_usd THEN 'OVER BUDGET'
--         ELSE 'WITHIN BUDGET'
--     END AS budget_status,
--     ROUND(cs.total_spend_usd - cm.budget_usd, 2) AS over_budget_amount,
--     ROUND((cs.total_spend_usd / cm.budget_usd) * 100, 1) AS pct_of_budget
-- FROM campaign_spend AS cs
-- LEFT JOIN raw_campaign_metadata AS cm 
--     ON cs.campaign_id = cm.campaign_id
-- WHERE cm.budget_usd IS NOT NULL
-- ORDER BY over_budget_amount DESC;


-- Answer: 
-- 13 of 15 campaigns with budgets are over budget. 
-- Highest: Campaign 1267 at 483% of budget ($645K vs $133K). 
-- This suggests budget_usd may be a monthly allocation, not total campaign budget.




-- Estimate missing budgets
-- Average budget by product_line and region (from campaigns WITH budget)
-- WITH budget_averages AS (
--     SELECT
--         product_line,
--         region,
--         ROUND(AVG(CAST(budget_usd AS REAL)), 2) AS avg_budget
--     FROM raw_campaign_metadata
--     WHERE budget_usd IS NOT NULL
--         AND budget_usd != ''
--     GROUP BY product_line, region
-- ),
-- campaign_with_budget AS (
--     SELECT
--         cm.campaign_id,
--         cm.brand,
--         cm.product_line,
--         cm.region,
--         CASE
--             WHEN cm.budget_usd IS NULL OR cm.budget_usd = '' THEN ba.avg_budget
--             ELSE CAST(cm.budget_usd AS REAL)
--         END AS budget_usd,
--         CASE
--             WHEN cm.budget_usd IS NULL OR cm.budget_usd = '' THEN 'ESTIMATED'
--             ELSE 'ACTUAL'
--         END AS budget_source
--     FROM raw_campaign_metadata AS cm
--     LEFT JOIN budget_averages AS ba
--         ON cm.product_line = ba.product_line
--         AND cm.region = ba.region
-- ),
-- campaign_spend AS (
--     SELECT
--         f.campaign_id,
--         SUM(f.spend_usd) AS total_spend_usd
--     FROM fact_daily_performance AS f
--     GROUP BY f.campaign_id
-- )
-- SELECT
--     cb.campaign_id,
--     cb.brand,
--     cb.product_line,
--     cb.region,
--     ROUND(cs.total_spend_usd, 2) AS total_spend_usd,
--     cb.budget_usd,
--     cb.budget_source,
--     CASE
--         WHEN cs.total_spend_usd > cb.budget_usd THEN 'OVER BUDGET'
--         ELSE 'WITHIN BUDGET'
--     END AS budget_status,
--     ROUND(cs.total_spend_usd - cb.budget_usd, 2) AS over_budget_amount
-- FROM campaign_with_budget AS cb
-- LEFT JOIN campaign_spend AS cs 
--     ON cb.campaign_id = cs.campaign_id
-- ORDER BY over_budget_amount DESC;


-- Missing budgets estimated using daily spend rate × campaign duration
-- Calculates daily spend rate for campaigns WITH actual budgets
-- Averages the daily rate by product_line + region
-- Estimates missing budgets = daily rate × campaign duration
-- Combines actual + estimated into one table
-- Compares total spend against budget
-- Flags over budget with amount and percentage


WITH campaign_daily_spend AS (
    -- Calculate daily average spend for campaigns WITH actual budgets
    SELECT
        cm.campaign_id,
        cm.product_line,
        cm.region,
        SUM(f.spend_usd) / COUNT(DISTINCT f.date) AS daily_avg_spend
    FROM raw_campaign_metadata AS cm
    JOIN fact_daily_performance AS f
        ON cm.campaign_id = f.campaign_id
    WHERE cm.budget_usd IS NOT NULL AND cm.budget_usd != ''
    GROUP BY cm.campaign_id, cm.product_line, cm.region
),

product_daily_rate AS (
    -- Average daily spend rate by product_line + region
    SELECT
        product_line,
        region,
        ROUND(AVG(daily_avg_spend), 2) AS avg_daily_rate,
        COUNT(*) AS campaign_count
    FROM campaign_daily_spend
    GROUP BY product_line, region
),

campaign_duration AS (
    -- Campaign duration in days
    SELECT
        campaign_id,
        CAST(julianday(campaign_end_date) - julianday(campaign_start_date) AS INTEGER) AS duration_days
    FROM raw_campaign_metadata
),

campaign_budgets AS (
    -- Actual budgets
    SELECT
        cm.campaign_id,
        cm.product_line,
        cm.region,
        CAST(cm.budget_usd AS REAL) AS budget_usd,
        'ACTUAL' AS budget_source
    FROM raw_campaign_metadata cm
    WHERE cm.budget_usd IS NOT NULL AND cm.budget_usd != ''
    
    UNION ALL
    
    -- Estimated budgets (daily rate × duration)
    SELECT
        cm.campaign_id,
        cm.product_line,
        cm.region,
        ROUND(pdr.avg_daily_rate * cd.duration_days, 2) AS budget_usd,
        'ESTIMATED' AS budget_source
    FROM raw_campaign_metadata AS cm
    JOIN product_daily_rate AS pdr
        ON cm.product_line = pdr.product_line
        AND cm.region = pdr.region
    JOIN campaign_duration AS cd 
        ON cm.campaign_id = cd.campaign_id
    WHERE cm.budget_usd IS NULL OR cm.budget_usd = ''
),

campaign_spend AS (
    -- Total spend per campaign
    SELECT
        f.campaign_id,
        SUM(f.spend_usd) AS total_spend_usd,
        COUNT(DISTINCT f.date) AS days_active
    FROM fact_daily_performance AS f
    GROUP BY f.campaign_id
)

-- Final answer
SELECT
    cb.campaign_id,
    dc.campaign_name_standardized,
    dc.brand,
    cb.product_line,
    cb.region,
    ROUND(cs.total_spend_usd, 2) AS total_spend_usd,
    cb.budget_usd,
    cb.budget_source,
    cs.days_active,
    CASE
        WHEN cs.total_spend_usd > cb.budget_usd THEN 'OVER BUDGET'
        ELSE 'WITHIN BUDGET'
    END AS budget_status,
    ROUND(cs.total_spend_usd - cb.budget_usd, 2) AS over_budget_amount,
    ROUND((cs.total_spend_usd / cb.budget_usd) * 100, 1) AS pct_of_budget
FROM campaign_budgets AS cb
JOIN dim_campaign AS dc 
    ON cb.campaign_id = dc.campaign_id
LEFT JOIN campaign_spend AS cs 
    ON cb.campaign_id = cs.campaign_id
WHERE cs.total_spend_usd IS NOT NULL
ORDER BY over_budget_amount DESC;

-- Answer:
-- 15 campaigns over budget (68% of 22 analyzed)
-- Highest overage: Campaign 1090 at 1156% of budget ($427K vs $37K)
-- 2 campaigns excluded due to no spend data (1156, 1251)
-- 7 campaigns within budget (5 of these have estimated budgets)
