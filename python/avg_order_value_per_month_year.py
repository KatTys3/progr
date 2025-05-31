import os
from dotenv import load_dotenv

import pandas as pd
import matplotlib.pyplot as plt

from sqlalchemy import create_engine, func, MetaData, inspect
from sqlalchemy.ext.automap import automap_base
from sqlalchemy.orm import Session

# 0) Wczytanie zmiennych środowiskowych z .env
load_dotenv()

CONNECTION_STRING = os.getenv("CONNECTION_STRING", "")
CONNECTION_DRIVER = os.getenv("CONNECTION_DRIVER", "")

# 1) Stworzenie Engine
connection_url = CONNECTION_STRING + CONNECTION_DRIVER
engine = create_engine(connection_url)

# 2) Reflektowanie schematu "Sales", w którym leży tabela SalesOrderHeader
metadata = MetaData()
metadata.reflect(bind=engine, schema="Sales")

# 3) Automap: utworzenie klas ORM na podstawie zreflektowanych MetaData
Base = automap_base(metadata=metadata)
Base.prepare()

# 4) Wypisanie dostępnych klas, aby sprawdzić dokładną nazwę mapowanej tabeli
print("Dostępne mapowane klasy:")
print(Base.classes.keys())

# 5) Przypisanie klasy odpowiadającej SalesOrderHeader
SalesOrderHeader = Base.classes.SalesOrderHeader

# 6) Otwórz sesję i zbuduj zapytanie ORM, które odtworzy kolumny:
session = Session(engine)

# 6.1) Tworzymy zapytanie ORM, które wyciąga dokładnie te cztery kolumny.
orm_query = (
    session
    .query(
        SalesOrderHeader.SalesOrderID.label("SalesOrderID"),
        SalesOrderHeader.TotalDue.label("TotalDue"),
        func.year(SalesOrderHeader.OrderDate).label("SalesYear"),
        func.month(SalesOrderHeader.OrderDate).label("SalesMonth"),
    )
)

# 7) Wczytanie wyniku zapytania ORM do pandas.DataFrame
#    Możemy przekazać `orm_query.statement` do `pd.read_sql(...)`
df_orders = pd.read_sql(orm_query.statement, engine)

# 8) Dodanie kolumny z pierwszym dniem miesiąca w formacie datetime,
#    aby łatwo grupować po miesiącach
df_orders["OrderDate_MonthStart"] = pd.to_datetime(
    df_orders["SalesYear"].astype(str) + "-" +
    df_orders["SalesMonth"].astype(str).str.zfill(2) + "-01"
)

# 9) Grupowanie po „pierwszym dniu miesiąca” i obliczenie średniej TotalDue
monthly_avg = (
    df_orders
    .groupby("OrderDate_MonthStart", as_index=False)
    .agg(AvgOrderValue=("TotalDue", "mean"))
)

# 10) Zaokrąglenie średniej do 2 miejsc po przecinku
monthly_avg["AvgOrderValue"] = monthly_avg["AvgOrderValue"].round(2)

# 11) Wyświetlenie wyniku w konsoli
print("Średnia wartość zamówienia (TotalDue) według miesiąca:")
print(
    monthly_avg.to_string(
        index=False,
        formatters={"OrderDate_MonthStart": lambda x: x.strftime("%Y-%m")}
    )
)

# 12) Wykres liniowy średniej wartości zamówienia w czasie
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

# 13) Zamknięcie sesji
session.close()
