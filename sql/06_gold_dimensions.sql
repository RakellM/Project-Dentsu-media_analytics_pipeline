-- GOLD: Dimension Tables
-------------------------------------------------------------------------------

-- Campaign Dimension (attributes only)
CREATE TABLE IF NOT EXISTS dim_campaign AS
SELECT
    campaign_id,
    brand,
    product_line,
    region, 
    campaign_name_standardized
FROM ref_campaign_list;


-- DMA Dimension
CREATE TABLE IF NOT EXISTS dim_dma AS
SELECT
    dma_code,
    dma_name
FROM ref_dma_list;


-- Date Dimension
CREATE TABLE IF NOT EXISTS dim_date AS
SELECT
    date,
    year,
    month,
    month_name,
    day_of_week,
    is_weekend
FROM ref_calendar;
