/*
================================================================================
SOFT ATTRITION DEFINITION - Churn Prediction Model (OPTIMIZED)
================================================================================
Objective: Identify members showing signs of engagement decline (soft attrition)
while maintaining active accounts.

DEFINITION:
Soft Attrition = A measurable decrease in member engagement with Visa over a 
defined period (120 days), while the account remains open. The member has 
established transaction history and is in the longer-tenured cohort (12-23 months).

COMPOSITE ATTRITION RULES:
1. Spend-Volume Decay: >= 20% decrease in transaction spending
2. Transaction-Frequency Decay: >= 20% decrease in transaction count/cadence
3. Category-Breadth Contraction: >= 25% decrease in unique MCC categories
4. Composite Engagement Score: RFM decline combined with category breadth drop

MEMBER COHORT CRITERIA:
- Account tenure: 12-23 months
- Established transaction history
- Account status: Active (open)
- Account holder type: Primary personal

THRESHOLD TUNING PARAMETERS:
- Spend decay threshold: 20%
- Frequency decay threshold: 20%
- MCC breadth decay threshold: 25%
- Poor recency threshold: 60 days
- Breadth collapse threshold: 50% of baseline
- Minimum flagged components for soft attrition: 2 of 4
- Minimum baseline activity: > 0 (to exclude never-engaged members)

================================================================================
*/

DECLARE @AsOfDate DATE = '2026-06-09';
DECLARE @BaselineWindowEnd DATE = DATEADD(DAY, -120, @AsOfDate);
DECLARE @BaselineWindowStart DATE = DATEADD(DAY, -240, @AsOfDate);
DECLARE @HistoricalCutoff DATE = DATEADD(DAY, -270, @AsOfDate);

-- ============================================================================
-- STEP 1: DEFINE MEMBER COHORT (12-23 months tenure)
-- ============================================================================

IF OBJECT_ID('tempdb..#MemberCohort') IS NOT NULL
    DROP TABLE #MemberCohort;

SELECT 
    pv.[Dim_Party_Key],
    pv.[Party_ID],
    da.[Account_Number],
    da.[Dim_FinancialAccount_Key],
    da.[Tsys_Product_Code],
    da.[Client_Product_Code],
    da.[Credit_Limit],
    da.[Account_Open_Date],
    DATEDIFF(MONTH, da.[Account_Open_Date], @AsOfDate) AS Months_Since_Account_Open
INTO #MemberCohort
FROM [dbo].[Dim_FinancialAccount_Visa] da
    LEFT JOIN [dbo].[Dim_Party_Visa] pv
        ON pv.[Account_Number] = da.[Account_Number]
        AND pv.[Party_Type_Code] = 'P'
        AND pv.[Party_Category_Code] = '0'
        AND pv.[Party_Deceased_Flag] = 'N'
        AND pv.[Effective_Date] <= @AsOfDate
        AND (pv.[End_Date] = '9999-12-31' OR pv.[End_Date] > @AsOfDate)
WHERE da.[Account_Status_Code] IN ('A', 'O')
    AND DATEDIFF(MONTH, da.[Account_Open_Date], @AsOfDate) BETWEEN 12 AND 23;

-- ============================================================================
-- STEP 2: CONSOLIDATED METRIC CALCULATION (Single Fact Table Scan)
-- ============================================================================
-- Combines all metrics from a single pass through Fact_FinancialTransaction_Visa
-- Filters: Purchase transactions only, primary account holders, debit transactions

IF OBJECT_ID('tempdb..#AllMetrics') IS NOT NULL
    DROP TABLE #AllMetrics;

