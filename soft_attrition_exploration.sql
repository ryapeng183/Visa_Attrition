/*
================================================================================
SOFT ATTRITION DEFINITION - Churn Prediction Model
================================================================================
Objective: Identify members showing signs of engagement decline (soft attrition)
while maintaining active accounts.

DEFINITION:
Soft Attrition = A measurable decrease in member engagement with Visa over a 
defined period (120 days), while the account remains open. The member has 
established transaction history and is in the longer-tenured cohort (12-23 months).

COMPOSITE ATTRITION RULES:
1. Spend-Volume Decay: X% decrease in transaction spending
2. Transaction-Frequency Decay: X% decrease in transaction count/cadence
3. Category-Breadth Contraction: Decrease in unique MCC categories
4. Composite Engagement Score: RFM decline combined with category breadth drop

MEMBER COHORT CRITERIA:
- Account tenure: 12-23 months
- Established transaction history
- Account status: Active (open)
- Account holder type: Primary personal

================================================================================
*/

-- ============================================================================
-- STEP 1: DEFINE MEMBER COHORT (12-23 months tenure with established history)
-- ============================================================================

IF OBJECT_ID('tempdb..#MemberCohort') IS NOT NULL
    DROP TABLE #MemberCohort;

DECLARE @AsOfDate DATE = '2026-06-09';          -- Current observation date
DECLARE @BaselineWindowEnd DATE = '2026-02-09'; -- 120 days prior
DECLARE @BaselineWindowStart DATE = '2025-10-12'; -- 240 days prior (240-120 day baseline)
DECLARE @HistoricalCutoff DATE = '2025-03-09'; -- Historical baseline start (270 days prior)

-- Members in 12-23 month tenure window with established transaction history
SELECT 
    pv.[Dim_Party_Key],
    pv.[Party_ID],
    da.[Account_Number],
    da.[Dim_FinancialAccount_Key],
    da.[Tsys_Product_Code],
    da.[Client_Product_Code],
    da.[Credit_Limit],
    da.[Acquisition_Strategy_Code],
    da.[Account_Open_Date],
    DATEDIFF(DAY, da.[Account_Open_Date], @AsOfDate) AS Days_Since_Account_Open,
    DATEDIFF(MONTH, da.[Account_Open_Date], @AsOfDate) AS Months_Since_Account_Open,
    CASE 
        WHEN DATEDIFF(MONTH, da.[Account_Open_Date], @AsOfDate) BETWEEN 12 AND 23 THEN 1
        ELSE 0
    END AS In_Target_Tenure_Window
INTO #MemberCohort
FROM [dbo].[Dim_FinancialAccount_Visa] da
    LEFT JOIN [dbo].[Dim_Party_Visa] pv
        ON pv.[Account_Number] = da.[Account_Number]
        AND pv.[Party_Type_Code] = 'P'
        AND pv.[Party_Category_Code] = '0'
        AND pv.[Party_Deceased_Flag] = 'N'
        AND pv.[Effective_Date] <= @AsOfDate
        AND (pv.[End_Date] = '9999-12-31' OR pv.[End_Date] > @AsOfDate)
WHERE da.[Account_Status_Code] IN ('A', 'O')  -- Active, Open
    AND DATEDIFF(MONTH, da.[Account_Open_Date], @AsOfDate) BETWEEN 12 AND 23
ORDER BY pv.[Party_ID];

-- ============================================================================
-- STEP 2: CALCULATE SPEND-VOLUME DECAY (Recent vs Baseline Period)
-- ============================================================================

IF OBJECT_ID('tempdb..#SpendVolumeMetrics') IS NOT NULL
    DROP TABLE #SpendVolumeMetrics;

