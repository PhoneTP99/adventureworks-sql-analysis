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

/*
Business Question: Customer Lifetime Value (CLV)
Goal:
Calculate the total revenue generated by each customer across all their orders.
*/


SELECT TOP 10
       CASE WHEN C.PersonID IS NOT NULL 
            THEN CONCAT(P.FirstName,' ',P.LastName) 
            ELSE S.Name 
            END As CustomerName,
       SUM(SOH.TotalDue) AS CLV
FROM Sales.SalesOrderHeader SOH
JOIN Sales.Customer C
    ON C.CustomerID = SOH.CustomerID
LEFT JOIN Person.Person P
    ON C.PersonID = P.BusinessEntityID
LEFT JOIN Sales.Store S
    ON S.BusinessEntityID = C.StoreID
GROUP BY C.PersonID , S.Name , P.FirstName , P.LastName
ORDER BY CLV DESC;


/*
Business Question: Customer Segmentation with RFM
Goal:
Segment customers based on Recency, Frequency, and Monetary value (RFM).
*/


WITH RFMTable AS (
    SELECT SOH.CustomerID,
       CASE WHEN C.PersonID IS NOT NULL 
            THEN CONCAT(P.FirstName,' ',P.LastName) 
            ELSE S.Name 
            END As CustomerName,
       DATEDIFF(Day,MAX(SOH.OrderDate),GETDATE()) AS Recency,
       COUNT(SOH.SalesOrderID) AS Frequency,
       SUM(SOH.TotalDue) AS Monetary
    FROM Sales.SalesOrderHeader SOH
    JOIN Sales.Customer C
        ON C.CustomerID = SOH.CustomerID
    LEFT JOIN Person.Person P
        ON C.PersonID = P.BusinessEntityID
    LEFT JOIN Sales.Store S
        ON S.BusinessEntityID = C.StoreID
    GROUP BY C.PersonID , S.Name , P.FirstName , P.LastName , SOH.CustomerID
),
RankedRFMTable AS (
    SELECT *,
           NTILE(5) OVER (ORDER BY Recency DESC) AS Rscore ,
           NTILE(5) OVER (ORDER BY Frequency ASC) AS Fscore ,
           NTILE(5) OVER (ORDER BY Monetary ASC) AS Mscore
    FROM RFMTable
)
SELECT 
       CASE WHEN Rscore >= 4 AND Fscore >= 4 AND Mscore >= 4 THEN 'Champion' 
            WHEN Fscore >= 3 AND Mscore >= 3 THEN 'Loyal'
            WHEN Rscore <= 2 AND Fscore >= 3 THEN  'At Risk'
            ELSE 'Regular' END AS Segment
FROM RankedRFMTable
ORDER BY Monetary DESC;

/*
Sumarrized Table
*/

WITH RFMTable AS (
    SELECT SOH.CustomerID,
       CASE WHEN C.PersonID IS NOT NULL 
            THEN CONCAT(P.FirstName,' ',P.LastName) 
            ELSE S.Name 
            END As CustomerName,
       DATEDIFF(Day,MAX(SOH.OrderDate),GETDATE()) AS Recency,
       COUNT(SOH.SalesOrderID) AS Frequency,
       SUM(SOH.TotalDue) AS Monetary
    FROM Sales.SalesOrderHeader SOH
    JOIN Sales.Customer C
        ON C.CustomerID = SOH.CustomerID
    LEFT JOIN Person.Person P
        ON C.PersonID = P.BusinessEntityID
    LEFT JOIN Sales.Store S
        ON S.BusinessEntityID = C.StoreID
    GROUP BY C.PersonID , S.Name , P.FirstName , P.LastName , SOH.CustomerID
),
RankedRFMTable AS (
    SELECT *,
           NTILE(5) OVER (ORDER BY Recency DESC) AS Rscore ,
           NTILE(5) OVER (ORDER BY Frequency ASC) AS Fscore ,
           NTILE(5) OVER (ORDER BY Monetary ASC) AS Mscore
    FROM RFMTable
),
SegmentedRFMTable AS (
    SELECT *,
           CASE WHEN Rscore >= 4 AND Fscore >= 4 AND Mscore >= 4 THEN 'Champion' 
                WHEN Fscore >= 3 AND Mscore >= 3 THEN 'Loyal'
                WHEN Rscore <= 2 AND Fscore >= 3 THEN  'At Risk'
                ELSE 'Regular' 
                END AS Segment
    FROM RankedRFMTable
)
SELECT Segment,
       COUNT(CustomerID) AS TotalCustomer,
       SUM(Monetary) AS TotalRevenue
       FROM SegmentedRFMTable
GROUP BY Segment
ORDER BY Monetary DESC;


/*
Business Question:
How does customer retention change depending on the month customers made their first purchase?
*/

WITH FirstPurchase AS (
    SELECT 
        CustomerID,
        MIN(OrderDate) AS FirstPurchaseDate,
        FORMAT(MIN(OrderDate),'yyyy-MM') AS CohortMonth
    FROM Sales.SalesOrderHeader
    GROUP BY CustomerID
),

CustomerOrders AS (
    SELECT 
        SOH.CustomerID,
        FP.CohortMonth,
        FORMAT(SOH.OrderDate,'yyyy-MM') AS OrderMonth,
        DATEDIFF(MONTH, FP.FirstPurchaseDate, SOH.OrderDate) AS CohortIndex
    FROM Sales.SalesOrderHeader SOH
    JOIN FirstPurchase FP
        ON SOH.CustomerID = FP.CustomerID
),

CohortCounts AS (
    SELECT
        CohortMonth,
        CohortIndex,
        COUNT(DISTINCT CustomerID) AS CustomerCount
    FROM CustomerOrders
    GROUP BY CohortMonth, CohortIndex
)

