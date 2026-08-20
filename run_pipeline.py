"""
Main pipeline orchestrator.
Runs extraction, transformation, loading, and SQL transforms.
"""

import logging
import sys
from pathlib import Path

# Add project root to path
sys.path.append(str(Path(__file__).parent))

from config import (
    DB_PATH,
    LOGS_DIR,
    LOG_LEVEL,
    LOG_FORMAT,
    LOG_FILE,
)
from src.extract import extract_all, get_row_counts
from src.transform import transform_all
from src.load import load_all, get_connection

# Configure logging
logging.basicConfig(
    level=LOG_LEVEL,
    format=LOG_FORMAT,
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(LOG_FILE),
    ],
)
logger = logging.getLogger(__name__)


def execute_sql_file(conn, file_path: str) -> None:
    """Execute a SQL script from file."""
    logger.info(f"Executing SQL: {file_path}")
    
    with open(file_path, "r") as f:
        script = f.read()
    
    conn.executescript(script)
    conn.commit()
    logger.info(f"Completed SQL: {file_path}")


def run_sql_transforms(conn) -> None:
    """Run all SQL transformation scripts in order."""
    sql_files = [
        "sql/01_reference_tables.sql",
        "sql/02_silver_meta_ads.sql",
        "sql/03_silver_google_ads.sql",
        "sql/04_silver_unified.sql",
        "sql/05_silver_store_visits.sql",
        "sql/06_gold_dimensions.sql",
        "sql/07_gold_facts.sql",
        "sql/08_log_campaign_name_changes.sql",
    ]
    
    for file_path in sql_files:
        if Path(file_path).exists():
            execute_sql_file(conn, file_path)
        else:
            logger.warning(f"SQL file not found: {file_path}")


def run_validation(conn) -> None:
    """Run data quality validation checks."""
    logger.info("Running validation checks")
    
    # Check table counts
    tables = [
        "raw_meta_ads",
        "raw_google_ads",
        "raw_store_visits",
        "raw_campaign_metadata",
        "stg_meta_ads",
        "stg_google_ads",
        "stg_daily_performance",
        "stg_store_visits",
        "dim_campaign",
        "dim_dma",
        "dim_date",
        "fact_daily_performance",
        "fact_store_visits",
    ]
    
    for table in tables:
        cursor = conn.execute(f"SELECT COUNT(*) FROM {table}")
        count = cursor.fetchone()[0]
        logger.info(f"  {table}: {count} rows")
    
    # Check for null spend in fact table
    cursor = conn.execute("""
        SELECT COUNT(*) FROM fact_daily_performance 
        WHERE spend_usd IS NULL OR spend_usd < 0
    """)
    null_spend = cursor.fetchone()[0]
    
    if null_spend > 0:
        logger.warning(f" [ATTENTION] Found {null_spend} records with null/negative spend")
    else:
        logger.info(" [OK] No null or negative spend values")


def run_pipeline() -> None:
    """Run the full pipeline end-to-end."""
    logger.info("===> STARTING MEDIA ANALYTICS PIPELINE")
    
    try:
        # 1. Extract
        logger.info("\n[STEP 1] EXTRACTION")
        raw_data = extract_all()
        counts = get_row_counts(raw_data)
        logger.info(f"  Extracted: {counts}")
        
        # 2. Transform
        logger.info("\n[STEP 2] TRANSFORMATION")
        transformed_data = transform_all(raw_data)
        counts = get_row_counts(transformed_data)
        logger.info(f"  Transformed: {counts}")
        
        # 3. Load
        logger.info("\n[STEP 3] LOADING TO SQLITE")
        load_results = load_all(transformed_data)
        logger.info(f"  Load results: {load_results}")
        
        # 4. SQL Transforms
        logger.info("\n[STEP 4] SQL TRANSFORMATIONS")
        with get_connection() as conn:
            run_sql_transforms(conn)
        
        # 5. Validation
        logger.info("\n[STEP 5] VALIDATION")
        with get_connection() as conn:
            run_validation(conn)
        
        logger.info("\n")
        logger.info("===> PIPELINE COMPLETE")
          
    except Exception as e:
        logger.error(f"Pipeline failed: {e}", exc_info=True)
        sys.exit(1)


if __name__ == "__main__":
    run_pipeline()

