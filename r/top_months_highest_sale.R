#-----------------------------
# TOP N miesięcy z najwyższą sprzedażą
#-----------------------------

# 0) Wczytanie bibliotek
library(DBI)
library(odbc)
library(dplyr)
library(lubridate)
library(ggplot2)

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

MAX_RECORDS <- 7

# 2) Wyliczenie TOP N miesięcy według sumy sprzedaży
topn_months_tbl <- tbl(con, in_schema("Sales", "SalesOrderHeader")) %>%
  mutate(
    SalesYear  = year(OrderDate),
    SalesMonth = month(OrderDate)
  ) %>%
  group_by(SalesYear, SalesMonth) %>%
  summarise(
    TotalSales = sum(TotalDue, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    MonthRank = min_rank(desc(TotalSales))
  ) %>%
  filter(
    MonthRank <= !!MAX_RECORDS
  )

# 3) Pobranie danych do R i dodanie nazwy miesiąca
topn_months <- topn_months_tbl %>%
  collect() %>%
  mutate(
    MonthName = paste(month.name[SalesMonth], SalesYear)
  )

cat(sprintf("TOP %d miesięcy z najwyższą sprzedażą:\n", MAX_RECORDS))
print(topn_months)

# 4) (Opcjonalny wykres słupkowy)
ggplot(topn_months, aes(x = reorder(MonthName, -TotalSales), y = TotalSales)) +
  geom_col() +
  labs(
    x = "Miesiąc (rok)",
    y = "Łączna wartość sprzedaży (TotalDue)",
    title = sprintf("TOP %d miesięcy z najwyższą sprzedażą", MAX_RECORDS)
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# 5) Zamknięcie połączenia
dbDisconnect(con)

