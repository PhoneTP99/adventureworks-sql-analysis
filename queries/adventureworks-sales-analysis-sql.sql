/* to check common column and data type
*/

SELECT c1.COLUMN_NAME, c1.DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS c1
INNER JOIN INFORMATION_SCHEMA.COLUMNS c2
    ON c1.COLUMN_NAME = c2.COLUMN_NAME
   AND c1.DATA_TYPE = c2.DATA_TYPE
WHERE c1.TABLE_NAME = 'Table1'
  AND c2.TABLE_NAME = 'Table2';

/*
Business Question:
What is the total revenue, number of orders, and average order value?
*/

SELECT 
    COUNT(SalesOrderID) AS TotalOrders,
    SUM(TotalDue) AS TotalRevenue,
    AVG(TotalDue) AS AverageOrderValue
FROM Sales.SalesOrderHeader;


/*
Business Question:
Which products generated the highest revenue?
*/

SELECT TOP 5 
       P.Name AS ProductName,
       SUM(SOD.LineTotal) AS RevenuePerProduct,
       SUM(SOD.OrderQty) AS TotalQuantitySold
FROM Sales.SalesOrderDetail SOD
JOIN Production.Product P
    ON SOD.ProductID = P.ProductID
GROUP BY P.Name
ORDER BY RevenuePerProduct DESC;


/*
Business Question:
Who are the top customers by total revenue?
*/

SELECT TOP 10
       C.CustomerID,
       CASE 
           WHEN C.PersonID IS NOT NULL THEN P.FirstName + ' ' + P.LastName
           ELSE S.Name
       END AS CustomerName,
       SUM(SOH.TotalDue) AS TotalRevenue
FROM Sales.SalesOrderHeader SOH
JOIN Sales.Customer C
    ON SOH.CustomerID = C.CustomerID
LEFT JOIN Person.Person P
    ON C.PersonID = P.BusinessEntityID
LEFT JOIN Sales.Store S
    ON C.StoreID = S.BusinessEntityID
GROUP BY C.CustomerID, P.FirstName, P.LastName, S.Name , C.PersonID
ORDER BY TotalRevenue DESC;


/*
Which sales territories generated the most revenue?
*/

SELECT TOP 5
       ST.Name AS TerritoryName,
       ST.CountryRegionCode,
       SUM(SOH.TotalDue) AS TotalRevenue
FROM Sales.SalesOrderHeader SOH
JOIN Sales.SalesTerritory ST
    ON SOH.TerritoryID = ST.TerritoryID
GROUP BY ST.Name, ST.CountryRegionCode
ORDER BY TotalRevenue DESC;


/*
Business Question:
How does revenue trend over time (monthly)?
*/

SELECT YEAR(SOH.OrderDate) AS YEAR ,
       MONTH(SOH.OrderDate) AS MONTH,
       SUM(SOH.TotalDue) AS TotalRevenue
FROM Sales.SalesOrderHeader SOH
GROUP BY YEAR(SOH.OrderDate) , MONTH(SOH.OrderDate)
ORDER BY YEAR(SOH.OrderDate) ASC, MONTH(SOH.OrderDate) ASC ; 

SELECT 
       FORMAT(SOH.OrderDate, 'yyyy-MM') AS MonthYear,  /* Dashboard friendly */
       SUM(SOH.TotalDue) AS TotalRevenue
FROM Sales.SalesOrderHeader SOH
GROUP BY FORMAT(SOH.OrderDate, 'yyyy-MM')
ORDER BY MonthYear;


/*
Business Question:
Which products generate the most revenue each month?
*/

WITH MonthlyProductRevenue AS (
    SELECT 
           P.Name AS ProductName,
           FORMAT(SOH.OrderDate,'yyyy-MM') AS MonthYear,
           SUM(SOD.LineTotal) AS TotalRevenue
    FROM Sales.SalesOrderDetail SOD
    JOIN Sales.SalesOrderHeader SOH
        ON SOD.SalesOrderID = SOH.SalesOrderID
    JOIN Production.Product P
        ON P.ProductID = SOD.ProductID
    GROUP BY P.Name, FORMAT(SOH.OrderDate,'yyyy-MM')
),
RankedProducts AS (
    SELECT *,
           RANK() OVER(PARTITION BY MonthYear ORDER BY TotalRevenue DESC) AS RankPerMonth
    FROM MonthlyProductRevenue
)
SELECT *
FROM RankedProducts
WHERE RankPerMonth <= 3
ORDER BY MonthYear, RankPerMonth;


