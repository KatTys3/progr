import pandas as pd
from sqlalchemy import create_engine
import matplotlib.pyplot as plt
from dotenv import load_dotenv
import os

load_dotenv()

CONNECTION_STRING = os.getenv('CONNECTION_STRING')
CONNECTION_DRIVER = os.getenv('CONNECTION_DRIVER')

# 1) Parametry
YEAR = 2014  # wybierz rok, który chcesz analizować
MAX_RECORDS = 15

# 2) Connection string (dostosuj do swojego środowiska)
connection_string = (
    CONNECTION_STRING + CONNECTION_DRIVER
)

engine = create_engine(connection_string)

# 3) Zapytanie: połączenie SalesOrderHeader, SalesOrderDetail i Customer
#    Sumujemy TotalDue per klient w danym roku
query = f"""
WITH CustomerRevenue AS (
    SELECT
        c.CustomerID,
        p.FirstName,
        p.LastName,
        SUM(h.TotalDue) AS TotalRevenue,
        RANK() OVER (ORDER BY SUM(h.TotalDue) DESC) AS RevenueRank
    FROM Sales.SalesOrderHeader AS h
    INNER JOIN Sales.Customer AS c
        ON h.CustomerID = c.CustomerID
    INNER JOIN Person.Person AS p
        ON c.PersonID = p.BusinessEntityID
    WHERE YEAR(h.OrderDate) = {YEAR}
    GROUP BY
        c.CustomerID,
        p.FirstName,
        p.LastName
    HAVING
        SUM(h.TotalDue) > 0
)
SELECT
    CustomerID,
    FirstName,
    LastName,
    TotalRevenue,
    RevenueRank
FROM CustomerRevenue
WHERE RevenueRank <= {MAX_RECORDS}
ORDER BY RevenueRank;
"""

# 4) Wczytanie do pandas DataFrame
df_revenue = pd.read_sql(query, engine)

# 5) Wyświetlenie top 10
print(f"Top {MAX_RECORDS} klientów wg przychodu w {YEAR}:")
print(df_revenue.to_string(index=False))

# 6) (opcjonalnie) wizualizacja: wykres słupkowy Top 10 klientów
plt.figure(figsize=(10, 6))
plt.barh(
    df_revenue["FirstName"] + " " + df_revenue["LastName"],
    df_revenue["TotalRevenue"]
)
plt.gca().invert_yaxis()  # odwróć kolejność, żeby największy był na górze
plt.xlabel("Łączny przychód (TotalDue)")
plt.title(f"Top {MAX_RECORDS} klientów wg przychodu w {YEAR}")
plt.tight_layout()
plt.show()