SELECT 
    mc.[Party_ID],
    mc.[Account_Number],
    mc.[Dim_Party_Key],
    mc.[Months_Since_Account_Open],
    
    -- ===== SPEND-VOLUME METRICS =====
    COALESCE(SUM(CASE 
        WHEN ft.[Transaction_Date] >= @BaselineWindowEnd AND ft.[Transaction_Date] <= @AsOfDate
        THEN ABS(ft.[Transaction_Amount])
        ELSE 0
    END), 0) AS Spend_Recent_120d,
    
    COALESCE(SUM(CASE 
        WHEN ft.[Transaction_Date] >= @BaselineWindowStart AND ft.[Transaction_Date] < @BaselineWindowEnd
        THEN ABS(ft.[Transaction_Amount])
        ELSE 0
    END), 0) AS Spend_Baseline_120d,
    
    -- ===== TRANSACTION-FREQUENCY METRICS =====
    COUNT(DISTINCT CASE 
        WHEN ft.[Transaction_Date] >= @BaselineWindowEnd AND ft.[Transaction_Date] <= @AsOfDate
        THEN ft.[Fact_FinancialTransaction_Key]
    END) AS Txn_Count_Recent_120d,
    
    COUNT(DISTINCT CASE 
        WHEN ft.[Transaction_Date] >= @BaselineWindowStart AND ft.[Transaction_Date] < @BaselineWindowEnd
        THEN ft.[Fact_FinancialTransaction_Key]
    END) AS Txn_Count_Baseline_120d,
    
    -- ===== TRANSACTION CADENCE (Days between transactions) =====
    CASE 
        WHEN COUNT(DISTINCT CASE 
            WHEN ft.[Transaction_Date] >= @BaselineWindowEnd AND ft.[Transaction_Date] <= @AsOfDate
            THEN CAST(ft.[Transaction_Date] AS DATE)
        END) > 1 
        THEN CAST(120.0 / NULLIF(COUNT(DISTINCT CASE 
            WHEN ft.[Transaction_Date] >= @BaselineWindowEnd AND ft.[Transaction_Date] <= @AsOfDate
            THEN CAST(ft.[Transaction_Date] AS DATE)
        END), 0) AS DECIMAL(10, 2))
        ELSE NULL
    END AS Recent_Avg_Days_Between_Txns,
    
    CASE 
        WHEN COUNT(DISTINCT CASE 
            WHEN ft.[Transaction_Date] >= @BaselineWindowStart AND ft.[Transaction_Date] < @BaselineWindowEnd
            THEN CAST(ft.[Transaction_Date] AS DATE)
        END) > 1 
        THEN CAST(120.0 / NULLIF(COUNT(DISTINCT CASE 
            WHEN ft.[Transaction_Date] >= @BaselineWindowStart AND ft.[Transaction_Date] < @BaselineWindowEnd
            THEN CAST(ft.[Transaction_Date] AS DATE)
        END), 0) AS DECIMAL(10, 2))
        ELSE NULL
    END AS Baseline_Avg_Days_Between_Txns,
    
    -- ===== CATEGORY-BREADTH METRICS (MCC) =====
    COUNT(DISTINCT CASE 
        WHEN ft.[Transaction_Date] >= @BaselineWindowEnd AND ft.[Transaction_Date] <= @AsOfDate
        THEN ft.[Merchant_SIC_Class_Code]
    END) AS MCC_Count_Recent_120d,
    
    COUNT(DISTINCT CASE 
        WHEN ft.[Transaction_Date] >= @BaselineWindowStart AND ft.[Transaction_Date] < @BaselineWindowEnd
        THEN ft.[Merchant_SIC_Class_Code]
    END) AS MCC_Count_Baseline_120d,
    
    -- ===== RFM METRICS =====
    DATEDIFF(DAY, MAX(CASE 
        WHEN ft.[Transaction_Date] <= @AsOfDate
        THEN ft.[Transaction_Date] 
    END), @AsOfDate) AS Recency_Days,
    
    COUNT(DISTINCT CASE 
        WHEN ft.[Transaction_Date] >= @BaselineWindowEnd AND ft.[Transaction_Date] <= @AsOfDate
        THEN ft.[Fact_FinancialTransaction_Key]
    END) AS Frequency_Recent_120d,
    
    COALESCE(SUM(CASE 
        WHEN ft.[Transaction_Date] >= @BaselineWindowEnd AND ft.[Transaction_Date] <= @AsOfDate
        THEN ABS(ft.[Transaction_Amount])
        ELSE 0
    END), 0) AS Monetary_Recent_120d

