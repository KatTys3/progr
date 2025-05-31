USE AdventureWorks2022;
GO

WITH PersonSales AS (
    SELECT
        sp.BusinessEntityID AS SalesPersonID,
        p.FirstName AS FirstName,
        p.LastName AS LastName,
        SUM(d.LineTotal) AS TotalSales
    FROM Sales.SalesOrderHeader AS h
    INNER JOIN Sales.SalesPerson  AS sp ON h.SalesPersonID = sp.BusinessEntityID
    INNER JOIN Person.Person AS p ON sp.BusinessEntityID  = p.BusinessEntityID
    INNER JOIN Sales.SalesOrderDetail AS d ON h.SalesOrderID = d.SalesOrderID
    INNER JOIN Production.Product AS prod ON d.ProductID = prod.ProductID
    GROUP BY
        sp.BusinessEntityID,
        p.FirstName,
        p.LastName
),
CategoryCounts AS (
    SELECT
        sp.BusinessEntityID AS SalesPersonID,
        cat.Name AS CategoryName,
        SUM(d.OrderQty) AS TotalQty,
        ROW_NUMBER() OVER (
            PARTITION BY sp.BusinessEntityID
            ORDER BY SUM(d.OrderQty) DESC
        ) AS rn
    FROM Sales.SalesOrderHeader AS h
    INNER JOIN Sales.SalesPerson AS sp ON h.SalesPersonID = sp.BusinessEntityID
    INNER JOIN Sales.SalesOrderDetail AS d ON h.SalesOrderID = d.SalesOrderID
    INNER JOIN Production.Product AS prod ON d.ProductID = prod.ProductID
    INNER JOIN Production.ProductSubcategory AS sub
        ON prod.ProductSubcategoryID = sub.ProductSubcategoryID
    INNER JOIN Production.ProductCategory AS cat
        ON sub.ProductCategoryID = cat.ProductCategoryID
    GROUP BY
        sp.BusinessEntityID,
        cat.Name
),
Combined AS (
    SELECT
        ps.SalesPersonID,
        ps.FirstName,
        ps.LastName,
        ps.TotalSales,
        cc.CategoryName AS MostFrequentCategory
    FROM PersonSales ps
    LEFT JOIN CategoryCounts cc
        ON ps.SalesPersonID = cc.SalesPersonID
       AND cc.rn = 1
),
RankedSales AS (
    SELECT
        *,
        RANK() OVER (ORDER BY TotalSales DESC) AS SalesRank
    FROM Combined
)

SELECT
    FirstName,
    LastName,
    ROUND(CAST(TotalSales as money), 2),
    MostFrequentCategory,
    SalesRank
FROM RankedSales
WHERE SalesRank <= 10
ORDER BY SalesRank;
