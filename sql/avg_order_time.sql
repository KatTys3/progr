USE AdventureWorks2022;
GO

SELECT
    CAST(AVG(DATEDIFF(day, OrderDate, ShipDate)) AS DECIMAL(6,2))
        AS AvgLeadTimeDays
FROM Sales.SalesOrderHeader
WHERE ShipDate IS NOT NULL;
GO