SELECT *
FROM CohortCounts
ORDER BY CohortMonth, CohortIndex;

/*
Business Question — Customer Lifetime Value (CLV)
What is the lifetime value of each customer, and which customers generate the most long-term revenue?
*/



SELECT TOP 10
       SOH.CustomerID,
       CASE WHEN C.PersonID IS NOT NULL 
            THEN CONCAT(P.FirstName,' ',P.LastName) 
            ELSE S.Name 
            END As CustomerName,
       MIN(SOH.OrderDate) AS FirstPurchase,
       MAX(SOH.OrderDate) AS LastPurchase,
       Count(SOH.SalesOrderID) AS TotalOrder,
       SUM(SOH.TotalDue) AS TotalRevenue,
       AVG(SOH.TotalDue) AS AOV,
       DATEDIFF(DAY,MIN(SOH.OrderDate),MAX(SOH.OrderDate)) AS LifeTime,
       CASE 
           WHEN SUM(SOH.TotalDue) > 50000 THEN 'VIP'
           WHEN SUM(SOH.TotalDue) > 20000 THEN 'High Value'
           WHEN SUM(SOH.TotalDue) > 5000 THEN 'Medium Value'
           ELSE 'Low Value'
           END AS Status
FROM Sales.SalesOrderHeader SOH
JOIN Sales.Customer C
    ON C.CustomerID = SOH.CustomerID
LEFT JOIN Person.Person P
    ON C.PersonID = P.BusinessEntityID
LEFT JOIN Sales.Store S
    ON S.BusinessEntityID = C.StoreID
GROUP BY SOH.CustomerID ,
         C.PersonID ,
         P.FirstName ,
         P.LastName ,
         S.Name 
ORDER BY TotalRevenue DESC;


/*
Business Question:
Which customers are becoming inactive?

Definition:
A customer is inactive if they haven't purchased in the last 180 days.
*/


SELECT TOP 10
       SOH.CustomerID,
       CASE WHEN C.PersonID IS NOT NULL 
            THEN CONCAT(P.FirstName,' ',P.LastName) 
            ELSE S.Name 
            END As CustomerName,
       MAX(SOH.OrderDate) AS LastPurchase,
       DATEDIFF(DAY, MAX(SOH.OrderDate),GETDATE()) AS DaysSinceLastOrder,
       CASE WHEN DATEDIFF(DAY, MAX(SOH.OrderDate),GETDATE()) > 180 THEN 'Inactive'
            ELSE 'Active'
            END AS Status
FROM Sales.SalesOrderHeader SOH
JOIN Sales.Customer C
    ON C.CustomerID = SOH.CustomerID
LEFT JOIN Person.Person P
    ON C.PersonID = P.BusinessEntityID
LEFT JOIN Sales.Store S
    ON S.BusinessEntityID = C.StoreID
GROUP BY SOH.CustomerID ,
         C.PersonID ,
         P.FirstName ,
         P.LastName ,
         S.Name 
ORDER BY DaysSinceLastOrder ASC;


/*
Business Question — Category Sales Trend & Risk
Question
Which product categories are at risk due to declining sales over the past months?

Goal:
Identify categories with falling revenue.
Flag them for management action or promotion.
*/



WITH monthly_category_revenue AS (

    SELECT
        pc.Name AS category_name,
        FORMAT(soh.OrderDate, 'yyyy-MM') AS month_year,
        SUM(sod.LineTotal) AS total_revenue

    FROM Sales.SalesOrderDetail sod

    JOIN Production.Product p
        ON p.ProductID = sod.ProductID

    JOIN Production.ProductSubcategory ps
        ON ps.ProductSubcategoryID = p.ProductSubcategoryID

    JOIN Production.ProductCategory pc
        ON pc.ProductCategoryID = ps.ProductCategoryID

    JOIN Sales.SalesOrderHeader soh
        ON soh.SalesOrderID = sod.SalesOrderID

    GROUP BY
        pc.Name,
        FORMAT(soh.OrderDate, 'yyyy-MM')

),

category_growth AS (

    SELECT
        *,
        LAG(total_revenue) OVER(
            PARTITION BY category_name
            ORDER BY month_year
        ) AS previous_month_revenue

    FROM monthly_category_revenue

)

SELECT
    *,
    (total_revenue - previous_month_revenue)
        * 100.0 / NULLIF(previous_month_revenue,0) AS month_over_month_growth,

    CASE
        WHEN (total_revenue - previous_month_revenue)
             * 100.0 / NULLIF(previous_month_revenue,0) < 0
        THEN 'At Risk'
        ELSE 'Stable'
    END AS risk_status

FROM category_growth
ORDER BY
    category_name,
    month_year;


/*
Business Question — Product Launch & Sales Performance
Question:
How do newly launched products perform over time? Which ones are trending or underperforming?
*/

WITH product_first_sale AS (
    SELECT
        p.Name AS ProductName,
        FORMAT(MIN(soh.OrderDate), 'yyyy-MM') AS FirstSaleMonth,
        SUM(sod.LineTotal) AS TotalRevenue
    FROM Sales.SalesOrderDetail sod
    JOIN Sales.SalesOrderHeader soh
        ON soh.SalesOrderID = sod.SalesOrderID
    JOIN Production.Product p
        ON p.ProductID = sod.ProductID
    GROUP BY p.Name
),
ranked_products AS (
    SELECT *,
           RANK() OVER(
               PARTITION BY FirstSaleMonth
               ORDER BY TotalRevenue DESC
           ) AS Rank
    FROM product_first_sale
)
SELECT *
FROM ranked_products
WHERE Rank <= 3
ORDER BY FirstSaleMonth, Rank; 



