import pandas as pd
from sqlalchemy import create_engine
import matplotlib.pyplot as plt
from dotenv import load_dotenv
import os

load_dotenv()

CONNECTION_STRING = os.getenv('CONNECTION_STRING')
CONNECTION_DRIVER = os.getenv('CONNECTION_DRIVER')

# 1) Connection string (dostosuj)
connection_string = (
    CONNECTION_STRING + CONNECTION_DRIVER
)
engine = create_engine(connection_string)

# 2) Zapytanie SQL: dla każdego zamówienia mamy TotalDue, wyciągamy rok/miesiąc
query = """
SELECT
    SalesOrderID,
    TotalDue,
    YEAR(OrderDate)  AS SalesYear,
    MONTH(OrderDate) AS SalesMonth
FROM Sales.SalesOrderHeader
"""

# 3) Wczytajmy wszystkie zamówienia do pandas
df_orders = pd.read_sql(query, engine)

# 4) Dodajemy w DataFrame kolumnę z datą „pierwszego dnia miesiąca”, żeby łatwiej grupować
df_orders["OrderDate_MonthStart"] = pd.to_datetime(
    df_orders["SalesYear"].astype(str) + "-" +
    df_orders["SalesMonth"].astype(str).str.zfill(2) + "-01"
)

# 5) Grupujemy po „pierwszym dniu miesiąca” i liczymy średnią z TotalDue
monthly_avg = (
    df_orders
    .groupby("OrderDate_MonthStart", as_index=False)
    .agg(AvgOrderValue=("TotalDue", "mean"))
)

# 6) Zaokrąglamy do dwóch miejsc po przecinku
monthly_avg["AvgOrderValue"] = monthly_avg["AvgOrderValue"].round(2)

# 7) Wyświetlamy wynik
print("Średnia wartość zamówienia (TotalDue) według miesiąca:")
print(monthly_avg.to_string(index=False,
    formatters={"OrderDate_MonthStart": lambda x: x.strftime("%Y-%m")}
))

# 8) (opcjonalnie) wykres liniowy średniej wartości zamówienia w czasie
plt.figure(figsize=(10, 5))
plt.plot(
    monthly_avg["OrderDate_MonthStart"],
    monthly_avg["AvgOrderValue"],
    marker="o",
    linestyle="-"
)
plt.xlabel("Rok-Miesiąc")
plt.ylabel("Średnia wartość zamówienia (TotalDue)")
plt.title("Średnia wartość zamówienia według miesiąca")
plt.grid(alpha=0.3)
plt.tight_layout()
plt.show()
