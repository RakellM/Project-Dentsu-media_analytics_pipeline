"""
Transform layer for media analytics pipeline.

Performs light cleaning and type coercion before loading to SQLite.
Heavy transformation (unification, aggregation) happens in SQL.

Handles:
- Type conversion (text to numeric)
- Timestamp conversion (PST → UTC)
- Data quality flags (missing currency, missing budget)
- Platform tagging
- Google deduplication (export bug)

Deferred to SQL silver layer:
- Currency conversion (CAD/GBP → USD via exchange rate table)
- Micros conversion (micros → dollars)
- Campaign name resolution
"""

# %%
import logging
from typing import List, Dict, Any
from datetime import datetime, timedelta

logger = logging.getLogger(__name__)


# %%
#---------- CAMPAIGN_METADATA
def transform_campaign_metadata(records: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    Clean campaign metadata records before load for bronze layer.
    
    Handles:
    - Strip whitespace from text fields
    - Convert budget_usd from string to float
    - Flag campaigns with missing budget
    """
    logger.info(f"Transforming {len(records)} campaign metadata records")
    
    cleaned = []
    for r in records:
        # Text fields: strip whitespace
        campaign_id = r["campaign_id"].strip()
        brand = r["brand"].strip()
        product_line = r["product_line"].strip()
        region = r["region"].strip()
        start_date = r["campaign_start_date"].strip()
        end_date = r["campaign_end_date"].strip()
        
        # Budget: handle empty/missing
        budget_raw = r.get("budget_usd", "").strip()
        
        if budget_raw:
            budget_usd = float(budget_raw)
            budget_available = 1  # True
        else:
            budget_usd = None
            budget_available = 0  # False
            logger.debug(f"Campaign {campaign_id} has no budget")
        
        clean = {
            "campaign_id": campaign_id,
            "brand": brand,
            "product_line": product_line,
            "region": region,
            "campaign_start_date": start_date,
            "campaign_end_date": end_date,
            "budget_usd": budget_usd,
            "budget_available": budget_available,
        }
        
        cleaned.append(clean)
    
    logger.info(f"Transformed {len(cleaned)} campaign metadata records")
    return cleaned


# %%
#---------- STORE_VISITS
def transform_store_visits(records: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    Clean store visits records before load for bronze layer.
    
    Handles:
    - Strip whitespace from text fields
    - Convert attributed_visits from string to integer
    - Convert attribution_window_days from string to integer
    """
    logger.info(f"Transforming {len(records)} store visit records")
    
    cleaned = []
    for r in records:
        # Text fields: strip whitespace
        date = r["date"].strip()
        dma_code = r["dma_code"].strip()
        dma_name = r["dma_name"].strip()
        
        # Numeric fields: convert from string to int
        attributed_visits = int(r["attributed_visits"].strip())
        attribution_window_days = int(r["attribution_window_days"].strip())
        
        clean = {
            "date": date,
            "dma_code": dma_code,
            "dma_name": dma_name,
            "attributed_visits": attributed_visits,
            "attribution_window_days": attribution_window_days,
        }
        
        cleaned.append(clean)
    
    logger.info(f"Transformed {len(cleaned)} store visit records")
    return cleaned


# %% 
#---------- META_ADS
def _pst_to_utc(timestamp_str: str) -> str:
    """Convert PST timestamp to UTC (+8 hours, simplified)."""
    if not timestamp_str:
        return ""
    try:
        dt = datetime.fromisoformat(timestamp_str)
        dt_utc = dt + timedelta(hours=8)
        return dt_utc.strftime("%Y-%m-%d %H:%M:%S")
    except ValueError:
        return ""


def transform_meta_ads(records):
    """
    Clean Meta Ads records for bronze layer.
    
    Currency handling:
    - Empty currency: keep as NULL, flag as missing
    - CAD/GBP: keep original currency and amount
    - Missing currency will be assumed USD in SQL (documented)
    """
    logger.info(f"Transforming {len(records)} Meta Ads records")
    
    cleaned = []
    for r in records:
        # Dates
        date = r["date"].strip()
        timestamp_pst = r.get("timestamp_pst", "").strip()
        timestamp_utc = _pst_to_utc(timestamp_pst)
    
        # Currency: don't assume, flag instead
        currency_raw = r.get("currency", "").strip().upper()
        
        if currency_raw:
            original_currency = currency_raw
            currency_missing = 0
        else:
            original_currency = None  # Keep as NULL in raw
            currency_missing = 1
        
        clean = {
            "date": date,
            "timestamp_pst": timestamp_pst,
            "timestamp_utc": timestamp_utc,
            "campaign_id": r["campaign_id"].strip(),
            "campaign_name": r["campaign_name"].strip(),
            "adset_id": r.get("adset_id", "").strip(),
            "ad_id": r.get("ad_id", "").strip(),
            "objective": r.get("objective", "").strip(),
            "placement": r.get("placement", "").strip(),
            "impressions": int(r["impressions"].strip()),
            "clicks": int(r["clicks"].strip()),
            "spend_amount": float(r["spend_usd"].strip()),
            "original_currency": original_currency,  # NULL if missing
            "currency_missing": currency_missing,     # 1 if missing
            "conversions": float(r["conversions"].strip()) if r.get("conversions", "").strip() else 0.0,
            "conversion_value_amount": float(r["conversion_value_usd"].strip()) if r.get("conversion_value_usd", "").strip() else 0.0,
            "platform": "meta",
        }

        cleaned.append(clean)
    
    logger.info(f"Transformed {len(cleaned)} Meta Ads records")
    return cleaned


# %%
#---------- GOOGLE_ADS
def transform_google_ads(records: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    Clean Google Ads records for bronze layer.
    
    Currency:
    - Always USD (cost_micros and conversions_value_micros)
    - Keep micros as-is in bronze
    - Conversion to dollars happens in SQL silver layer
    
    Duplicates:
    - Same date + campaign_id can appear multiple times (export bug)
    - Handled HERE: metrics summed, flags added
    - duplicate_combined: 1 if merged, 0 if single
    - duplicate_count: number of records merged
    
    Conversions:
    - Fractional values (e.g., 66.82) keep as REAL
    """
    logger.info(f"Transforming {len(records)} Google Ads records")
    
    # Step 1: Clean and type each record
    cleaned = []
    for r in records:
        clean = {
            "date": r["date"].strip(),
            "timestamp_utc": r.get("timestamp_utc", "").strip(),
            "campaign_id": str(r["campaign_id"]).strip(),
            "campaign_name": r.get("campaign_name", "").strip(),
            "advertising_channel_type": r.get("advertising_channel_type", "").strip(),
            "impressions": int(r["impressions"]),
            "clicks": int(r["clicks"]),
            "cost_micros": int(r["cost_micros"]),
            "conversions": float(r["conversions"]),
            "conversions_value_micros": int(r["conversions_value_micros"]),
            "platform": "google",
        }
        cleaned.append(clean)
    
    # Step 2: Deduplicate
    deduplicated = _deduplicate_google_records(cleaned)
    
    logger.info(f"Transformed {len(cleaned)} Google Ads records → {len(deduplicated)} after deduplication")
    return deduplicated


def _deduplicate_google_records(records):
    """
    Deduplicate Google Ads records.
    
    Duplicate key: (date, campaign_id, campaign_name, advertising_channel_type)
    
    When duplicates found:
    1. Check timestamps:
       - If different → keep NEWEST timestamp
       - If same/missing → keep record with MAX impressions
    2. Flag as duplicate_combined
    3. Record duplicate_count
    """
    from collections import defaultdict
    
    grouped = defaultdict(list)
    for r in records:
        key = (
            r["date"],
            r["campaign_id"],
            r.get("campaign_name", ""),
            r.get("advertising_channel_type", ""),
        )
        grouped[key].append(r)
    
    result = []
    for key, group in grouped.items():
        if len(group) == 1:
            record = group[0].copy()
            record["duplicate_combined"] = 0
            record["duplicate_count"] = 1
            result.append(record)
        else:
            # Decide which record to keep
            best_record = _select_best_record(group)
            
            record = best_record.copy()
            record["duplicate_combined"] = 1
            record["duplicate_count"] = len(group)
            
            result.append(record)
            logger.debug(
                f"Duplicates for {key}: "
                f"timestamps={[r.get('timestamp_utc', '') for r in group]}, "
                f"impressions={[r['impressions'] for r in group]}, "
                f"kept impression={best_record['impressions']}"
            )
    
    return result


def _select_best_record(group: List[Dict[str, Any]]) -> Dict[str, Any]:
    """
    Select the best record from a group of duplicates.
    
    Priority:
    1. Newest timestamp (if timestamps differ)
    2. Max impressions (if timestamps are same or missing)
    """
    # Check if timestamps differ
    timestamps = [r.get("timestamp_utc", "") for r in group]
    unique_timestamps = set(timestamps)
    
    if len(unique_timestamps) > 1:
        # Timestamps differ: keep the newest
        best = max(group, key=lambda r: r.get("timestamp_utc", ""))
        logger.debug("Selected by newest timestamp")
        return best
    else:
        # Timestamps same or all missing: keep max impressions
        best = max(group, key=lambda r: r["impressions"])
        logger.debug("Selected by max impressions (timestamps identical)")
        return best


# %%
#---------- TRANSFORM ALL
def transform_all(extracted_data: Dict[str, List[Dict[str, Any]]]) -> Dict[str, List[Dict[str, Any]]]:
    """Transform all extracted data."""
    logger.info("Starting full transformation")
    
    return {
        "meta_ads": transform_meta_ads(extracted_data.get("meta_ads", [])),
        "google_ads": transform_google_ads(extracted_data.get("google_ads", [])),
        "store_visits": transform_store_visits(extracted_data.get("store_visits", [])),
        "campaign_metadata": transform_campaign_metadata(extracted_data.get("campaign_metadata", [])),
    }


# %%
