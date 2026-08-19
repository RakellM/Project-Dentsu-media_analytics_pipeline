"""
Extraction layer for raw data files.
Reads each source format and returns standardized Python data structures.
No cleaning or transformation happens here, that's the transform layer's job.
"""

# %%
import csv
import json
from pathlib import Path
from typing import List, Dict, Any
import logging

from config import (
    META_ADS_FILE,
    GOOGLE_ADS_FILE,
    STORE_VISITS_FILE,
    CAMPAIGN_METADATA_FILE,
)

logger = logging.getLogger(__name__)

# %%
def extract_meta_ads(file_path: Path = META_ADS_FILE) -> List[Dict[str, Any]]:
    """
    Extract Meta Ads daily performance data from CSV.
    
    Columns: date, timestamp_pst, campaign_id, campaign_name, adset_id, ad_id,
             objective, placement, impressions, clicks, spend_usd, currency,
             conversions, conversion_value_usd
    """
    logger.info(f"Extracting Meta Ads data from {file_path}")
    
    if not file_path.exists():
        raise FileNotFoundError(f"Meta Ads file not found: {file_path}")
    
    records = []
    with open(file_path, "r", newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            records.append(dict(row))
    
    logger.info(f"Extracted {len(records)} rows from Meta Ads")
    return records


#%%
def extract_google_ads(file_path: Path = GOOGLE_ADS_FILE) -> List[Dict[str, Any]]:
    """
    Extract Google Ads daily performance data from newline-delimited JSON.
    Flattens nested campaign and metrics objects.
    """
    logger.info(f"Extracting Google Ads data from {file_path}")
    
    if not file_path.exists():
        raise FileNotFoundError(f"Google Ads file not found: {file_path}")
    
    records = []
    with open(file_path, "r", encoding="utf-8") as f:
        for line_num, line in enumerate(f, 1):
            if line.strip():
                try:
                    data = json.loads(line)
                    flat_record = _flatten_google_record(data)
                    records.append(flat_record)
                except json.JSONDecodeError as e:
                    logger.warning(f"Failed to parse line {line_num}: {e}")
                    continue
    
    logger.info(f"Extracted {len(records)} rows from Google Ads")
    return records


# %%
def _flatten_google_record(record: Dict[str, Any]) -> Dict[str, Any]:
    """
    Flatten nested Google Ads JSON into a flat dictionary.
    
    Input: {
        "date": "2026-01-13",
        "timestamp_utc": "2026-01-13T00:00:00Z",
        "campaign": {"id": "1064", "name": "...", "advertising_channel_type": "YOUTUBE"},
        "metrics": {"impressions": 59373, "clicks": 1192, "cost_micros": 3067393584, ...}
    }
    
    Output: {
        "date": "2026-01-13",
        "timestamp_utc": "2026-01-13T00:00:00Z",
        "campaign_id": "1064",
        "campaign_name": "...",
        "advertising_channel_type": "YOUTUBE",
        "impressions": 59373,
        "clicks": 1192,
        "cost_micros": 3067393584,
        "conversions": 66.82,
        "conversions_value_micros": 9190143921
    }
    """
    flat = {}
    
    # Top-level fields
    for key in ["date", "timestamp_utc"]:
        if key in record:
            flat[key] = record[key]
    
    # Flatten campaign object
    if "campaign" in record and isinstance(record["campaign"], dict):
        campaign = record["campaign"]
        if "id" in campaign:
            flat["campaign_id"] = campaign["id"]
        if "name" in campaign:
            flat["campaign_name"] = campaign["name"]
        if "advertising_channel_type" in campaign:
            flat["advertising_channel_type"] = campaign["advertising_channel_type"]
    
    # Flatten metrics object
    if "metrics" in record and isinstance(record["metrics"], dict):
        for key, value in record["metrics"].items():
            flat[key] = value
    
    return flat


# %%
def extract_store_visits(file_path: Path = STORE_VISITS_FILE) -> List[Dict[str, Any]]:
    """
    Extract store visits data from CSV.
    
    Columns: date, dma_code, dma_name, attributed_visits, attribution_window_days
    """
    logger.info(f"Extracting store visits data from {file_path}")
    
    if not file_path.exists():
        raise FileNotFoundError(f"Store visits file not found: {file_path}")
    
    records = []
    with open(file_path, "r", newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            records.append(dict(row))
    
    logger.info(f"Extracted {len(records)} rows from store visits")
    return records


# %%
def extract_campaign_metadata(file_path: Path = CAMPAIGN_METADATA_FILE) -> List[Dict[str, Any]]:
    """
    Extract campaign metadata from CSV.
    
    Columns: campaign_id, brand, product_line, region, 
             campaign_start_date, campaign_end_date, budget_usd
    """
    logger.info(f"Extracting campaign metadata from {file_path}")
    
    if not file_path.exists():
        raise FileNotFoundError(f"Campaign metadata file not found: {file_path}")
    
    records = []
    with open(file_path, "r", newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            records.append(dict(row))
    
    logger.info(f"Extracted {len(records)} rows from campaign metadata")
    return records


# %%
def extract_all() -> Dict[str, List[Dict[str, Any]]]:
    """
    Extract all data sources in one call.
    
    Returns:
        Dictionary with keys: meta_ads, google_ads, store_visits, campaign_metadata
        Each value is a list of dictionaries (raw rows)
    """
    logger.info("Starting full data extraction from all sources")
    
    return {
        "meta_ads": extract_meta_ads(),
        "google_ads": extract_google_ads(),
        "store_visits": extract_store_visits(),
        "campaign_metadata": extract_campaign_metadata(),
    }


# %%
def get_row_counts(data: Dict[str, List[Dict[str, Any]]]) -> Dict[str, int]:
    """
    Get row counts for each dataset.
    Useful for logging and data quality checks.
    """
    return {key: len(value) for key, value in data.items()}

# %%
