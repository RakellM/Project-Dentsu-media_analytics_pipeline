-- SILVER: Store Visits with missing dates filled
--------------------------------------------------------------------------------

-- Cross joins calendar with DMA list, fills gaps with zero
CREATE TABLE IF NOT EXISTS stg_store_visits (
    date TEXT,
    dma_code TEXT,
    dma_name TEXT,
    attributed_visits INTEGER,
    attribution_window_days INTEGER,
    is_zero_filled INTEGER DEFAULT 0,
    _load_timestamp TEXT,
    _staged_timestamp TEXT DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (date, dma_code)
);

-- Initialize tracking
INSERT OR IGNORE INTO _pipeline_tracking (table_name, last_processed_load_timestamp)
VALUES ('stg_store_visits', '1900-01-01');

-- Insert actual records + zero-filled gaps
INSERT OR REPLACE INTO stg_store_visits
SELECT
    c.date,
    dma.dma_code,
    dma.dma_name,
    COALESCE(sv.attributed_visits, 0) AS attributed_visits,
    COALESCE(sv.attribution_window_days, 0) AS attribution_window_days,
    CASE WHEN sv.date IS NULL THEN 1 ELSE 0 END AS is_zero_filled,
    COALESCE(sv._load_timestamp, c.date || ' 00:00:00') AS _load_timestamp,
    CURRENT_TIMESTAMP AS _staged_timestamp
FROM ref_calendar c
CROSS JOIN ref_dma_list dma
LEFT JOIN raw_store_visits sv
    ON c.date = sv.date
    AND dma.dma_code = sv.dma_code
WHERE c.date BETWEEN (
    SELECT MIN(date) FROM raw_store_visits
) AND (
    SELECT MAX(date) FROM raw_store_visits
);

-- Update tracking
UPDATE _pipeline_tracking
SET last_processed_load_timestamp = (
    SELECT MAX(_load_timestamp) FROM stg_store_visits
)
WHERE table_name = 'stg_store_visits';
