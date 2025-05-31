WITH ProductSales AS (
    SELECT
        p.ProductID,
        p.Name AS ProductName,
        SUM(d.OrderQty) AS TotalQuantity
    FROM Sales.SalesOrderDetail AS d
    JOIN Production.Product AS p ON d.ProductID = p.ProductID
    GROUP BY
        p.ProductID,
        p.Name
),
RankedProducts AS (
    SELECT
        ProductID,
        ProductName,
        TotalQuantity,
        RANK() OVER (ORDER BY TotalQuantity DESC) AS SalesRank
    FROM ProductSales
)
SELECT
    ProductID,
    ProductName,
    TotalQuantity,
    SalesRank
FROM RankedProducts
WHERE SalesRank <= 10
ORDER BY SalesRank, ProductName;
GO