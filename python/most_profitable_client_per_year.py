import os
from dotenv import load_dotenv

import pandas as pd
import matplotlib.pyplot as plt

from sqlalchemy import create_engine, func, desc, MetaData
from sqlalchemy.ext.automap import automap_base
from sqlalchemy.orm import Session

# 0) Wczytanie zmiennych środowiskowych z .env
load_dotenv()

CONNECTION_STRING = os.getenv("CONNECTION_STRING", "")
CONNECTION_DRIVER = os.getenv("CONNECTION_DRIVER", "")

# 1) Parametry analizy
YEAR = 2014      # Rok, dla którego wyszukujemy najbardziej dochodowych klientów
MAX_RECORDS = 15 # Ile top‐klientów chcemy zobaczyć (odpowiednik rank <= 15)

# 2) Stworzenie Engine
connection_url = CONNECTION_STRING + CONNECTION_DRIVER
engine = create_engine(connection_url)

# 3) Reflektowanie konkretnych schematów w MetaData
metadata = MetaData()

# 4) Reflektujemy kolejno schemat "Sales" oraz "Person"
metadata.reflect(bind=engine, schema="Sales")
metadata.reflect(bind=engine, schema="Person")

# 5) Automap: utworzenie klas ORM na podstawie zreflektowanych MetaData
Base = automap_base(metadata=metadata)
Base.prepare()

# 6) Przypisanie klas do zmiennych
SalesOrderHeader = Base.classes.SalesOrderHeader
Customer = Base.classes.Customer
Person = Base.classes.Person

# 7) Budowa zapytania ORM
session = Session(engine)

# 7.1) subquery: obliczamy łączny przychód per klient w danym roku
subq_1 = (
    session
    .query(
        Customer.CustomerID.label("CustomerID"),
        Person.FirstName.label("FirstName"),
        Person.LastName.label("LastName"),
        func.sum(SalesOrderHeader.TotalDue).label("TotalRevenue")
    )
    .join(Customer, SalesOrderHeader.CustomerID == Customer.CustomerID)
    .join(Person, Customer.PersonID == Person.BusinessEntityID)
    .filter(func.year(SalesOrderHeader.OrderDate) == YEAR)
    .group_by(Customer.CustomerID, Person.FirstName, Person.LastName)
    .having(func.sum(SalesOrderHeader.TotalDue) > 0)
    .subquery()
)

# 7.2) subquery: dodajemy ranking (RANK() OVER (ORDER BY TotalRevenue DESC))
subq_2 = (
    session
    .query(
        subq_1.c.CustomerID,
        subq_1.c.FirstName,
        subq_1.c.LastName,
        subq_1.c.TotalRevenue,
        func.rank()
            .over(order_by=desc(subq_1.c.TotalRevenue))
            .label("RevenueRank")
    )
    .subquery()
)

# 7.3) finalne zapytanie: wybieramy tylko tych, których RevenueRank <= MAX_RECORDS
final_q = (
    session
    .query(
        subq_2.c.CustomerID,
        subq_2.c.FirstName,
        subq_2.c.LastName,
        subq_2.c.TotalRevenue,
        subq_2.c.RevenueRank
    )
    .filter(subq_2.c.RevenueRank <= MAX_RECORDS)
    .order_by(subq_2.c.RevenueRank)
)

# 8) Wczytanie wyniku do pandas DataFrame
df_revenue = pd.read_sql(final_q.statement, engine)

# 9) Prezentacja wyników w konsoli
print(f"Top {MAX_RECORDS} klientów wg przychodu w {YEAR}:")
print(df_revenue.to_string(index=False))

# 10) Wizualizacja: wykres słupkowy Top {MAX_RECORDS} klientów
plt.figure(figsize=(10, 6))
plt.barh(
    df_revenue["FirstName"] + " " + df_revenue["LastName"],
    df_revenue["TotalRevenue"]
)
plt.gca().invert_yaxis()  # Największe przychody na górze
plt.xlabel("Łączny przychód (TotalDue)")
plt.title(f"Top {MAX_RECORDS} klientów wg przychodu w {YEAR}")
plt.tight_layout()
plt.show()

# 11) Zamknięcie sesji
session.close()