SELECT 
    mc.[Party_ID],
    mc.[Account_Number],
    mc.[Dim_Party_Key],
    
    -- Recent Period: Last 120 days (Feb 9 - Jun 9)
    COALESCE(SUM(CASE 
        WHEN ft.[Transaction_Date] BETWEEN @BaselineWindowEnd AND @AsOfDate
            AND tc.[Transaction_Category] NOT IN ('Payment', 'Fee Reversals', 'Interest Reversals', 'Reversal Fee')
        THEN ABS(ft.[Transaction_Amount])
        ELSE 0
    END), 0) AS Recent_Period_Spend_120d,
    
    -- Baseline Period: 120-240 days ago (Oct 12 - Feb 9)
    COALESCE(SUM(CASE 
        WHEN ft.[Transaction_Date] BETWEEN @BaselineWindowStart AND @BaselineWindowEnd
            AND tc.[Transaction_Category] NOT IN ('Payment', 'Fee Reversals', 'Interest Reversals', 'Reversal Fee')
        THEN ABS(ft.[Transaction_Amount])
        ELSE 0
    END), 0) AS Baseline_Period_Spend_120d,
    
    -- Recency: Days since last transaction
    DATEDIFF(DAY, MAX(CASE WHEN ft.[Transaction_Date] <= @AsOfDate THEN ft.[Transaction_Date] END), @AsOfDate) AS Days_Since_Last_Transaction

INTO #SpendVolumeMetrics
FROM #MemberCohort mc
    LEFT JOIN [dbo].[Fact_FinancialTransaction_Visa] ft
        ON ft.[Account_Number] = mc.[Account_Number]
        AND ft.[Transaction_Date] >= @HistoricalCutoff
        AND ft.[Debit_Credit_Indicator] = 'D'  -- Only debits (spending)
    LEFT JOIN [dbo].[Dim_Card_Visa] c
        ON c.[Dim_Card_Key] = ft.[Dim_Card_Key]
    LEFT JOIN [dbo].[Dim_Party_Visa] party_check
        ON party_check.[Dim_Party_Key] = c.[Party_ID]
        AND party_check.[Party_Category_Code] = '0'  -- Primary only
        AND party_check.[Effective_Date] <= @AsOfDate
        AND (party_check.[End_Date] = '9999-12-31' OR party_check.[End_Date] > @AsOfDate)
    -- Join transaction codes to filter out non-purchase transactions
    LEFT JOIN (
        SELECT '1001' AS Code UNION ALL SELECT '0101' UNION ALL SELECT '1098' UNION ALL 
        SELECT '0104' UNION ALL SELECT '1003' UNION ALL SELECT '1002' UNION ALL 
        SELECT '0102' UNION ALL SELECT '1006' UNION ALL SELECT '0106' UNION ALL 
        SELECT '1026' UNION ALL SELECT '1025' UNION ALL SELECT '1038'
    ) tc ON CAST(ft.[Tsys_Product_Code] AS VARCHAR(4)) = tc.[Code]
GROUP BY mc.[Party_ID], mc.[Account_Number], mc.[Dim_Party_Key];

-- ============================================================================
-- STEP 3: CALCULATE TRANSACTION-FREQUENCY DECAY (Count and Cadence)
-- ============================================================================

IF OBJECT_ID('tempdb..#TransactionFrequencyMetrics') IS NOT NULL
    DROP TABLE #TransactionFrequencyMetrics;

