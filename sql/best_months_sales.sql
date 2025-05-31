WITH MonthlySales AS (
    SELECT
        YEAR(OrderDate)  AS SalesYear,
        MONTH(OrderDate) AS SalesMonth,
        ROUND(CAST(SUM(TotalDue) AS MONEY), 2) AS TotalSales
    FROM Sales.SalesOrderHeader
    GROUP BY
        YEAR(OrderDate),
        MONTH(OrderDate)
),
RankedMonths AS (
    SELECT
        SalesYear,
        SalesMonth,
        TotalSales,
        RANK() OVER (ORDER BY TotalSales DESC) AS SalesRank
    FROM MonthlySales
)
SELECT
    CONCAT(DATENAME(month, DATEFROMPARTS(SalesYear, SalesMonth, 1)), ' ', SalesYear) as Months,
    TotalSales,
    SalesRank
FROM RankedMonths
ORDER BY SalesRank;
GO
