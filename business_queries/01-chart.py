# %%
import matplotlib.pyplot as plt
import sqlite3
from src.load import get_connection

# Get CPA data
with get_connection() as conn:
    cursor = conn.execute("""
        SELECT
            dd.month_name,
            ROUND(SUM(f.spend_usd) / NULLIF(SUM(f.conversions), 0), 2) AS blended_cpa
        FROM fact_daily_performance f
        JOIN dim_campaign dc ON f.campaign_id = dc.campaign_id
        JOIN dim_date dd ON f.date = dd.date
        GROUP BY dd.month, dd.month_name
        ORDER BY dd.month
    """)
    months = []
    cpas = []
    for row in cursor:
        months.append(row["month_name"])
        cpas.append(row["blended_cpa"])

# Create chart
plt.figure(figsize=(10, 6))
plt.plot(months, cpas, marker='o', linewidth=2, color='#2E86AB')
plt.title('Blended CPA by Month (2026)', fontsize=14, fontweight='bold')
plt.xlabel('Month')
plt.ylabel('Cost Per Acquisition (USD)')
plt.ylim(40, 50)
plt.grid(True, alpha=0.3)

# Add data labels
for i, (month, cpa) in enumerate(zip(months, cpas)):
    plt.annotate(
        f'${cpa:.2f}',
        (month, cpa),
        textcoords="offset points",
        xytext=(0, 10),
        ha='center',
        fontsize=9,
        fontweight='bold',
        color='#2E86AB'
    )

plt.tight_layout()

# Save
plt.savefig('outputs/cpa_trend.png', dpi=150)
plt.show()

# %%
