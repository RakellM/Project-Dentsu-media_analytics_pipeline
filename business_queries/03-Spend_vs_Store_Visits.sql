-- Query 3: Spend vs Store Visits (with DMA mapping)

WITH visit_totals AS (
    -- Actual (non-zero-filled) visits, summed per week per DMA region
    SELECT
        strftime('%Y-W%W', fsv.date) AS week,
        fsv.mapped_region,
        SUM(fsv.attributed_visits) AS visits
    FROM fact_store_visits AS fsv
    WHERE fsv.is_zero_filled = 0
    GROUP BY week, fsv.mapped_region
),

campaign_regions AS (
    SELECT DISTINCT region FROM dim_campaign
),

visits_by_campaign_region AS (
    -- For each campaign-targeting region (National/East/West), sum the visits
    -- from the DMA regions that region actually targets. National sums
    -- East + West; East/West sum only their own matching region. Each row on
    -- the right (visit_totals) is already fully aggregated, so summing across
    -- matches here does not re-inflate by DMA count.
    SELECT
        vt.week,
        cr.region AS campaign_region,
        SUM(vt.visits) AS total_store_visits
    FROM campaign_regions AS cr
    JOIN visit_totals AS vt
        ON (cr.region = 'National' OR cr.region = vt.mapped_region)
    GROUP BY vt.week, cr.region
),

spend_by_campaign_region AS (
    SELECT
        strftime('%Y-W%W', f.date) AS week,
        date(f.date, '-' || ((strftime('%w', f.date) + 6) % 7) || ' days') AS week_start,
        dc.region AS campaign_region,
        SUM(f.spend_usd) AS total_spend_usd
    FROM fact_daily_performance AS f
    JOIN dim_campaign AS dc
        ON f.campaign_id = dc.campaign_id
    GROUP BY
        strftime('%Y-W%W', f.date),
        date(f.date, '-' || ((strftime('%w', f.date) + 6) % 7) || ' days'),
        dc.region
)

SELECT
    s.week,
    s.week_start,
    s.campaign_region,
    ROUND(s.total_spend_usd, 2) AS total_spend_usd,
    v.total_store_visits,
    ROUND(s.total_spend_usd / NULLIF(v.total_store_visits, 0), 2) AS cost_per_visit
FROM spend_by_campaign_region AS s
LEFT JOIN visits_by_campaign_region AS v
    ON s.week = v.week
    AND s.campaign_region = v.campaign_region
ORDER BY s.week, s.campaign_region;


-- Answer
-- $0.38–$11 range 
