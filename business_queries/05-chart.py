# %%
import matplotlib.pyplot as plt
from src.load import get_connection

with get_connection() as conn:
    # ROI by product line
    cursor = conn.execute("""
        SELECT
            dc.product_line,
            ROUND(SUM(f.spend_usd), 2) AS total_spend,
            ROUND(SUM(f.conversion_value_usd), 2) AS total_conversion_value,
            ROUND(SUM(f.conversion_value_usd) / NULLIF(SUM(f.spend_usd), 0), 2) AS roi
        FROM fact_daily_performance f
        JOIN dim_campaign dc ON f.campaign_id = dc.campaign_id
        GROUP BY dc.product_line
        ORDER BY roi DESC
    """)
    
    print("ROI by Product Line:")
    for row in cursor:
        print(f"  {row['product_line']}: ROI {row['roi']}x "
              f"(spend ${row['total_spend']}, value ${row['total_conversion_value']})")
        

# %%
# Get ROI data
with get_connection() as conn:
    cursor = conn.execute("""
        SELECT
            dc.product_line,
            ROUND(SUM(f.conversion_value_usd) / NULLIF(SUM(f.spend_usd), 0), 2) AS roi,
            ROUND(SUM(f.spend_usd), 2) AS total_spend
        FROM fact_daily_performance f
        JOIN dim_campaign dc ON f.campaign_id = dc.campaign_id
        GROUP BY dc.product_line
        ORDER BY roi DESC
    """)
    
    products = []
    rois = []
    spends = []
    for row in cursor:
        products.append(row["product_line"])
        rois.append(row["roi"])
        spends.append(row["total_spend"])

# Simple horizontal bar
plt.figure(figsize=(10, 6))
colors = ['#2ECC71', '#2E86AB', '#8E44AD', '#E67E22']
bars = plt.barh(products, rois, color=colors, alpha=0.8)

plt.title('ROI by Product Line', fontsize=14, fontweight='bold')
plt.xlabel('ROI (Conversion Value / Spend)')
plt.xlim(0, max(rois) + 1)

# Labels
for bar, roi, spend in zip(bars, rois, spends):
    plt.text(
        bar.get_width() + 0.1,
        bar.get_y() + bar.get_height()/2,
        f'{roi:.1f}x  (${spend:,.0f})',
        va='center',
        fontsize=11,
        fontweight='bold'
    )

plt.tight_layout()
plt.savefig('outputs/roi_by_product.png', dpi=150, bbox_inches='tight')
plt.show()
