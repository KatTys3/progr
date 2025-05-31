#-----------------------------
# Kod 2: Średni czas realizacji zamówienia (wykorzystanie DATEDIFF)
#-----------------------------

# 0) Wczytanie bibliotek
library(DBI)
library(odbc)
library(dplyr)

# 1) Nawiązanie połączenia
con <- dbConnect(
  odbc::odbc(),
  Driver   = "ODBC Driver 17 for SQL Server",
  Server   = "SERVER",
  Database = "AdventureWorks2022",
  UID      = "USER",
  PWD      = "PASS",
  TrustServerCertificate = "yes"
)

# 2) Wyliczenie średniego czasu realizacji (w dniach) z użyciem DATEDIFF
avg_lead_time_tbl <- tbl(con, in_schema("Sales", "SalesOrderHeader")) %>%
  filter(
    !is.na(ShipDate)
  ) %>%
  transmute(
    LeadDays = sql("DATEDIFF(day, OrderDate, ShipDate)")
  ) %>%
  summarise(
    AvgLeadDays = round(mean(LeadDays, na.rm = TRUE), 2)
  )

avg_lead_time <- avg_lead_time_tbl %>%
  collect()

print("Średni czas realizacji zamówienia (w dniach):")
print(avg_lead_time)

# 3) Zamknięcie połączenia
dbDisconnect(con)