INTO #AllMetrics
FROM #MemberCohort mc
    LEFT JOIN [dbo].[Fact_FinancialTransaction_Visa] ft
        ON ft.[Account_Number] = mc.[Account_Number]
        AND ft.[Transaction_Date] >= @HistoricalCutoff
        AND ft.[Debit_Credit_Indicator] = 'D'
    -- Join to card dimension to validate primary account holder
    LEFT JOIN [dbo].[Dim_Card_Visa] c
        ON c.[Dim_Card_Key] = ft.[Dim_Card_Key]
    LEFT JOIN [dbo].[Dim_Party_Visa] party_check
        ON party_check.[Dim_Party_Key] = c.[Party_ID]
        AND party_check.[Party_Category_Code] = '0'
        AND party_check.[Effective_Date] <= @AsOfDate
        AND (party_check.[End_Date] = '9999-12-31' OR party_check.[End_Date] > @AsOfDate)
    -- Filter to purchase transactions only (specific TSYS codes)
    LEFT JOIN (
        SELECT '1001' AS Code UNION ALL SELECT '0101' UNION ALL SELECT '1098' UNION ALL 
        SELECT '0104' UNION ALL SELECT '1003' UNION ALL SELECT '1002' UNION ALL 
        SELECT '0102' UNION ALL SELECT '1006' UNION ALL SELECT '0106' UNION ALL 
        SELECT '1026' UNION ALL SELECT '1025' UNION ALL SELECT '1038'
    ) purchase_codes ON CAST(ft.[Tsys_Product_Code] AS VARCHAR(4)) = purchase_codes.[Code]
WHERE purchase_codes.[Code] IS NOT NULL  -- Ensure we only have purchase transactions
GROUP BY mc.[Party_ID], mc.[Account_Number], mc.[Dim_Party_Key], mc.[Months_Since_Account_Open];

-- ============================================================================
-- STEP 3: CALCULATE DECAY PERCENTAGES AND ATTRITION FLAGS
-- ============================================================================

IF OBJECT_ID('tempdb..#SoftAttritionDefinition') IS NOT NULL
    DROP TABLE #SoftAttritionDefinition;

