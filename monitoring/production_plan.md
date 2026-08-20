# Production Monitoring Plan

## Overview

This document outlines how the data pipeline will alert stakeholders to problems and ensure the business impact of stale or broken data is minimized.

---

## Pipeline Schedule

### Daily Run
- **Time**: 6:00 AM UTC
- **Purpose**: Load previous day's data from Meta and Google
- **Duration**: ~30 seconds (full pipeline)

### Weekly Run
- **Time**: Monday 7:00 AM UTC
- **Purpose**: Refresh store visits data and campaign metadata
- **Duration**: ~1 minute

---

## Monitoring Checks

### 1. File Arrival Checks

| Check | Threshold | Alert |
|-------|-----------|-------|
| Meta file arrives | By 5:00 AM UTC | Email + Slack if missing by 6:00 AM |
| Google file arrives | By 5:00 AM UTC | Email + Slack if missing by 6:00 AM |
| Store visits file | Weekly (Monday) | Slack if missing |
| Campaign metadata | Weekly (Monday) | Slack if missing |

**Alert Message**: "Meta Ads data file not received. Pipeline will run with previous day's data. Expected impact: CPA and spend metrics will be stale."

---

### 2. Data Quality Checks

| Check | Threshold | Alert |
|-------|-----------|-------|
| Row count vs 7-day average | ±20% deviation | Warning alert |
| Row count vs 7-day average | ±50% deviation | Critical alert |
| Null spend records | >0 records | Immediate alert |
| Duplicate records (Google) | >5% of daily records | Warning alert |
| Currency issues | >10% non-USD | Review required |

**Alert Message**: "Google Ads row count 60% below 7-day average. Possible data export issue. Pipeline halted for review."

---

### 3. Business Metric Checks

| Metric | Threshold | Alert |
|--------|-----------|-------|
| Blended CPA | >$60 (vs $45 avg) | Warning |
| Daily spend | >$100K deviation from forecast | Review |
| Conversion rate | <1% (vs 2.2% avg) | Warning |
| Store visits | >30% drop week-over-week | Warning |

---

### 4. Pipeline Health Checks

| Check | Frequency | Alert |
|-------|-----------|-------|
| Pipeline runtime | Every run | Alert if >5 minutes |
| Database size | Daily | Alert if growth >10% unexpected |
| Ingestion log | Every run | Alert if missing entries |
| Pipeline tracking | Every run | Alert if stalled >1 hour |

---

## Alerting Channels

| Severity | Channel | Response Time |
|----------|---------|---------------|
| **Critical** | PagerDuty + Slack | Immediate (24/7) |
| **Warning** | Slack + Email | Within 4 business hours |
| **Info** | Email digest | Within 24 hours |

---

## Incident Response

### If Pipeline Fails:

1. **Immediate**: Check `_ingestion_log` for last successful load
2. **15 min**: Identify failing step (extract/transform/load/SQL)
3. **30 min**: Determine if data is stale or corrupted
4. **1 hour**: Restore from last known good state
5. **2 hours**: Notify stakeholders with impact assessment

### Impact Communication Template:

> "Data pipeline issue detected at [TIME]. Affected metrics: [LIST]. Estimated impact: [PERCENT] of data may be stale. Expected resolution: [TIME]. Alternative data source: [IF ANY]."

---

## Data Quality Thresholds

### Acceptable Data Loss
- **Spend data**: <0.5% loss acceptable
- **Conversion data**: <1% loss acceptable
- **Store visits**: <5% loss acceptable (weekly aggregate)

### Unacceptable Conditions
- Missing currency conversion rates
- Duplicate primary keys
- Negative spend values
- Unmapped DMA codes

---

## Dashboard for Stakeholders

A simple status page showing:

| Indicator | Status | Last Updated |
|-----------|--------|--------------|
| Data Freshness | ✔️ Current | 6:00 AM today |
| Pipeline Health | ✔️ Running | 6:02 AM today |
| Data Quality | ⚠️ 2 warnings | 6:02 AM today |
| Spend Mismatch | ✔️ 0.3% | 6:02 AM today |

---

## Business Impact Examples

| Failure Scenario | Business Impact | Alert |
|------------------|-----------------|-------|
| Meta file not received | CPA for Meta campaigns unavailable | Critical |
| Currency rates missing | Spend in CAD/GBP not converted | Warning |
| DMA mapping broken | Store visit analysis incorrect | Warning |
| Budget data missing | Over-budget analysis incomplete | Info |

---

## Recommended Tools

| Component | Tool | Purpose |
|-----------|------|---------|
| Orchestration | Airflow/Dagster | Schedule and monitor pipeline |
| Alerting | Slack + PagerDuty | Notify on failures |
| Monitoring | Grafana | Visualize pipeline metrics |
| Logging | ELK Stack | Centralized logs |
| Testing | Great Expectations | Data quality validation |
| CI/CD | GitHub Actions | Automated testing |

---

*This monitoring plan ensures the business is promptly informed of data issues and can trust the metrics being reported.*
