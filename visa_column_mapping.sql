-- Connecting query from Kevin
IF OBJECT_ID('tempdb..#VisaTxn') IS NOT NULL
    DROP TABLE #VisaTxn;

SELECT
    t.[Fact_FinancialTransaction_Key],
    t.[Transaction_Reference_Number],
    t.[Transaction_ID],
    t.[Time_Post],
    t.[Business_Date],
    t.[Account_Number],
    t.[Transaction_Date],
    t.[Transaction_Amount],
    t.[Currency_Code],
    t.[Tsys_Product_Code],
    t.[Client_Product_Code],
    t.[Merchant_SIC_Class_Code],
    t.[Merchant_Dba_Country],
    t.[Merchant_Dba_Name],
    t.[Merchant_Dba_City],
    t.[Class_Code],
    t.[Debit_Credit_Indicator],
    a.[Auto_Payment_Option_Set],
    c.[Dim_Card_Key],
    c.[Card_Number],
    c.[Masked_Card_Number],
    p.[First_Name],
    p.[Last_Name],
    p.[Party_Type_Code],
    CASE
        WHEN p.[Party_Type_Code] = 'P' THEN 'Personal'
        WHEN p.[Party_Type_Code] = 'B' THEN 'Business'
        ELSE p.[Party_Type_Code]
    END AS Party_Type_Code_Desc,
    p.[Party_Category_Code],
    CASE
        WHEN p.[Party_Category_Code] = '0' THEN 'Primary'
        WHEN p.[Party_Category_Code] = '2' THEN 'Authorized user'
        WHEN p.[Party_Category_Code] = '3' THEN 'Business'
        ELSE p.[Party_Category_Code]
    END AS Party_Category_Code_Desc,
    p.[Party_Deceased_Flag]
INTO #VisaTxn
FROM [dbo].[Fact_FinancialTransaction_Visa] t
LEFT JOIN [dbo].[Dim_FinancialAccount_Visa] a
    ON a.[Dim_FinancialAccount_Key] = t.[Dim_FinancialAccount_Key]
LEFT JOIN [dbo].[Dim_Card_Visa] c
    ON c.[Dim_Card_Key] = t.[Dim_Card_Key]
LEFT JOIN [dbo].[Dim_Party_Visa] p
    ON p.[Dim_Party_Key] = c.[Party_ID]
WHERE t.[Transaction_Date] >= '2026-01-01'
  AND t.[Transaction_Date] <= '2026-01-31';

SELECT TOP 100 *
FROM #VisaTxn;

SELECT *
FROM #VisaTxn
WHERE Account_Number IN (
    SELECT Account_Number
    FROM #VisaTxn
    GROUP BY Account_Number
    HAVING COUNT(DISTINCT Masked_Card_Number) > 1
)
ORDER BY Account_Number, Dim_Card_Key, Transaction_Date, Time_Post;


-- Example of avg pv amt april 2024 to may 2025
SELECT 
    Account_Number,
    AVG(Transaction_Amount) AS AVG_PV_AMT_Apr24_May25
FROM Fact_FinancialTransaction_Visa
WHERE Transaction_Date >= '2024-04-01'
  AND Transaction_Date < '2025-06-01'
GROUP BY Account_Number

-- Example of avg transaction count april 2024 to may 2025
SELECT 
    Account_Number,
    COUNT(*) AS transaction_count
FROM Fact_FinancialTransaction_Visa
WHERE Transaction_Date >= '2024-04-01'
  AND Transaction_Date < '2025-06-01'
GROUP BY Account_Number

-- How to calculate Utilization rate per account
-- join Fact_FinancialAccount_Visa and Dim_FinancialAccount_Visa table by account number
SELECT 
    f.Account_Number,
    f.Current_Balance,
    d.Credit_Limit,
    CASE WHEN d.Credit_Limit > 0 
         THEN f.Current_Balance * 1.0 / d.Credit_Limit 
         ELSE NULL END AS Utilization_Rate
FROM Fact_FinancialAccount_Visa f
JOIN Dim_FinancialAccount_Visa d
  ON f.Account_Number = d.Account_Number
WHERE f.Business_Date < '2026-03-31'
  AND d.Date_Last_Limit_Change <= '2025-03-31'
GROUP BY f.Account_Number, f.Current_Balance, d.Credit_Limit


SELECT DISTINCT(Last_Credit_Bureau_Score)
FROM Fact_FinancialAccount_Visa

SELECT TOP 10 Party_ID
FROM dbo.Dim_Party_Visa



SELECT TOP 200 * 
FROM Unified.Br_Party_Unified


SELECT DISTINCT Source_System_Name
FROM Unified.Br_Party_Unified

SELECT TOP 10 Unified_Party_ID
FROM Unified.Br_Party_Unified
WHERE Source_System_Name = 'Visa 2'


SELECT *
FROM Unified.Br_Party_Unified
WHERE Unified_Party_ID = 426423


SELECT Party_ID, first_name, last_name, date_of_birth
FROM dbo.Dim_Party_Visa
WHERE Party_ID = 199344
-- RITA VANDER RAADT



SELECT Party_ID, first_name, last_name, date_of_birth
FROM dbo.Dim_Party_Visa
WHERE Party_ID = 00000169167
-- arlene yergatian