SELECT 
    mc.[Party_ID],
    mc.[Account_Number],
    
    -- Recent Period: Transaction count (120 days)
    COUNT(DISTINCT CASE 
        WHEN ft.[Transaction_Date] BETWEEN @BaselineWindowEnd AND @AsOfDate
            AND tc.[Transaction_Category] NOT IN ('Payment', 'Fee Reversals', 'Interest Reversals', 'Reversal Fee')
        THEN ft.[Fact_FinancialTransaction_Key]
    END) AS Recent_Period_Transaction_Count_120d,
    
    -- Baseline Period: Transaction count (120 days)
    COUNT(DISTINCT CASE 
        WHEN ft.[Transaction_Date] BETWEEN @BaselineWindowStart AND @BaselineWindowEnd
            AND tc.[Transaction_Category] NOT IN ('Payment', 'Fee Reversals', 'Interest Reversals', 'Reversal Fee')
        THEN ft.[Fact_FinancialTransaction_Key]
    END) AS Baseline_Period_Transaction_Count_120d,
    
    -- Average days between transactions (recent period)
    CASE 
        WHEN COUNT(DISTINCT CASE 
            WHEN ft.[Transaction_Date] BETWEEN @BaselineWindowEnd AND @AsOfDate
                AND tc.[Transaction_Category] NOT IN ('Payment', 'Fee Reversals', 'Interest Reversals', 'Reversal Fee')
            THEN CAST(ft.[Transaction_Date] AS DATE)
        END) > 1 
        THEN CAST(120.0 / NULLIF(COUNT(DISTINCT CASE 
            WHEN ft.[Transaction_Date] BETWEEN @BaselineWindowEnd AND @AsOfDate
                AND tc.[Transaction_Category] NOT IN ('Payment', 'Fee Reversals', 'Interest Reversals', 'Reversal Fee')
            THEN CAST(ft.[Transaction_Date] AS DATE)
        END), 0) AS DECIMAL(10, 2))
        ELSE NULL
    END AS Recent_Avg_Days_Between_Transactions,
    
    -- Average days between transactions (baseline period)
    CASE 
        WHEN COUNT(DISTINCT CASE 
            WHEN ft.[Transaction_Date] BETWEEN @BaselineWindowStart AND @BaselineWindowEnd
                AND tc.[Transaction_Category] NOT IN ('Payment', 'Fee Reversals', 'Interest Reversals', 'Reversal Fee')
            THEN CAST(ft.[Transaction_Date] AS DATE)
        END) > 1 
        THEN CAST(120.0 / NULLIF(COUNT(DISTINCT CASE 
            WHEN ft.[Transaction_Date] BETWEEN @BaselineWindowStart AND @BaselineWindowEnd
                AND tc.[Transaction_Category] NOT IN ('Payment', 'Fee Reversals', 'Interest Reversals', 'Reversal Fee')
            THEN CAST(ft.[Transaction_Date] AS DATE)
        END), 0) AS DECIMAL(10, 2))
        ELSE NULL
    END AS Baseline_Avg_Days_Between_Transactions

INTO #TransactionFrequencyMetrics
FROM #MemberCohort mc
    LEFT JOIN [dbo].[Fact_FinancialTransaction_Visa] ft
        ON ft.[Account_Number] = mc.[Account_Number]
        AND ft.[Transaction_Date] >= @HistoricalCutoff
        AND ft.[Debit_Credit_Indicator] = 'D'
    LEFT JOIN [dbo].[Dim_Card_Visa] c
        ON c.[Dim_Card_Key] = ft.[Dim_Card_Key]
    LEFT JOIN [dbo].[Dim_Party_Visa] party_check
        ON party_check.[Dim_Party_Key] = c.[Party_ID]
        AND party_check.[Party_Category_Code] = '0'
        AND party_check.[Effective_Date] <= @AsOfDate
        AND (party_check.[End_Date] = '9999-12-31' OR party_check.[End_Date] > @AsOfDate)
    LEFT JOIN (
        SELECT '1001' AS Code UNION ALL SELECT '0101' UNION ALL SELECT '1098' UNION ALL 
        SELECT '0104' UNION ALL SELECT '1003' UNION ALL SELECT '1002' UNION ALL 
        SELECT '0102' UNION ALL SELECT '1006' UNION ALL SELECT '0106' UNION ALL 
        SELECT '1026' UNION ALL SELECT '1025' UNION ALL SELECT '1038'
    ) tc ON CAST(ft.[Tsys_Product_Code] AS VARCHAR(4)) = tc.[Code]
GROUP BY mc.[Party_ID], mc.[Account_Number];

-- ============================================================================
-- STEP 4: CALCULATE CATEGORY-BREADTH CONTRACTION (MCC Diversity)
-- ============================================================================

IF OBJECT_ID('tempdb..#CategoryBreadthMetrics') IS NOT NULL
    DROP TABLE #CategoryBreadthMetrics;