SELECT 
    [Party_ID],
    [Account_Number],
    [Dim_Party_Key],
    [Months_Since_Account_Open],
    @AsOfDate AS Observation_Date,
    
    -- ===== SPEND-VOLUME METRICS =====
    [Spend_Recent_120d],
    [Spend_Baseline_120d],
    CASE 
        WHEN [Spend_Baseline_120d] > 0
        THEN ROUND(([Spend_Recent_120d] - [Spend_Baseline_120d]) * 100.0 / [Spend_Baseline_120d], 2)
        ELSE NULL
    END AS Spend_Volume_Decay_Pct,
    
    -- ===== TRANSACTION-FREQUENCY METRICS =====
    [Txn_Count_Recent_120d],
    [Txn_Count_Baseline_120d],
    CASE 
        WHEN [Txn_Count_Baseline_120d] > 0
        THEN ROUND(([Txn_Count_Recent_120d] - [Txn_Count_Baseline_120d]) * 100.0 / [Txn_Count_Baseline_120d], 2)
        ELSE NULL
    END AS Txn_Frequency_Decay_Pct,
    
    [Recent_Avg_Days_Between_Txns],
    [Baseline_Avg_Days_Between_Txns],
    CASE 
        WHEN [Baseline_Avg_Days_Between_Txns] > 0
        THEN ROUND(([Recent_Avg_Days_Between_Txns] - [Baseline_Avg_Days_Between_Txns]) * 100.0 / [Baseline_Avg_Days_Between_Txns], 2)
        ELSE NULL
    END AS Cadence_Decay_Pct,
    
    -- ===== CATEGORY-BREADTH METRICS =====
    [MCC_Count_Recent_120d],
    [MCC_Count_Baseline_120d],
    CASE 
        WHEN [MCC_Count_Baseline_120d] > 0
        THEN ROUND(([MCC_Count_Recent_120d] - [MCC_Count_Baseline_120d]) * 100.0 / [MCC_Count_Baseline_120d], 2)
        ELSE NULL
    END AS MCC_Breadth_Contraction_Pct,
    
    -- ===== RFM METRICS =====
    [Recency_Days],
    [Frequency_Recent_120d],
    [Monetary_Recent_120d],
    
    -- ===== INDIVIDUAL ATTRITION FLAGS =====
    -- Flag 1: Spend-volume decay >= 20%
    CASE 
        WHEN [Spend_Baseline_120d] > 0 
        AND (([Spend_Recent_120d] - [Spend_Baseline_120d]) * 100.0 / [Spend_Baseline_120d]) <= -20 
        THEN 1 
        ELSE 0 
    END AS Flag_Spend_Volume_Decay,
    
    -- Flag 2: Transaction frequency decay >= 20%
    CASE 
        WHEN [Txn_Count_Baseline_120d] > 0 
        AND (([Txn_Count_Recent_120d] - [Txn_Count_Baseline_120d]) * 100.0 / [Txn_Count_Baseline_120d]) <= -20 
        THEN 1 
        ELSE 0 
    END AS Flag_Txn_Frequency_Decay,
    
    -- Flag 3: MCC breadth contraction >= 25%
    CASE 
        WHEN [MCC_Count_Baseline_120d] > 0 
        AND (([MCC_Count_Recent_120d] - [MCC_Count_Baseline_120d]) * 100.0 / [MCC_Count_Baseline_120d]) <= -25 
        THEN 1 
        ELSE 0 
    END AS Flag_MCC_Breadth_Contraction,
    
    -- Flag 4: Poor recency (> 60 days) - ONLY if member had baseline activity
    CASE 
        WHEN [Txn_Count_Baseline_120d] > 0 
        AND [Recency_Days] > 60 
        THEN 1 
        ELSE 0 
    END AS Flag_Poor_Recency,
    
    -- Flag 5: Engagement collapse (breadth < 50% of baseline) - ONLY if baseline activity exists
    CASE 
        WHEN [MCC_Count_Baseline_120d] > 0 
        AND [MCC_Count_Recent_120d] < ([MCC_Count_Baseline_120d] * 0.5)
        THEN 1 
        ELSE 0 
    END AS Flag_Breadth_Collapse,
    
    -- ===== OVERALL SOFT ATTRITION CLASSIFICATION =====
    -- Requires: At least 2 of 4 decay indicators AND baseline activity > 0
    CASE 
        WHEN [Txn_Count_Baseline_120d] > 0  -- Member must have had baseline engagement
        AND (
            CASE WHEN [Spend_Baseline_120d] > 0 
                AND (([Spend_Recent_120d] - [Spend_Baseline_120d]) * 100.0 / [Spend_Baseline_120d]) <= -20 
                THEN 1 ELSE 0 
            END
            + CASE WHEN [Txn_Count_Baseline_120d] > 0 
                AND (([Txn_Count_Recent_120d] - [Txn_Count_Baseline_120d]) * 100.0 / [Txn_Count_Baseline_120d]) <= -20 
                THEN 1 ELSE 0 
            END
            + CASE WHEN [MCC_Count_Baseline_120d] > 0 
                AND (([MCC_Count_Recent_120d] - [MCC_Count_Baseline_120d]) * 100.0 / [MCC_Count_Baseline_120d]) <= -25 
                THEN 1 ELSE 0 
            END
            + CASE WHEN [Recency_Days] > 60 THEN 1 ELSE 0 END
        ) >= 2 
        THEN 1
        ELSE 0
    END AS Soft_Attrition_Flag,
    
    -- ===== ATTRITION SEVERITY SCORE (0-4 scale) =====
    CASE 
        WHEN [Txn_Count_Baseline_120d] = 0 THEN 0  -- Never engaged = not applicable
        ELSE (
            CASE WHEN [Spend_Baseline_120d] > 0 
                AND (([Spend_Recent_120d] - [Spend_Baseline_120d]) * 100.0 / [Spend_Baseline_120d]) <= -20 
                THEN 1 ELSE 0 
            END
            + CASE WHEN [Txn_Count_Baseline_120d] > 0 
                AND (([Txn_Count_Recent_120d] - [Txn_Count_Baseline_120d]) * 100.0 / [Txn_Count_Baseline_120d]) <= -20 
                THEN 1 ELSE 0 
            END
            + CASE WHEN [MCC_Count_Baseline_120d] > 0 
                AND (([MCC_Count_Recent_120d] - [MCC_Count_Baseline_120d]) * 100.0 / [MCC_Count_Baseline_120d]) <= -25 
                THEN 1 ELSE 0 
            END
            + CASE WHEN [Recency_Days] > 60 THEN 1 ELSE 0 END
        )
    END AS Attrition_Severity_Score,
    
    -- ===== ATTRITION SEVERITY LABEL (stored for reporting) =====
    CASE 
        WHEN [Txn_Count_Baseline_120d] = 0 THEN 'Never Engaged'
        WHEN (
            CASE WHEN [Spend_Baseline_120d] > 0 
                AND (([Spend_Recent_120d] - [Spend_Baseline_120d]) * 100.0 / [Spend_Baseline_120d]) <= -20 
                THEN 1 ELSE 0 
            END
            + CASE WHEN [Txn_Count_Baseline_120d] > 0 
                AND (([Txn_Count_Recent_120d] - [Txn_Count_Baseline_120d]) * 100.0 / [Txn_Count_Baseline_120d]) <= -20 
                THEN 1 ELSE 0 
            END
            + CASE WHEN [MCC_Count_Baseline_120d] > 0 
                AND (([MCC_Count_Recent_120d] - [MCC_Count_Baseline_120d]) * 100.0 / [MCC_Count_Baseline_120d]) <= -25 
                THEN 1 ELSE 0 
            END
            + CASE WHEN [Recency_Days] > 60 THEN 1 ELSE 0 END
        ) = 0 THEN 'Stable'
        WHEN (
            CASE WHEN [Spend_Baseline_120d] > 0 
                AND (([Spend_Recent_120d] - [Spend_Baseline_120d]) * 100.0 / [Spend_Baseline_120d]) <= -20 
                THEN 1 ELSE 0 
            END
            + CASE WHEN [Txn_Count_Baseline_120d] > 0 
                AND (([Txn_Count_Recent_120d] - [Txn_Count_Baseline_120d]) * 100.0 / [Txn_Count_Baseline_120d]) <= -20 
                THEN 1 ELSE 0 
            END
            + CASE WHEN [MCC_Count_Baseline_120d] > 0 
                AND (([MCC_Count_Recent_120d] - [MCC_Count_Baseline_120d]) * 100.0 / [MCC_Count_Baseline_120d]) <= -25 
                THEN 1 ELSE 0 
            END
            + CASE WHEN [Recency_Days] > 60 THEN 1 ELSE 0 END
        ) = 1 THEN 'Minor Decay'
        WHEN (
            CASE WHEN [Spend_Baseline_120d] > 0 
                AND (([Spend_Recent_120d] - [Spend_Baseline_120d]) * 100.0 / [Spend_Baseline_120d]) <= -20 
                THEN 1 ELSE 0 
            END
            + CASE WHEN [Txn_Count_Baseline_120d] > 0 
                AND (([Txn_Count_Recent_120d] - [Txn_Count_Baseline_120d]) * 100.0 / [Txn_Count_Baseline_120d]) <= -20 
                THEN 1 ELSE 0 
            END
            + CASE WHEN [MCC_Count_Baseline_120d] > 0 
                AND (([MCC_Count_Recent_120d] - [MCC_Count_Baseline_120d]) * 100.0 / [MCC_Count_Baseline_120d]) <= -25 
                THEN 1 ELSE 0 
            END
            + CASE WHEN [Recency_Days] > 60 THEN 1 ELSE 0 END
        ) = 2 THEN 'Moderate Decay'
        WHEN (
            CASE WHEN [Spend_Baseline_120d] > 0 
                AND (([Spend_Recent_120d] - [Spend_Baseline_120d]) * 100.0 / [Spend_Baseline_120d]) <= -20 
                THEN 1 ELSE 0 
            END
            + CASE WHEN [Txn_Count_Baseline_120d] > 0 
                AND (([Txn_Count_Recent_120d] - [Txn_Count_Baseline_120d]) * 100.0 / [Txn_Count_Baseline_120d]) <= -20 
                THEN 1 ELSE 0 
            END
            + CASE WHEN [MCC_Count_Baseline_120d] > 0 
                AND (([MCC_Count_Recent_120d] - [MCC_Count_Baseline_120d]) * 100.0 / [MCC_Count_Baseline_120d]) <= -25 
                THEN 1 ELSE 0 
            END
            + CASE WHEN [Recency_Days] > 60 THEN 1 ELSE 0 END
        ) = 3 THEN 'Significant Decay'
        ELSE 'Critical Decay'
    END AS Attrition_Severity_Label

