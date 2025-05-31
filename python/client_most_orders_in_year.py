import pandas as pd
from sqlalchemy import create_engine
from dotenv import load_dotenv
import os

load_dotenv()

CONNECTION_STRING = os.getenv('CONNECTION_STRING')
CONNECTION_DRIVER = os.getenv('CONNECTION_DRIVER')

# 1) Parametry
YEAR = 2014  # rok do analizy
MAX_RECORDS = 15 # liczba wyciąganych klientów

# 2) Connection string (dostosuj)
connection_string = (
    CONNECTION_STRING + CONNECTION_DRIVER
)
engine = create_engine(connection_string)

# 3) Zapytanie: zliczamy liczbę zamówień (SalesOrderID) per klient w danym roku
#    i wybieramy klienta z najwyższą liczbą zamówień
query = f"""
WITH CustomerOrderCounts AS (
    SELECT
        c.CustomerID,
        p.FirstName,
        p.LastName,
        COUNT(h.SalesOrderID) AS OrderCount,
        RANK() OVER (ORDER BY COUNT(h.SalesOrderID) DESC) AS OrderRank
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
)
SELECT
    CustomerID,
    FirstName,
    LastName,
    OrderCount
FROM CustomerOrderCounts
WHERE OrderRank <= {MAX_RECORDS}
ORDER BY OrderRank;

"""

# 4) Wczytanie do pandas DataFrame
df_order_count = pd.read_sql(query, engine)

# 5) Wyświetlamy wynik
print(f"Top {MAX_RECORDS} z największą liczbą zamówień w {YEAR}:")
print(df_order_count.to_string(index=False))