SELECT 
    mc.[Party_ID],
    mc.[Account_Number],
    
    -- Recent Period: Unique MCC categories
    COUNT(DISTINCT CASE 
        WHEN ft.[Transaction_Date] BETWEEN @BaselineWindowEnd AND @AsOfDate
            AND tc.[Transaction_Category] NOT IN ('Payment', 'Fee Reversals', 'Interest Reversals', 'Reversal Fee')
        THEN ft.[Merchant_SIC_Class_Code]
    END) AS Recent_Period_Unique_MCCs_120d,
    
    -- Baseline Period: Unique MCC categories
    COUNT(DISTINCT CASE 
        WHEN ft.[Transaction_Date] BETWEEN @BaselineWindowStart AND @BaselineWindowEnd
            AND tc.[Transaction_Category] NOT IN ('Payment', 'Fee Reversals', 'Interest Reversals', 'Reversal Fee')
        THEN ft.[Merchant_SIC_Class_Code]
    END) AS Baseline_Period_Unique_MCCs_120d,
    
    -- Recent Period: Unique merchants
    COUNT(DISTINCT CASE 
        WHEN ft.[Transaction_Date] BETWEEN @BaselineWindowEnd AND @AsOfDate
            AND tc.[Transaction_Category] NOT IN ('Payment', 'Fee Reversals', 'Interest Reversals', 'Reversal Fee')
        THEN ft.[Merchant_Dba_Name]
    END) AS Recent_Period_Unique_Merchants_120d

INTO #CategoryBreadthMetrics
FROM #MemberCohort mc
    LEFT JOIN [dbo].[Fact_FinancialTransaction_Visa] ft
        ON ft.[Account_Number] = mc.[Account_Number]
        AND ft.[Transaction_Date] >= @HistoricalCutoff
        AND ft.[Debit_Credit_Indicator] = 'D'
    LEFT JOIN [dbo].[Dim_Card_Visa] c
        ON c.[Dim_Card_Key] = ft.[Dim_Card_Key]
    LEFT JOIN [dbo].[Dim_Party_Visa] party_check
        ON party_check.[Dim_Party_Key] = c.[Party_ID]
        AND party_check.[Party_Category_Code] = '0'
        AND party_check.[Effective_Date] <= @AsOfDate
        AND (party_check.[End_Date] = '9999-12-31' OR party_check.[End_Date] > @AsOfDate)
    LEFT JOIN (
        SELECT '1001' AS Code UNION ALL SELECT '0101' UNION ALL SELECT '1098' UNION ALL 
        SELECT '0104' UNION ALL SELECT '1003' UNION ALL SELECT '1002' UNION ALL 
        SELECT '0102' UNION ALL SELECT '1006' UNION ALL SELECT '0106' UNION ALL 
        SELECT '1026' UNION ALL SELECT '1025' UNION ALL SELECT '1038'
    ) tc ON CAST(ft.[Tsys_Product_Code] AS VARCHAR(4)) = tc.[Code]
GROUP BY mc.[Party_ID], mc.[Account_Number];

-- ============================================================================
-- STEP 5: CALCULATE RFM (RECENCY-FREQUENCY-MONETARY) + BREADTH SCORE
-- ============================================================================

IF OBJECT_ID('tempdb..#RFMMetrics') IS NOT NULL
    DROP TABLE #RFMMetrics;

SELECT 
    mc.[Party_ID],
    mc.[Account_Number],
    
    -- RECENCY: Days since last purchase
    DATEDIFF(DAY, MAX(CASE 
        WHEN ft.[Transaction_Date] <= @AsOfDate
            AND tc.[Transaction_Category] NOT IN ('Payment', 'Fee Reversals', 'Interest Reversals', 'Reversal Fee')
        THEN ft.[Transaction_Date] 
    END), @AsOfDate) AS Recency_Days,
    
    -- FREQUENCY: Transaction count in recent 120 days
    COUNT(DISTINCT CASE 
        WHEN ft.[Transaction_Date] BETWEEN @BaselineWindowEnd AND @AsOfDate
            AND tc.[Transaction_Category] NOT IN ('Payment', 'Fee Reversals', 'Interest Reversals', 'Reversal Fee')
        THEN ft.[Fact_FinancialTransaction_Key]
    END) AS Frequency_Recent_120d,
    
    -- MONETARY: Total spend in recent 120 days
    COALESCE(SUM(CASE 
        WHEN ft.[Transaction_Date] BETWEEN @BaselineWindowEnd AND @AsOfDate
            AND tc.[Transaction_Category] NOT IN ('Payment', 'Fee Reversals', 'Interest Reversals', 'Reversal Fee')
        THEN ABS(ft.[Transaction_Amount])
        ELSE 0
    END), 0) AS Monetary_Recent_120d,
    
    -- BREADTH: Unique categories in recent 120 days
    COUNT(DISTINCT CASE 
        WHEN ft.[Transaction_Date] BETWEEN @BaselineWindowEnd AND @AsOfDate
            AND tc.[Transaction_Category] NOT IN ('Payment', 'Fee Reversals', 'Interest Reversals', 'Reversal Fee')
        THEN ft.[Merchant_SIC_Class_Code]
    END) AS Breadth_Unique_MCCs_Recent_120d