INTO #SoftAttritionDefinition
FROM #AllMetrics;

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
    
    -- RFM Metrics
    [Recency_Days],
    [Frequency_Recent_120d],
    [Monetary_Recent_120d],
    
    -- Flags
    [Flag_Spend_Volume_Decay],
    [Flag_Txn_Frequency_Decay],
    [Flag_MCC_Breadth_Contraction],
    [Flag_Poor_Recency],
    [Flag_Breadth_Collapse],
    
    -- Attrition Classification
    [Soft_Attrition_Flag],
    [Attrition_Severity_Score],
    [Attrition_Severity_Label]

FROM #SoftAttritionDefinition
ORDER BY [Soft_Attrition_Flag] DESC, [Attrition_Severity_Score] DESC, [Party_ID];

-- ============================================================================
-- DISTRIBUTION ANALYSIS: Attrition Metrics by Soft Attrition Flag
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
-- SEVERITY BREAKDOWN: Distribution by Severity Label
-- ============================================================================

SELECT 
    [Attrition_Severity_Label],
    COUNT(*) AS Member_Count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM #SoftAttritionDefinition), 2) AS Pct_of_Total,
    ROUND(AVG([Spend_Volume_Decay_Pct]), 2) AS Avg_Spend_Decay_Pct,
    ROUND(AVG([Txn_Frequency_Decay_Pct]), 2) AS Avg_Frequency_Decay_Pct,
    ROUND(AVG([Monetary_Recent_120d]), 2) AS Avg_Recent_Spend,
    ROUND(AVG([Recency_Days]), 1) AS Avg_Recency_Days,
    MIN([Attrition_Severity_Score]) AS Min_Severity_Score,
    MAX([Attrition_Severity_Score]) AS Max_Severity_Score

FROM #SoftAttritionDefinition
GROUP BY [Attrition_Severity_Label]
ORDER BY [Attrition_Severity_Score];

-- ============================================================================
-- ENGAGEMENT BASELINE: Members with insufficient baseline activity (never engaged)
-- ============================================================================

SELECT 
    COUNT(*) AS Never_Engaged_Member_Count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM #SoftAttritionDefinition), 2) AS Pct_of_Target_Cohort

FROM #SoftAttritionDefinition
WHERE [Attrition_Severity_Label] = 'Never Engaged';

-- Clean up temp tables
DROP TABLE #MemberCohort;
DROP TABLE #AllMetrics;
DROP TABLE #SoftAttritionDefinition;
