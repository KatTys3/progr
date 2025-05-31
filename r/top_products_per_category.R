#-----------------------------
# TOP N produktów wg liczby sprzedanych sztuk
#-----------------------------

# 0) Wczytanie bibliotek
library(DBI)
library(odbc)
library(dplyr)
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

MAX_RECORDS <- 10

# 2) Wyliczenie TOP 10 produktów według sumy sprzedanych sztuk
topn_products_tbl <- tbl(con, in_schema("Sales", "SalesOrderDetail")) %>%
  inner_join(
    tbl(con, in_schema("Production", "Product")),
    by = "ProductID"
  ) %>%
  group_by(ProductID, Name) %>%
  summarise(
    TotalQty = sum(OrderQty, na.rm = TRUE)
  ) %>%
  ungroup() %>%
  mutate(
    ProductRank = min_rank(desc(TotalQty))
  ) %>%
  filter(
    ProductRank <= !!MAX_RECORDS
  )

topn_products <- topn_products_tbl %>%
  collect()

sprintf("TOP %s produktów wg liczby sprzedanych sztuk:", MAX_RECORDS)
print(topn_products)

# 3) (Opcjonalny wykres słupkowy)
ggplot(topn_products, aes(x = reorder(Name, -TotalQty), y = TotalQty)) +
  geom_col() +
  labs(
    x = "Nazwa produktu",
    y = "Łączna liczba sprzedanych sztuk",
    title = sprintf("TOP %d produktów wg liczby sprzedanych sztuk", MAX_RECORDS)
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# 4) Zamknięcie połączenia
dbDisconnect(con)