INTO #RFMMetrics
FROM #MemberCohort mc
    LEFT JOIN [dbo].[Fact_FinancialTransaction_Visa] ft
        ON ft.[Account_Number] = mc.[Account_Number]
        AND ft.[Transaction_Date] >= @HistoricalCutoff
        AND ft.[Debit_Credit_Indicator] = 'D'
    LEFT JOIN [dbo].[Dim_Card_Visa] c
        ON c.[Dim_Card_Key] = ft.[Dim_Card_Key]
    LEFT JOIN [dbo].[Dim_Party_Visa] party_check
        ON party_check.[Dim_Party_Key] = c.[Party_ID]
        AND party_check.[Party_Category_Code] = '0'
        AND party_check.[Effective_Date] <= @AsOfDate
        AND (party_check.[End_Date] = '9999-12-31' OR party_check.[End_Date] > @AsOfDate)
    LEFT JOIN (
        SELECT '1001' AS Code UNION ALL SELECT '0101' UNION ALL SELECT '1098' UNION ALL 
        SELECT '0104' UNION ALL SELECT '1003' UNION ALL SELECT '1002' UNION ALL 
        SELECT '0102' UNION ALL SELECT '1006' UNION ALL SELECT '0106' UNION ALL 
        SELECT '1026' UNION ALL SELECT '1025' UNION ALL SELECT '1038'
    ) tc ON CAST(ft.[Tsys_Product_Code] AS VARCHAR(4)) = tc.[Code]
GROUP BY mc.[Party_ID], mc.[Account_Number];

-- ============================================================================
-- STEP 6: COMBINE ALL METRICS AND DEFINE SOFT ATTRITION
-- ============================================================================

IF OBJECT_ID('tempdb..#SoftAttritionDefinition') IS NOT NULL
    DROP TABLE #SoftAttritionDefinition;