/*
Business Question:
Which product categories generate the most revenue?
*/


SELECT PC.Name AS Category ,
       SUM(SOD.LineTotal) AS TotalRevenue
FROM Sales.SalesOrderDetail SOD
JOIN Production.Product P
    ON SOD.ProductID = P.ProductID
JOIN Production.ProductSubcategory PSC
    ON P.ProductSubcategoryID = PSC.ProductSubcategoryID
JOIN Production.ProductCategory PC
    ON PC.ProductCategoryID = PSC.ProductCategoryID
GROUP BY PC.Name  
ORDER BY TotalRevenue DESC;


/*
Business Question:
Which sales territory has the highest average order value (AOV)?
*/

SELECT TOP 5
       ST.Name AS TerritoryName,
       COUNT(SOH.SalesOrderID) AS TotalOrders,
       AVG(SOH.TotalDue) AS AOV
FROM Sales.SalesOrderHeader SOH
JOIN Sales.SalesTerritory ST
    ON ST.TerritoryID = SOH.TerritoryID
GROUP BY ST.Name
ORDER BY AOV DESC;


/*
Business Question:
Which customers place the most orders?
*/


SELECT TOP 10
       C.CustomerID,
       CASE 
            WHEN C.PersonID IS NOT NULL 
                 THEN P.FirstName + ' ' + P.LastName
            ELSE S.Name
       END AS CustomerName,
       COUNT(SOH.SalesOrderID) AS TotalOrders
FROM Sales.SalesOrderHeader SOH
JOIN Sales.Customer C
    ON SOH.CustomerID = C.CustomerID
LEFT JOIN Person.Person P
    ON C.PersonID = P.BusinessEntityID
LEFT JOIN Sales.Store S
    ON C.StoreID = S.BusinessEntityID
GROUP BY 
       C.CustomerID,
       P.FirstName,
       P.LastName,
       S.Name,
       C.PersonID
ORDER BY TotalOrders DESC;

/*
Business Question:
Which products are frequently purchased together?
*/

SELECT TOP 20
       X.Name AS "PRODUCT A NAME",
       Y.Name AS "PRODUCT B NAME",
       COUNT(*) AS TotalTime
FROM Sales.SalesOrderDetail A
JOIN Sales.SalesOrderDetail B
    ON A.SalesOrderID = B.SalesOrderID
JOIN Production.Product X
    ON X.ProductID = A.ProductID
JOIN Production.Product Y
    ON Y.ProductID = B.ProductID
WHERE A.ProductID <> B.ProductID AND
      A.ProductID < B.ProductID
GROUP BY X.Name , Y.Name
ORDER BY TotalTime DESC


/*
Business Question:
Goal:
Calculate month-over-month revenue growth.
*/

WITH MonthlyRevenue AS (
    SELECT FORMAT(OrderDate,'yyyy-MM') AS MonthYear ,
       SUM(TotalDue) AS TotalRevenue 
    FROM Sales.SalesOrderHeader
    GROUP BY FORMAT(OrderDate,'yyyy-MM')
),
LagMonthlyRevenue AS (
    SELECT *,
            LAG(TotalRevenue) OVER(ORDER BY MonthYear) AS PreviousMonthRevenue
    FROM MonthlyRevenue
)

SELECT MonthYear,
       TotalRevenue,
       (TotalRevenue-PreviousMonthRevenue) AS GrowthAmount,
       ROUND((TotalRevenue - PreviousMonthRevenue) / PreviousMonthRevenue * 100, 2) AS GrowthPercent
FROM LagMonthlyRevenue
ORDER BY MonthYear;