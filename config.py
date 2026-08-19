# %%
"""
Configuration settings for the pipeline.
Centralizes file paths, constants, and business rules.
"""

# %%
from pathlib import Path
import logging

# %%
# Base paths
BASE_DIR = Path(__file__).parent
DATA_DIR = BASE_DIR / "data"
RAW_DIR = DATA_DIR / "raw"
STAGED_DIR = DATA_DIR / "staged"
DB_PATH = DATA_DIR / "pipeline.db"
LOGS_DIR = BASE_DIR / "logs"
OUTPUTS_DIR = BASE_DIR / "outputs"

# Ensure directories exist
for dir_path in [DATA_DIR, RAW_DIR, STAGED_DIR, LOGS_DIR, OUTPUTS_DIR]:
    dir_path.mkdir(parents=True, exist_ok=True)

# Source files
META_ADS_FILE = RAW_DIR / "meta_ads_daily.csv"
GOOGLE_ADS_FILE = RAW_DIR / "google_ads_daily.json"
STORE_VISITS_FILE = RAW_DIR / "store_visits.csv"
CAMPAIGN_METADATA_FILE = RAW_DIR / "campaign_metadata.csv"

# Database settings
DB_TIMEOUT = 30  # seconds

# Business rules
MICROS_TO_USD = 1_000_000  # Google Ads micros to dollars conversion

# Timezone handling
TARGET_TIMEZONE = "UTC"
META_SOURCE_TIMEZONE = "America/Los_Angeles"  # PST/PDT
GOOGLE_SOURCE_TIMEZONE = "UTC"

# Data quality thresholds
MIN_ROWS_EXPECTED = 10
DUPLICATE_TOLERANCE = 0.01  # 1% tolerance for near-duplicates

# Logging configuration
LOG_LEVEL = logging.INFO
LOG_FORMAT = "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
LOG_FILE = LOGS_DIR / "pipeline_run.log"

# Output files
ANSWERS_OUTPUT = OUTPUTS_DIR / "answers.md"

# %%