SELECT 
    mc.[Party_ID],
    mc.[Account_Number],
    mc.[Dim_Party_Key],
    mc.[Tsys_Product_Code],
    mc.[Client_Product_Code],
    mc.[Credit_Limit],
    mc.[Months_Since_Account_Open],
    @AsOfDate AS Observation_Date,
    
    -- ===== SPEND-VOLUME DECAY =====
    COALESCE(sv.[Recent_Period_Spend_120d], 0) AS Spend_Recent_120d,
    COALESCE(sv.[Baseline_Period_Spend_120d], 0) AS Spend_Baseline_120d,
    CASE 
        WHEN COALESCE(sv.[Baseline_Period_Spend_120d], 0) > 0
        THEN ROUND((COALESCE(sv.[Recent_Period_Spend_120d], 0) - COALESCE(sv.[Baseline_Period_Spend_120d], 0)) * 100.0 / COALESCE(sv.[Baseline_Period_Spend_120d], 0), 2)
        ELSE NULL
    END AS Spend_Volume_Decay_Pct,
    
    -- ===== TRANSACTION-FREQUENCY DECAY =====
    COALESCE(tf.[Recent_Period_Transaction_Count_120d], 0) AS Txn_Count_Recent_120d,
    COALESCE(tf.[Baseline_Period_Transaction_Count_120d], 0) AS Txn_Count_Baseline_120d,
    CASE 
        WHEN COALESCE(tf.[Baseline_Period_Transaction_Count_120d], 0) > 0
        THEN ROUND((COALESCE(tf.[Recent_Period_Transaction_Count_120d], 0) - COALESCE(tf.[Baseline_Period_Transaction_Count_120d], 0)) * 100.0 / COALESCE(tf.[Baseline_Period_Transaction_Count_120d], 0), 2)
        ELSE NULL
    END AS Txn_Frequency_Decay_Pct,
    
    COALESCE(tf.[Recent_Avg_Days_Between_Transactions], 0) AS Recent_Avg_Days_Between_Txns,
    COALESCE(tf.[Baseline_Avg_Days_Between_Transactions], 0) AS Baseline_Avg_Days_Between_Txns,
    CASE 
        WHEN COALESCE(tf.[Baseline_Avg_Days_Between_Transactions], 0) > 0
        THEN ROUND((COALESCE(tf.[Recent_Avg_Days_Between_Transactions], 0) - COALESCE(tf.[Baseline_Avg_Days_Between_Transactions], 0)) * 100.0 / COALESCE(tf.[Baseline_Avg_Days_Between_Transactions], 0), 2)
        ELSE NULL
    END AS Cadence_Decay_Pct,
    
    -- ===== CATEGORY-BREADTH CONTRACTION =====
    COALESCE(cb.[Recent_Period_Unique_MCCs_120d], 0) AS MCC_Count_Recent_120d,
    COALESCE(cb.[Baseline_Period_Unique_MCCs_120d], 0) AS MCC_Count_Baseline_120d,
    CASE 
        WHEN COALESCE(cb.[Baseline_Period_Unique_MCCs_120d], 0) > 0
        THEN ROUND((COALESCE(cb.[Recent_Period_Unique_MCCs_120d], 0) - COALESCE(cb.[Baseline_Period_Unique_MCCs_120d], 0)) * 100.0 / COALESCE(cb.[Baseline_Period_Unique_MCCs_120d], 0), 2)
        ELSE NULL
    END AS MCC_Breadth_Contraction_Pct,
    
    COALESCE(cb.[Recent_Period_Unique_Merchants_120d], 0) AS Merchant_Count_Recent_120d,
    
    -- ===== RFM + BREADTH COMPOSITE SCORE =====
    rfm.[Recency_Days],
    rfm.[Frequency_Recent_120d],
    rfm.[Monetary_Recent_120d],
    rfm.[Breadth_Unique_MCCs_Recent_120d],
    
    -- ===== SOFT ATTRITION FLAGS & COMPOSITE SCORE =====
    -- Individual component flags (flagging if decay > 20% or breadth decreased)
    CASE WHEN COALESCE(sv.[Baseline_Period_Spend_120d], 0) > 0 
        AND (COALESCE(sv.[Recent_Period_Spend_120d], 0) - COALESCE(sv.[Baseline_Period_Spend_120d], 0)) * 100.0 / COALESCE(sv.[Baseline_Period_Spend_120d], 0) < -20 
        THEN 1 ELSE 0 
    END AS Flag_Spend_Volume_Decay,
    
    CASE WHEN COALESCE(tf.[Baseline_Period_Transaction_Count_120d], 0) > 0 
        AND (COALESCE(tf.[Recent_Period_Transaction_Count_120d], 0) - COALESCE(tf.[Baseline_Period_Transaction_Count_120d], 0)) * 100.0 / COALESCE(tf.[Baseline_Period_Transaction_Count_120d], 0) < -20 
        THEN 1 ELSE 0 
    END AS Flag_Txn_Frequency_Decay,
    
    CASE WHEN COALESCE(cb.[Baseline_Period_Unique_MCCs_120d], 0) > 0 
        AND COALESCE(cb.[Recent_Period_Unique_MCCs_120d], 0) < COALESCE(cb.[Baseline_Period_Unique_MCCs_120d], 0) 
        THEN 1 ELSE 0 
    END AS Flag_MCC_Breadth_Contraction,
    
    -- Composite Engagement: Combine RFM signals with breadth
    CASE 
        WHEN rfm.[Recency_Days] > 30 OR rfm.[Frequency_Recent_120d] = 0 THEN 1
        ELSE 0
    END AS Flag_Poor_Recency,
    
    CASE 
        WHEN rfm.[Breadth_Unique_MCCs_Recent_120d] = 0 THEN 1
        WHEN COALESCE(cb.[Baseline_Period_Unique_MCCs_120d], 0) > 0 
        AND rfm.[Breadth_Unique_MCCs_Recent_120d] < COALESCE(cb.[Baseline_Period_Unique_MCCs_120d], 0) * 0.5 THEN 1
        ELSE 0
    END AS Flag_Breadth_Collapse,
    
    -- Overall Soft Attrition: Requires at least 2 of 4 decay indicators
    CASE 
        WHEN (
            -- Spend-volume decay > 20%
            (COALESCE(sv.[Baseline_Period_Spend_120d], 0) > 0 
                AND (COALESCE(sv.[Recent_Period_Spend_120d], 0) - COALESCE(sv.[Baseline_Period_Spend_120d], 0)) * 100.0 / COALESCE(sv.[Baseline_Period_Spend_120d], 0) < -20)
            -- Transaction frequency decay > 20%
            + (COALESCE(tf.[Baseline_Period_Transaction_Count_120d], 0) > 0 
                AND (COALESCE(tf.[Recent_Period_Transaction_Count_120d], 0) - COALESCE(tf.[Baseline_Period_Transaction_Count_120d], 0)) * 100.0 / COALESCE(tf.[Baseline_Period_Transaction_Count_120d], 0) < -20)
            -- MCC breadth contraction
            + (COALESCE(cb.[Baseline_Period_Unique_MCCs_120d], 0) > 0 
                AND COALESCE(cb.[Recent_Period_Unique_MCCs_120d], 0) < COALESCE(cb.[Baseline_Period_Unique_MCCs_120d], 0))
            -- Engagement score collapse (recency > 30 days OR no frequency + breadth > 50% reduction)
            + (rfm.[Recency_Days] > 30 OR (rfm.[Frequency_Recent_120d] = 0 AND rfm.[Breadth_Unique_MCCs_Recent_120d] < COALESCE(cb.[Baseline_Period_Unique_MCCs_120d], 0) * 0.5))
        ) >= 2 THEN 1
        ELSE 0
    END AS Soft_Attrition_Flag,
    
    -- Attrition Severity Score (0-4 scale based on number of triggered components)
    (
        CASE WHEN COALESCE(sv.[Baseline_Period_Spend_120d], 0) > 0 
            AND (COALESCE(sv.[Recent_Period_Spend_120d], 0) - COALESCE(sv.[Baseline_Period_Spend_120d], 0)) * 100.0 / COALESCE(sv.[Baseline_Period_Spend_120d], 0) < -20 
            THEN 1 ELSE 0 
        END
        + CASE WHEN COALESCE(tf.[Baseline_Period_Transaction_Count_120d], 0) > 0 
            AND (COALESCE(tf.[Recent_Period_Transaction_Count_120d], 0) - COALESCE(tf.[Baseline_Period_Transaction_Count_120d], 0)) * 100.0 / COALESCE(tf.[Baseline_Period_Transaction_Count_120d], 0) < -20 
            THEN 1 ELSE 0 
        END
        + CASE WHEN COALESCE(cb.[Baseline_Period_Unique_MCCs_120d], 0) > 0 
            AND COALESCE(cb.[Recent_Period_Unique_MCCs_120d], 0) < COALESCE(cb.[Baseline_Period_Unique_MCCs_120d], 0) 
            THEN 1 ELSE 0 
        END
        + CASE WHEN rfm.[Recency_Days] > 30 OR (rfm.[Frequency_Recent_120d] = 0 AND rfm.[Breadth_Unique_MCCs_Recent_120d] < COALESCE(cb.[Baseline_Period_Unique_MCCs_120d], 0) * 0.5)
            THEN 1 ELSE 0 
        END
    ) AS Attrition_Severity_Score

