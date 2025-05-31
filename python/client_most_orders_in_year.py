import os
from dotenv import load_dotenv

import pandas as pd

from sqlalchemy import create_engine, func, desc, MetaData
from sqlalchemy.ext.automap import automap_base
from sqlalchemy.orm import Session

# 0) Wczytanie zmiennych środowiskowych z .env
load_dotenv()

CONNECTION_STRING = os.getenv("CONNECTION_STRING", "")
CONNECTION_DRIVER = os.getenv("CONNECTION_DRIVER", "")

# 1) Parametry analizy
YEAR = 2014       # Rok, dla którego liczymy zamówienia
MAX_RECORDS = 15  # Ilu top‐klientów chcemy wyciągnąć (OrderRank <= MAX_RECORDS)

# 2) Stworzenie Engine
connection_url = CONNECTION_STRING + CONNECTION_DRIVER
engine = create_engine(connection_url)

# 3) Reflektowanie schematów "Sales" i "Person"
#    - Sales: SalesOrderHeader, Customer
#    - Person: Person
metadata = MetaData()
metadata.reflect(bind=engine, schema="Sales")
metadata.reflect(bind=engine, schema="Person")

# 4) Automap na podstawie zreflektowanych MetaData
Base = automap_base(metadata=metadata)
Base.prepare()

# 5) Przypisanie klas do zmiennych
SalesOrderHeader = Base.classes.SalesOrderHeader
Customer         = Base.classes.Customer
Person           = Base.classes.Person

# 6) Budowa zapytania ORM
session = Session(engine)

# 7.1) subq_1: obliczamy liczbę zamówień per klient w danym roku
subq_1 = (
    session
    .query(
        Customer.CustomerID.label("CustomerID"),
        Person.FirstName.label("FirstName"),
        Person.LastName.label("LastName"),
        func.count(SalesOrderHeader.SalesOrderID).label("OrderCount")
    )
    .join(Customer, SalesOrderHeader.CustomerID == Customer.CustomerID)
    .join(Person, Customer.PersonID == Person.BusinessEntityID)
    .filter(func.year(SalesOrderHeader.OrderDate) == YEAR)
    .group_by(Customer.CustomerID, Person.FirstName, Person.LastName)
    .subquery()
)

# 7.2) subq_2: dodajemy kolumnę RANK() OVER (ORDER BY OrderCount DESC)
subq_2 = (
    session
    .query(
        subq_1.c.CustomerID,
        subq_1.c.FirstName,
        subq_1.c.LastName,
        subq_1.c.OrderCount,
        func.rank()
            .over(order_by=desc(subq_1.c.OrderCount))
            .label("OrderRank")
    )
    .subquery()
)

# 7.3) finalne zapytanie: wybieramy tylko te wiersze, gdzie OrderRank <= MAX_RECORDS
final_q = (
    session
    .query(
        subq_2.c.CustomerID,
        subq_2.c.FirstName,
        subq_2.c.LastName,
        subq_2.c.OrderCount
    )
    .filter(subq_2.c.OrderRank <= MAX_RECORDS)
    .order_by(subq_2.c.OrderRank)
)

# 8) Wczytanie wyniku do pandas DataFrame
df_order_count = pd.read_sql(final_q.statement, engine)

# 9) Prezentacja wyników
print(f"Top {MAX_RECORDS} klientów z największą liczbą zamówień w {YEAR}:")
print(df_order_count.to_string(index=False))

# 10) Zamknięcie sesji
session.close()
