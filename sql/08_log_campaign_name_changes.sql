-- LOG: Campaign Name History
-------------------------------------------------------------------------------

-- Tracks name changes over time for auditability
CREATE TABLE IF NOT EXISTS log_campaign_name_changes (
    campaign_id TEXT,
    campaign_name TEXT,
    platform TEXT,
    first_seen_date TEXT,
    last_seen_date TEXT,
    days_active INTEGER,
    is_current INTEGER DEFAULT 0,
    PRIMARY KEY (campaign_id, campaign_name, platform)
);

-- Insert name history from unified performance data
INSERT OR REPLACE INTO log_campaign_name_changes
SELECT
    campaign_id,
    campaign_name,
    platform,
    MIN(date) AS first_seen_date,
    MAX(date) AS last_seen_date,
    COUNT(DISTINCT date) AS days_active,
    0 AS is_current
FROM stg_daily_performance
WHERE campaign_name != ''
GROUP BY campaign_id, campaign_name, platform;

-- Mark the latest name as current for each campaign
UPDATE log_campaign_name_changes
SET is_current = 0;

UPDATE log_campaign_name_changes
SET is_current = 1
WHERE (campaign_id, last_seen_date) IN (
    SELECT campaign_id, MAX(last_seen_date)
    FROM log_campaign_name_changes
    GROUP BY campaign_id
);