INTO #SoftAttritionDefinition
FROM #MemberCohort mc
    LEFT JOIN #SpendVolumeMetrics sv
        ON sv.[Party_ID] = mc.[Party_ID]
    LEFT JOIN #TransactionFrequencyMetrics tf
        ON tf.[Party_ID] = mc.[Party_ID]
    LEFT JOIN #CategoryBreadthMetrics cb
        ON cb.[Party_ID] = mc.[Party_ID]
    LEFT JOIN #RFMMetrics rfm
        ON rfm.[Party_ID] = mc.[Party_ID];

-- ============================================================================
-- FINAL OUTPUT: Members with Soft Attrition Indicators
-- ============================================================================

SELECT 
    [Party_ID],
    [Account_Number],
    [Months_Since_Account_Open],
    [Observation_Date],
    
    -- Spend Metrics
    [Spend_Recent_120d],
    [Spend_Baseline_120d],
    [Spend_Volume_Decay_Pct],
    
    -- Frequency Metrics
    [Txn_Count_Recent_120d],
    [Txn_Count_Baseline_120d],
    [Txn_Frequency_Decay_Pct],
    [Recent_Avg_Days_Between_Txns],
    [Baseline_Avg_Days_Between_Txns],
    [Cadence_Decay_Pct],
    
    -- Breadth Metrics
    [MCC_Count_Recent_120d],
    [MCC_Count_Baseline_120d],
    [MCC_Breadth_Contraction_Pct],
    [Merchant_Count_Recent_120d],
    
    -- RFM Metrics
    [Recency_Days],
    [Frequency_Recent_120d],
    [Monetary_Recent_120d],
    [Breadth_Unique_MCCs_Recent_120d],
    
    -- Flags
    [Flag_Spend_Volume_Decay],
    [Flag_Txn_Frequency_Decay],
    [Flag_MCC_Breadth_Contraction],
    [Flag_Poor_Recency],
    [Flag_Breadth_Collapse],
    
    -- Attrition Classification
    [Soft_Attrition_Flag],
    [Attrition_Severity_Score],
    CASE 
        WHEN [Attrition_Severity_Score] = 0 THEN 'Stable'
        WHEN [Attrition_Severity_Score] = 1 THEN 'Minor Decay'
        WHEN [Attrition_Severity_Score] = 2 THEN 'Moderate Decay'
        WHEN [Attrition_Severity_Score] = 3 THEN 'Significant Decay'
        WHEN [Attrition_Severity_Score] = 4 THEN 'Critical Decay'
    END AS Attrition_Severity_Label

