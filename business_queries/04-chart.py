# %%
import matplotlib.pyplot as plt
import numpy as np
from src.load import get_connection

# Read the SQL query
with open("business_queries/04-Campaign_Exceeding_Budget.sql", "r") as f:
    query_sql = f.read()

# Execute query and get data
with get_connection() as conn:
    cursor = conn.execute(query_sql)
    campaigns = []
    over_amounts = []
    budgets = []
    spends = []
    
    for row in cursor:
        campaigns.append(row["campaign_id"])
        over_amounts.append(row["over_budget_amount"])
        budgets.append(row["budget_usd"])
        spends.append(row["total_spend_usd"])

# Create chart
plt.figure(figsize=(14, 8))

colors = ['#E74C3C' if x > 0 else '#2ECC71' for x in over_amounts]

bars = plt.bar(range(len(campaigns)), over_amounts, color=colors, alpha=0.8)

plt.title('Budget Compliance by Campaign', fontsize=14, fontweight='bold')
plt.xlabel('Campaign ID')
plt.ylabel('Over Budget Amount (USD)')
plt.axhline(y=0, color='black', linestyle='-', linewidth=0.5)
plt.xticks(range(len(campaigns)), campaigns, fontsize=8)

# Data labels
for bar, amount in zip(bars, over_amounts):
    if amount > 0:
        plt.text(
            bar.get_x() + bar.get_width()/2,
            bar.get_height() + 10000,
            f'${amount:,.0f}',
            ha='center',
            va='bottom',
            fontsize=7,
            fontweight='bold'
        )
    else:
        plt.text(
            bar.get_x() + bar.get_width()/2,
            bar.get_height() - 15000,
            f'${amount:,.0f}',
            ha='center',
            va='top',
            fontsize=7,
            fontweight='bold'
        )

plt.tight_layout()
plt.savefig('outputs/budget_compliance.png', dpi=150, bbox_inches='tight')
plt.show()

# %%
