"""
Load layer for media analytics pipeline.

Loads transformed data into SQLite bronze tables.
Handles incremental loading via:
1. File metadata check — skip unchanged files
2. Primary key dedup — prevent duplicate rows

Tracks ingestion history in _ingestion_log table.

Raw tables preserve bronze-layer data:
- Original values where possible
- Added flags and derived columns from transform
- _load_timestamp for auditing
"""

# %%
import sqlite3
import logging
import os
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Any, Set, Tuple, Optional

from config import (
    DB_PATH,
    META_ADS_FILE,
    GOOGLE_ADS_FILE,
    STORE_VISITS_FILE,
    CAMPAIGN_METADATA_FILE,
)

logger = logging.getLogger(__name__)


# %%
#---------- CONNECTION
def get_connection(db_path: str = DB_PATH) -> sqlite3.Connection:
    """Create SQLite connection."""
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    return conn


# %%
#---------- FILE METADATA
def get_file_metadata(file_path: Path) -> Dict[str, Any]:
    """Get file metadata for change detection."""
    stat = file_path.stat()
    return {
        "file_name": file_path.name,
        "size_bytes": stat.st_size,
        "modified_time": datetime.fromtimestamp(stat.st_mtime).isoformat(),
    }


def create_ingestion_log(conn: sqlite3.Connection) -> None:
    """Create ingestion log table."""
    conn.execute("""
        CREATE TABLE IF NOT EXISTS _ingestion_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            source_file TEXT,
            ingested_at TEXT DEFAULT CURRENT_TIMESTAMP,
            file_size_bytes INTEGER,
            file_modified_time TEXT,
            records_loaded INTEGER,
            records_skipped INTEGER,
            status TEXT
        )
    """)
    conn.commit()


def get_last_ingestion(conn: sqlite3.Connection, source_file: str) -> Optional[Dict[str, Any]]:
    """Get last successful ingestion metadata for a file."""
    cursor = conn.execute("""
        SELECT file_size_bytes, file_modified_time
        FROM _ingestion_log
        WHERE source_file = ? AND status = 'success'
        ORDER BY ingested_at DESC
        LIMIT 1
    """, (source_file,))
    
    row = cursor.fetchone()
    if row:
        return {
            "size_bytes": row["file_size_bytes"],
            "modified_time": row["file_modified_time"],
        }
    return None


def should_skip_file(file_path: Path, conn: sqlite3.Connection) -> bool:
    """Check if file is unchanged since last ingestion."""
    last = get_last_ingestion(conn, file_path.name)
    if last is None:
        return False  # Never ingested
    
    current = get_file_metadata(file_path)
    
    # Skip if size AND modified time are unchanged
    return (
        current["size_bytes"] == last["size_bytes"] and
        current["modified_time"] == last["modified_time"]
    )


def log_ingestion(
    conn: sqlite3.Connection,
    source_file: str,
    file_metadata: Dict[str, Any],
    records_loaded: int,
    records_skipped: int,
    status: str,
) -> None:
    """Record ingestion attempt in log."""
    conn.execute("""
        INSERT INTO _ingestion_log (
            source_file, file_size_bytes, file_modified_time,
            records_loaded, records_skipped, status
        ) VALUES (?, ?, ?, ?, ?, ?)
    """, (
        source_file,
        file_metadata["size_bytes"],
        file_metadata["modified_time"],
        records_loaded,
        records_skipped,
        status,
    ))
    conn.commit()


