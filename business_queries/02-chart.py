# %%
import matplotlib.pyplot as plt
import sqlite3
from src.load import get_connection


# Get spend data
with get_connection() as conn:
    cursor = conn.execute("""
        SELECT
            dd.month_name,
            ROUND(SUM(f.spend_usd), 0) AS total_spend
        FROM fact_daily_performance f
        JOIN dim_date dd ON f.date = dd.date
        GROUP BY dd.month, dd.month_name
        ORDER BY dd.month
    """)
    months = []
    spends = []
    for row in cursor:
        months.append(row["month_name"])
        spends.append(row["total_spend"])

# Create bar chart
plt.figure(figsize=(10, 6))
bars = plt.bar(months, spends, color='#2E86AB', alpha=0.8)
plt.title('Total Spend by Month (2026)', fontsize=14, fontweight='bold')
plt.xlabel('Month')
plt.ylabel('Total Spend (USD)')
plt.grid(True, alpha=0.3, axis='y')

# Add data labels on bars
for bar, spend in zip(bars, spends):
    plt.text(
        bar.get_x() + bar.get_width()/2,
        bar.get_height() + 50000,
        f'${spend:,.0f}',
        ha='center',
        va='bottom',
        fontsize=9,
        fontweight='bold'
    )

plt.tight_layout()
plt.savefig('outputs/spend_by_month.png', dpi=150, bbox_inches='tight')
plt.show()


# %%
# %%

with open("business_queries/02-Spend_Growth.sql", "r") as f:
    query_sql = f.read()

# Execute query and get data
with get_connection() as conn:
    cursor = conn.execute(query_sql)
    campaigns = []
    growths = []
    weeks = []
    
    for row in cursor:
        campaigns.append(row["campaign_name_standardized"])
        growths.append(row["week_over_week_growth_pct"])
        weeks.append(row["week"])

# Create chart
plt.figure(figsize=(12, 8))

labels = [f"{c}\n(w{w})" for c, w in zip(campaigns, weeks)]
colors = ['#2ECC71' if g > 0 else '#E74C3C' for g in growths]

bars = plt.barh(range(len(campaigns)), growths, color=colors, alpha=0.8)

plt.title('Top 10 Campaigns by Week-over-Week Spend Growth', fontsize=14, fontweight='bold')
plt.xlabel('WoW Growth (%)')
plt.yticks(range(len(campaigns)), labels, fontsize=8)
plt.axvline(x=0, color='black', linestyle='-', linewidth=0.5)

# Data labels
for bar, growth in zip(bars, growths):
    plt.text(
        bar.get_width() + (1 if growth > 0 else -1),
        bar.get_y() + bar.get_height()/2,
        f'{growth:+.1f}%',
        va='center',
        ha='left' if growth > 0 else 'right',
        fontsize=9,
        fontweight='bold'
    )

plt.tight_layout()
plt.savefig('outputs/wow_growth.png', dpi=150, bbox_inches='tight')
plt.show()


# %%
