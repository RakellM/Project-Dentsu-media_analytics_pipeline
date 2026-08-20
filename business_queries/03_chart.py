# %%
import matplotlib.pyplot as plt
from src.load import get_connection

# Read the SQL query
with open("business_queries/03-Spend_vs_Store_Visits.sql", "r") as f:
    query_sql = f.read()

# Execute query and get data
with get_connection() as conn:
    cursor = conn.execute(query_sql)
    weeks = []
    cpvs = []
    
    for row in cursor:
        weeks.append(row["week"])
        cpvs.append(row["cost_per_visit"])

# Create chart
plt.figure(figsize=(14, 6))

plt.plot(weeks, cpvs, marker='s', linewidth=2, markersize=5, color='#8E44AD')

plt.title('Cost per Store Visit by Week', fontsize=14, fontweight='bold')
plt.xlabel('Week')
plt.ylabel('Cost per Visit (USD)')
plt.grid(True, alpha=0.3)
plt.xticks(rotation=45)

# Data labels (every 2nd point to avoid clutter)
for i, (week, cpv) in enumerate(zip(weeks, cpvs)):
    if i % 2 == 0:
        plt.annotate(
            f'${cpv:.2f}',
            (week, cpv),
            textcoords="offset points",
            xytext=(0, 10),
            ha='center',
            fontsize=8,
            fontweight='bold'
        )

plt.tight_layout()
plt.savefig('outputs/cost_per_visit.png', dpi=150, bbox_inches='tight')
plt.show()

# %%