# %%
#---------- TABLE CREATION
def create_raw_tables(conn: sqlite3.Connection) -> None:
    """Create bronze-layer tables with full grain primary keys."""
    
    conn.executescript("""
        -- Meta Ads bronze table
        -- Grain: one row per ad per day per objective per placement
        CREATE TABLE IF NOT EXISTS raw_meta_ads (
            date TEXT,
            timestamp_pst TEXT,
            timestamp_utc TEXT,
            campaign_id TEXT,
            campaign_name TEXT,
            adset_id TEXT,
            ad_id TEXT,
            objective TEXT,
            placement TEXT,
            impressions INTEGER,
            clicks INTEGER,
            spend_amount REAL,
            original_currency TEXT,
            currency_missing INTEGER,
            conversions REAL,
            conversion_value_amount REAL,
            platform TEXT,
            _load_timestamp TEXT DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (date, campaign_id, campaign_name, adset_id, ad_id, objective, placement)
        );

        -- Google Ads bronze table
        -- Grain: one row per campaign per day per channel
        CREATE TABLE IF NOT EXISTS raw_google_ads (
            date TEXT,
            timestamp_utc TEXT,
            campaign_id TEXT,
            campaign_name TEXT,
            advertising_channel_type TEXT,
            impressions INTEGER,
            clicks INTEGER,
            cost_micros INTEGER,
            conversions REAL,
            conversions_value_micros INTEGER,
            platform TEXT,
            duplicate_combined INTEGER DEFAULT 0,
            duplicate_count INTEGER DEFAULT 1,
            _load_timestamp TEXT DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (date, campaign_id, campaign_name, advertising_channel_type)
        );

        -- Store visits bronze table
        -- Grain: one row per DMA per day
        CREATE TABLE IF NOT EXISTS raw_store_visits (
            date TEXT,
            dma_code TEXT,
            dma_name TEXT,
            attributed_visits INTEGER,
            attribution_window_days INTEGER,
            _load_timestamp TEXT DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (date, dma_code)
        );

        -- Campaign metadata bronze table
        -- Grain: one row per campaign
        CREATE TABLE IF NOT EXISTS raw_campaign_metadata (
            campaign_id TEXT,
            brand TEXT,
            product_line TEXT,
            region TEXT,
            campaign_start_date TEXT,
            campaign_end_date TEXT,
            budget_usd REAL,
            budget_available INTEGER,
            _load_timestamp TEXT DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (campaign_id)
        );
    """)
    
    conn.commit()
    logger.info("Raw tables created/verified")


# %%
#---------- KEY MANAGEMENT
def _get_existing_keys(
    conn: sqlite3.Connection,
    table: str,
    key_columns: List[str],
) -> Set[Tuple[str, ...]]:
    """Get existing primary keys from a table."""
    cols = ", ".join(key_columns)
    cursor = conn.execute(f"SELECT {cols} FROM {table}")
    return {tuple(row) for row in cursor.fetchall()}


# %%
#---------- LOAD META_ADS
def load_meta_ads(conn: sqlite3.Connection, records: List[Dict[str, Any]]) -> Dict[str, int]:
    """Load Meta Ads records. Returns {inserted, skipped}."""
    
    existing = _get_existing_keys(
        conn, "raw_meta_ads",
        ["date", "campaign_id", "campaign_name", "adset_id", "ad_id", "objective", "placement"]
    )
    
    inserted = 0
    for r in records:
        key = (
            r["date"], r["campaign_id"], r["campaign_name"],
            r["adset_id"], r["ad_id"], r["objective"], r["placement"],
        )
        if key in existing:
            continue
        
        conn.execute("""
            INSERT OR IGNORE INTO raw_meta_ads (
                date, timestamp_pst, timestamp_utc, campaign_id, campaign_name,
                adset_id, ad_id, objective, placement, impressions, clicks,
                spend_amount, original_currency, currency_missing, conversions,
                conversion_value_amount, platform
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            r["date"], r["timestamp_pst"], r["timestamp_utc"], r["campaign_id"],
            r["campaign_name"], r["adset_id"], r["ad_id"], r["objective"],
            r["placement"], r["impressions"], r["clicks"], r["spend_amount"],
            r["original_currency"], r["currency_missing"], r["conversions"],
            r["conversion_value_amount"], r["platform"],
        ))
        existing.add(key)
        inserted += 1
    
    conn.commit()
    return {"inserted": inserted, "skipped": len(records) - inserted}


# %%
#---------- LOAD GOOGLE_ADS
def load_google_ads(conn: sqlite3.Connection, records: List[Dict[str, Any]]) -> Dict[str, int]:
    """Load Google Ads records. Returns {inserted, skipped}."""
    
    existing = _get_existing_keys(
        conn, "raw_google_ads",
        ["date", "campaign_id", "campaign_name", "advertising_channel_type"]
    )
    
    inserted = 0
    for r in records:
        key = (
            r["date"], r["campaign_id"],
            r["campaign_name"], r["advertising_channel_type"],
        )
        if key in existing:
            continue
        
        conn.execute("""
            INSERT OR IGNORE INTO raw_google_ads (
                date, timestamp_utc, campaign_id, campaign_name,
                advertising_channel_type, impressions, clicks,
                cost_micros, conversions, conversions_value_micros,
                platform, duplicate_combined, duplicate_count
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            r["date"], r["timestamp_utc"], r["campaign_id"], r["campaign_name"],
            r["advertising_channel_type"], r["impressions"], r["clicks"],
            r["cost_micros"], r["conversions"], r["conversions_value_micros"],
            r["platform"], r.get("duplicate_combined", 0), r.get("duplicate_count", 1),
        ))
        existing.add(key)
        inserted += 1
    
    conn.commit()
    return {"inserted": inserted, "skipped": len(records) - inserted}