FROM #SoftAttritionDefinition
ORDER BY [Soft_Attrition_Flag] DESC, [Attrition_Severity_Score] DESC, [Party_ID];

-- ============================================================================
-- DISTRIBUTION ANALYSIS: Attrition Metrics
-- ============================================================================

SELECT 
    [Soft_Attrition_Flag],
    COUNT(*) AS Member_Count,
    ROUND(AVG([Spend_Volume_Decay_Pct]), 2) AS Avg_Spend_Decay_Pct,
    ROUND(AVG([Txn_Frequency_Decay_Pct]), 2) AS Avg_Frequency_Decay_Pct,
    ROUND(AVG([Cadence_Decay_Pct]), 2) AS Avg_Cadence_Decay_Pct,
    ROUND(AVG([MCC_Breadth_Contraction_Pct]), 2) AS Avg_Breadth_Decay_Pct,
    ROUND(AVG([Recency_Days]), 1) AS Avg_Recency_Days,
    ROUND(AVG([Attrition_Severity_Score]), 2) AS Avg_Severity_Score

FROM #SoftAttritionDefinition
GROUP BY [Soft_Attrition_Flag]
ORDER BY [Soft_Attrition_Flag];

-- ============================================================================
-- SEVERITY BREAKDOWN: Distribution by Severity Score
-- ============================================================================

SELECT 
    [Attrition_Severity_Label],
    COUNT(*) AS Member_Count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM #SoftAttritionDefinition), 2) AS Pct_of_Total,
    ROUND(AVG([Spend_Volume_Decay_Pct]), 2) AS Avg_Spend_Decay_Pct,
    ROUND(AVG([Txn_Frequency_Decay_Pct]), 2) AS Avg_Frequency_Decay_Pct,
    ROUND(AVG([Monetary_Recent_120d]), 2) AS Avg_Recent_Spend,
    ROUND(AVG([Recency_Days]), 1) AS Avg_Recency_Days

FROM #SoftAttritionDefinition
GROUP BY [Attrition_Severity_Label]
ORDER BY [Attrition_Severity_Score];

-- Clean up temp tables
DROP TABLE #MemberCohort;
DROP TABLE #SpendVolumeMetrics;
DROP TABLE #TransactionFrequencyMetrics;
DROP TABLE #CategoryBreadthMetrics;
DROP TABLE #RFMMetrics;
DROP TABLE #SoftAttritionDefinition;
