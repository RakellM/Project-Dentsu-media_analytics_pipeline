# Data Quality & Confidence Notes

## Overview

This document outlines all data integrity issues found during pipeline development, how each was resolved, and the confidence level stakeholders should have in each metric.

---

## Data Quality Issues Identified

### 1. Meta Ads: Currency Inconsistencies

**Issue**: Spend reported in multiple currencies (USD, CAD, GBP) with inconsistent flags. 133 records had missing currency.

**Resolution**:
- Original currencies preserved in bronze layer
- CAD and GBP converted to USD using monthly exchange rates
- Missing currency assumed USD (documented assumption)
- Created `ref_exchange_rates` table for future API integration

**Impact**: 152 records (4.2% of Meta data) required currency conversion.

**Confidence**: **HIGH** for total spend. Conversion rates are approximate but directionally correct.

---

### 2. Meta Ads: Campaign Name Changes

**Issue**: Campaign names changed mid-flight across different dates.

**Resolution**:
- Original names preserved in bronze for auditability
- Standardized names created from metadata (`brand_product_line_region`)
- Created `log_campaign_name_changes` table tracking all name variations
- `dim_campaign` uses standardized names as source of truth

**Confidence**: **HIGH** for campaign identification. Campaign IDs are stable; names are display-only.

---

### 3. Google Ads: Duplicate Records

**Issue**: Some campaigns appeared twice on the same day due to an export bug.

**Resolution**:
- Duplicate key: `(date, campaign_id, campaign_name, advertising_channel_type)`
- Selection: newest timestamp → max impressions (cumulative metric)
- Flagged with `duplicate_combined` and `duplicate_count`
- Result: 1,055 raw records → 1,028 after dedup (27 duplicates combined)

**Confidence**: **HIGH**. The dedup logic is deterministic and auditable.

---

### 4. Google Ads: Micros Conversion

**Issue**: Cost and conversion values reported in micros (divide by 1,000,000).

**Resolution**:
- Converted in silver layer: `cost_micros / 1000000.0`
- Preserved original micros in bronze for audit

**Confidence**: **VERY HIGH**. This is a straightforward mathematical conversion.

---

### 5. Store Visits: Missing Dates

**Issue**: Some dates missing entirely from store visits data.

**Resolution**:
- Created continuous date range via calendar × DMA cross join
- Missing dates zero-filled with `is_zero_filled = 1` flag
- 400 of 2,700 records zero-filled

**Confidence**: **MEDIUM**. Zero-filling assumes no visits occurred, but data could simply be unreported.

---

### 6. Store Visits: DMA to Campaign Mapping

**Issue**: DMA codes don't directly map to campaign-level data.

**Resolution**:
- Created manual `ref_dma_region_map` assigning 15 DMAs to East/West
- National campaigns match all DMAs
- East campaigns match 9 East DMAs
- West campaigns match 6 West DMAs

**Confidence**: **MEDIUM**. Manual assignment is a best-effort approximation. Actual DMA-to-region mapping may vary.

---

### 7. Campaign Metadata: Missing Budgets

**Issue**: 9 of 24 campaigns (37.5%) missing `budget_usd`.

**Resolution**:
- Flagged with `budget_available = 0` in bronze
- Estimated using: daily spend rate (by product_line + region) × campaign duration
- Flagged as 'ESTIMATED' vs 'ACTUAL' in analysis

**Confidence**: **LOW-MEDIUM**. Estimation is based on similar campaigns but may not reflect actual budgets.

---

## Confidence Summary by Metric

| Metric | Confidence | Rationale |
|--------|-----------|-----------|
| Total Spend | **HIGH** | Currency conversion straightforward, micros conversion exact |
| Total Conversions | **HIGH** | No significant issues found |
| Blended CPA | **HIGH** | Derived from high-confidence metrics |
| Spend by Product Line | **HIGH** | Campaign attributes from metadata are clean |
| WoW Growth | **HIGH** | Based on spend data |
| Cost per Visit | **MEDIUM** | Depends on DMA mapping and zero-fill assumptions |
| Budget Compliance | **LOW-MEDIUM** | 37.5% budgets estimated |
| ROI by Product Line | **MEDIUM** | Conversion value may have currency issues |

## Data Affected Summary

| Issue | Records Affected | % of Total |
|-------|-----------------|------------|
| Currency conversion (CAD/GBP) | 152 | 4.2% |
| Missing currency (assumed USD) | 133 | 3.7% |
| Google dedup | 27 | 2.6% |
| Zero-filled store visits | 400 | 14.8% |
| Missing budgets (estimated) | 9 | 37.5% |

## Recommendations for Higher Confidence

1. **Exchange rate API**: Replace approximate rates with historical daily rates
2. **DMA mapping validation**: Confirm East/West assignments with business stakeholders
3. **Budget source**: Query finance system for actual campaign budgets
4. **Store visits attribution**: Clarify if missing dates = zero visits or unreported data