# %%
#---------- LOAD STORE_VISITS
def load_store_visits(conn: sqlite3.Connection, records: List[Dict[str, Any]]) -> Dict[str, int]:
    """Load store visits records. Returns {inserted, skipped}."""
    
    existing = _get_existing_keys(conn, "raw_store_visits", ["date", "dma_code"])
    
    inserted = 0
    for r in records:
        key = (r["date"], r["dma_code"])
        if key in existing:
            continue
        
        conn.execute("""
            INSERT OR IGNORE INTO raw_store_visits (
                date, dma_code, dma_name, attributed_visits, attribution_window_days
            ) VALUES (?, ?, ?, ?, ?)
        """, (
            r["date"], r["dma_code"], r["dma_name"],
            r["attributed_visits"], r["attribution_window_days"],
        ))
        existing.add(key)
        inserted += 1
    
    conn.commit()
    return {"inserted": inserted, "skipped": len(records) - inserted}


# %%
#---------- CAMPAIGN_METADATA
def load_campaign_metadata(conn: sqlite3.Connection, records: List[Dict[str, Any]]) -> Dict[str, int]:
    """Load campaign metadata records. Returns {inserted, skipped}."""
    
    existing = _get_existing_keys(conn, "raw_campaign_metadata", ["campaign_id"])
    
    inserted = 0
    for r in records:
        key = (r["campaign_id"],)
        if key in existing:
            continue
        
        conn.execute("""
            INSERT OR IGNORE INTO raw_campaign_metadata (
                campaign_id, brand, product_line, region,
                campaign_start_date, campaign_end_date, budget_usd, budget_available
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            r["campaign_id"], r["brand"], r["product_line"], r["region"],
            r["campaign_start_date"], r["campaign_end_date"],
            r["budget_usd"], r["budget_available"],
        ))
        existing.add(key)
        inserted += 1
    
    conn.commit()
    return {"inserted": inserted, "skipped": len(records) - inserted}


# %%
#---------- ORCHESTRATION LOAD ALL
def load_all(transformed_data: Dict[str, List[Dict[str, Any]]]) -> Dict[str, Any]:
    """
    Load all transformed data into SQLite with file metadata check.
    
    Returns:
        Summary dict with per-source results and ingestion log info.
    """
    logger.info("Starting data load")
    
    results = {}
    
    with get_connection() as conn:
        create_raw_tables(conn)
        create_ingestion_log(conn)
        
        # Define source mapping
        sources = [
            {
                "key": "meta_ads",
                "file": META_ADS_FILE,
                "loader": load_meta_ads,
                "table": "raw_meta_ads",
            },
            {
                "key": "google_ads",
                "file": GOOGLE_ADS_FILE,
                "loader": load_google_ads,
                "table": "raw_google_ads",
            },
            {
                "key": "store_visits",
                "file": STORE_VISITS_FILE,
                "loader": load_store_visits,
                "table": "raw_store_visits",
            },
            {
                "key": "campaign_metadata",
                "file": CAMPAIGN_METADATA_FILE,
                "loader": load_campaign_metadata,
                "table": "raw_campaign_metadata",
            },
        ]
        
        for source in sources:
            key = source["key"]
            file_path = source["file"]
            records = transformed_data.get(key, [])
            
            if not records:
                logger.warning(f"  {key}: NO DATA — skipping")
                results[key] = {"status": "no_data", "inserted": 0, "skipped": 0}
                continue
            
            # File metadata check
            file_metadata = get_file_metadata(file_path)
            
            if should_skip_file(file_path, conn):
                logger.info(f"  {key}: FILE UNCHANGED — skipping")
                results[key] = {"status": "unchanged", "inserted": 0, "skipped": len(records)}
                continue
            
            # Load records
            load_result = source["loader"](conn, records)
            
            # Log ingestion
            log_ingestion(
                conn,
                source_file=file_path.name,
                file_metadata=file_metadata,
                records_loaded=load_result["inserted"],
                records_skipped=load_result["skipped"],
                status="success",
            )
            
            results[key] = {
                "status": "success",
                "inserted": load_result["inserted"],
                "skipped": load_result["skipped"],
            }
            
            logger.info(
                f"  {key}: {load_result['inserted']} new, "
                f"{load_result['skipped']} skipped"
            )
    
    logger.info(f"Load complete: {results}")
    return results


# %%
