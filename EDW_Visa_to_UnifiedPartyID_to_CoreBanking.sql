--<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
-- START CREATE #Visa_TransactionCodes
--Debit means money is charged against the card and Credit is money given back to the card.

IF OBJECT_ID('tempdb..#Visa_TransactionCodes') IS NOT NULL
	DROP TABLE #Visa_TransactionCodes

SELECT CAST('0105' AS varchar(4)) AS Output_Transaction_Code_Internal, CAST('Cash' AS varchar(100)) AS Transaction_Category, CAST('ATM Cash' AS varchar(100)) AS Transaction_Description
INTO #Visa_TransactionCodes

INSERT INTO #Visa_TransactionCodes(Output_Transaction_Code_Internal, Transaction_Category, Transaction_Description)
SELECT             '1003','Cash','ATM Cash'
 UNION ALL SELECT  '1028','Cash','ATM Cash Reversal'
 UNION ALL SELECT  '1002','Cash','Manual Cash Advance'
 UNION ALL SELECT  '0102','Cash','Manual Cash Advance'
 UNION ALL SELECT  '1027','Cash','Manual Cash Advance Reversal'
 UNION ALL SELECT  '1006','Purchase Reversal','Purchase Reversal'
 UNION ALL SELECT  '0106','Purchase Reversal','Purchase Reversal'
 UNION ALL SELECT  '1026','Purchase','Credit Reversal'
 UNION ALL SELECT  '1001','Purchase','Purchase'
 UNION ALL SELECT  '0101','Purchase','Purchase'
 UNION ALL SELECT  '1025','Purchase Reversal','Purchase Reversal'
 UNION ALL SELECT  '1098','Purchase','Quasi-Cash Purchase'
 UNION ALL SELECT  '1038','Purchase Reversal','Quash-Cash Purchase Reversal'
 UNION ALL SELECT  '0104','Purchase','Convenience Cheque'
 UNION ALL SELECT  '0405','Fees','Annual Fee'
 UNION ALL SELECT  '0401','Fees','Cash Advance Fee'
 UNION ALL SELECT  '0404','Interest','Cash Advance Interest'
 UNION ALL SELECT  '0408','Fees','Over limit Fee'
 UNION ALL SELECT  '0403','Interest','Purchase Interest'
 UNION ALL SELECT  '0421','Fees','NSF Payment Fee'
 UNION ALL SELECT  '0167','Fee Reversals','Annual Fee Reversal'
 UNION ALL SELECT  '0164','Fee Reversals','Cash Advance Fee Reversal'
 UNION ALL SELECT  '0163','Interest Reversals','Cash Advance Interest Reversal'
 UNION ALL SELECT  '0170','Fee Reversals','Over limit Fee Reversal'
 UNION ALL SELECT  '0162','Interest Reversals','Purchase Interest Reversal'
 UNION ALL SELECT  '7002','Fee Reversals','Generic Fee Reversal'

 UNION ALL SELECT  '0174','Charge Off','CREDIT SMALL BALANCE CHARGE-OFF'
 UNION ALL SELECT  '0144','Charge Off','DEBIT SMALL BALANCE CHARGE-OFF'

 UNION ALL SELECT  '0485','Fee Reversals','CREDIT TO FRONT END FEE'
 UNION ALL SELECT  '0492','Fee Reversals','CREDIT TO INSURANCE FEES'
 UNION ALL SELECT  '0486','Fee Reversals','CREDIT TO MEMBERSHIP FEE'
 UNION ALL SELECT  '0484','Fee Reversals','CREDIT TO OVERLIMIT FEE'
 UNION ALL SELECT  '0444','Fee Reversals','MEMBERSHIP FEE REBATE'

 UNION ALL SELECT  '0287','Fee Reversals','RETURN CHECK FEE CREDIT ADJUSTMENT'
 UNION ALL SELECT  '0361','Fee Reversals','STATEMENT REPRINT CREDIT ADJUSTMENT'

 UNION ALL SELECT  '0219','Fees','BAL XFER CHECK CASH ADV DEBIT'
 
 UNION ALL SELECT  '0137','Fees','DEBIT MEMBERSHIP FEE'
 UNION ALL SELECT  '0415','Fees','INSURANCE FEE -01-'
 UNION ALL SELECT  '0252','Fees','MEMBERSHIP FEE DEBIT ADJ'

 UNION ALL SELECT  '0355','Fees','STATEMENT REPRINT FEE'
 UNION ALL SELECT  '0354','Credit','BACKDATING CREDIT'
 UNION ALL SELECT  '0166','Credit','CREDIT INSURANCE'
 UNION ALL SELECT  '0160','Credit','CREDIT TO PURCHASE BALANCE'
 UNION ALL SELECT  '0292','Credit','CREDIT TO PURCHASE-QUASI AND UNIQUE TRAN'
 UNION ALL SELECT  '0130','Debit','DEBIT TO PURCHASE BALANCE'
 UNION ALL SELECT  '0379','Debit','QUASI AND UNIQUE- DEBIT TO PURCHASE'
 UNION ALL SELECT  '0440','Payment','AUTOMATIC PAYMENT'
 UNION ALL SELECT  '7182','Payment','CLAIM PAYMENT'
 UNION ALL SELECT  '0108','Payment','PAYMENT'

 UNION ALL SELECT  '0139','Reversal Fee','NSF PYMT REV W/FEE'
 UNION ALL SELECT  '0150','Reversal Fee','NSF PYMT REV W/O FEE'
 UNION ALL SELECT  '0374','Payment Reversal','PYMT REV W/O FEE';

--SELECT * FROM #Visa_TransactionCodes ORDER BY Transaction_Category, Transaction_Description

-- END CREATE #Visa_TransactionCodes
--<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>

/*						*************************								*/
	
--<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
-- START CREATE #Visa_ASC

IF OBJECT_ID('tempdb..#Visa_ASC') IS NOT NULL
	DROP TABLE #Visa_ASC

SELECT CAST('SECURE' AS varchar(6)) AS Acquisition_Strategy_Code, CAST('Secured' AS varchar(100)) AS Acquisition_Strategy_Code_Desc
INTO #Visa_ASC

INSERT INTO #Visa_ASC(Acquisition_Strategy_Code, Acquisition_Strategy_Code_Desc)
SELECT 'REFUGE','Refuge Assist.'
 UNION ALL SELECT  'ACCESS', 'Accessibility'
 UNION ALL SELECT  'NEWCOM', 'Newcomers'
 UNION ALL SELECT  'GUAREG', 'Guaranteed'
 UNION ALL SELECT  'CMSMTG', 'Mortgage Renewal 2019'
 UNION ALL SELECT  'GUACMB', 'Community Business Guar.'
 UNION ALL SELECT  'GUAMTG', 'Mortgage Guaranteed'
 UNION ALL SELECT  'HOPACC', 'Hope for Freedom Acc.'
 UNION ALL SELECT  'HOPSEC', 'Hope for Freedom Secured'
 UNION ALL SELECT  'TECMAH', 'Tech Mahindra'
 UNION ALL SELECT  'TWCACC', 'Together We Can Acc.'
 UNION ALL SELECT  'TWCSEC', 'Together We Can Secured'
 UNION ALL SELECT  'NFA20P', 'Infinite (Pre‐appr w/mtg)'
 UNION ALL SELECT  'NFA20V', 'Infinite (Invitation)'
 UNION ALL SELECT  'PRA20P', 'Infinite Privilege (Pre‐appr w/mtg)'
 UNION ALL SELECT  'PRA20V','Infinite Privilege (Invitation)'
 UNION ALL SELECT  'BZA20V', 'Infinite Business (Pre‐appr w/mtg)'

--SELECT * FROM #Visa_ASC

-- END CREATE #Visa_ASC
--<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>

/*						*************************								*/
	
--<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
-- START CREATE #Visa_EmployeeCodes

IF OBJECT_ID('tempdb..#Visa_EmployeeCodes') IS NOT NULL
	DROP TABLE #Visa_EmployeeCodes

SELECT CAST('E' AS varchar(2)) AS Employee_Code, CAST('Employee' AS varchar(100)) AS Employee_Code_Desc
INTO #Visa_EmployeeCodes

INSERT INTO #Visa_EmployeeCodes(Employee_Code, Employee_Code_Desc)
SELECT '1','Related Party'
 UNION ALL SELECT  '2', 'Employee & Related Party'
 UNION ALL SELECT  '3', 'Retired Employee'

-- SELECT * FROM #Visa_EmployeeCodes

-- END CREATE #Visa_EmployeeCodes
--<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>

/*						*************************								*/
	
--<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
-- START CREATE #Visa_RegionCodes

IF OBJECT_ID('tempdb..#Visa_RegionCodes') IS NOT NULL
	DROP TABLE #Visa_RegionCodes

SELECT CAST('SEC' AS varchar(3)) AS Region_Code, CAST('Secured' AS varchar(100)) AS Region_Code_Desc
INTO #Visa_RegionCodes

INSERT INTO #Visa_RegionCodes(Region_Code, Region_Code_Desc)
SELECT 'RAP','Refuge Assist.'
 UNION ALL SELECT  'ACC', 'Accessibility'
 UNION ALL SELECT  'NEW', 'Newcomers'

-- SELECT * FROM #Visa_RegionCodes

-- END CREATE #Visa_RegionCodes
--<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>

/*						*************************								*/
	
--<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
-- START CREATE #Visa_BranchCodes

IF OBJECT_ID('tempdb..#Visa_BranchCodes') IS NOT NULL
	DROP TABLE #Visa_BranchCodes

SELECT CAST('000CHC' AS varchar(6)) AS Branch_Code, CAST('Card Services' AS varchar(100)) AS Branch_Code_Desc
INTO #Visa_BranchCodes

INSERT INTO #Visa_BranchCodes(Branch_Code, Branch_Code_Desc)
SELECT '000MSC','MSC'
 UNION ALL SELECT  '000CBB', 'Community Business'
 UNION ALL SELECT  '000SWM', 'Sustainable Wealth Management'

-- SELECT * FROM #Visa_BranchCodes

-- END CREATE #Visa_BranchCodes
--<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>

/*						*************************								*/
	
--<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
-- START CREATE #Visa_TSYSProductCodes

IF OBJECT_ID('tempdb..#Visa_TSYSProductCodes') IS NOT NULL
	DROP TABLE #Visa_TSYSProductCodes

SELECT CAST('VS' AS varchar(2)) AS TSYSProductCode, CAST('Visa Classic' AS varchar(100)) AS TSYSProductCode_Desc
INTO #Visa_TSYSProductCodes

INSERT INTO #Visa_TSYSProductCodes(TSYSProductCode, TSYSProductCode_Desc)
SELECT 'VG','Visa Gold'
 UNION ALL SELECT  'VB', 'Visa Business'
 UNION ALL SELECT  'VI', 'Visa Infinite'

-- SELECT * FROM #Visa_TSYSProductCodes

-- END CREATE #Visa_TSYSProductCodes
--<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>

/*						*************************								*/
	
--<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
-- START CREATE #Visa_ClientProductCodes

IF OBJECT_ID('tempdb..#Visa_ClientProductCodes') IS NOT NULL
	DROP TABLE #Visa_ClientProductCodes

SELECT CAST('RRR' AS varchar(3)) AS Client_Product_Code, CAST('Reg Rate w/ Rew' AS varchar(100)) AS Client_Product_Code_Desc, CAST('Retail Products' AS varchar(100)) AS Product_Class, CAST('VCU' AS varchar(100)) AS Institution_Code
INTO #Visa_ClientProductCodes

INSERT INTO #Visa_ClientProductCodes(Client_Product_Code, Client_Product_Code_Desc, Product_Class, Institution_Code)
SELECT 'VIB','Infinite Visa - Reg Rate w/ Rew', 'Business BIN Products','VCU'
 UNION ALL SELECT  'VIR', 'Infinite - Reg Rate w/ Rew', 'Retail Products','VCU'
 UNION ALL SELECT  'LRN', 'Low Rate - No Rew', 'Retail Products','VCU'
 UNION ALL SELECT  'VPR', 'Infinite Privilege - Reg Rate w/ Rew', 'Retail Products','VCU'
 UNION ALL SELECT  'LRR', 'Low Rate w/ Rew', 'Retail Products','VCU'
 UNION ALL SELECT  'EXP', 'Expense - Reg Rate w/ Rew', 'Business Use (Retail BIN) Products','VCU'
 UNION ALL SELECT  'RRA', 'Accelerator - Reg Rate w/ Rew', 'Retail Products','VCU'
 UNION ALL SELECT  'CUC', 'Credit Union Central - Reg Rate - No Rew', 'NPO / Corporate / Strategic Partner Products','VCU'
 UNION ALL SELECT  'CEN', 'Central One - Reg Rate w/ Rew', 'NPO / Corporate / Strategic Partner Products','VCU'
 UNION ALL SELECT  'NPO', 'Non Profit - Reg Rate w/ Rew', 'NPO / Corporate / Strategic Partner Products','VCU'
 UNION ALL SELECT  'COR', 'Corporate - Reg Rate w/ Rew', 'NPO / Corporate / Strategic Partner Products','VCU'
 UNION ALL SELECT  'RCL', 'Ratcliff - Reg Rate w/ Rew', 'NPO / Corporate / Strategic Partner Products','VCU'

 UNION ALL SELECT  'RRW', 'Reg Rate w/ Rew', 'Discontinued','CBC'
 UNION ALL SELECT  'LNO', 'Low Rate - No Rew', 'Discontinued','CBC'
 UNION ALL SELECT  'LRW', 'Low Rate w/ Rew', 'Discontinued','CBC'
 UNION ALL SELECT  'RCO', 'Corporate - Reg Rate w/ Rew', 'Business BIN Products','CBC'
 UNION ALL SELECT  'RNC', 'Non Corporate - Reg Rate w/ Rew', 'Business BIN Products','CBC'
 UNION ALL SELECT  'RNP', 'Non Profit - Reg Rate w/ Rew', 'Business BIN Products','CBC'

-- SELECT * FROM #Visa_ClientProductCodes

-- END CREATE #Visa_ClientProductCodes
--<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>

/*						*************************								*/
	

--Visa Accounts on month-end dates linked to Primary Visa Account holder
DECLARE @As_Of_Date date
SET @As_Of_Date = '2026-01-30' --NOTE!!! We've had to use Jan 30th as the "month-end" date because the Visa data doesn't come in EVERY day. IT is very annoying.

SELECT TOP 100 fa.[Business_Date]
, da.[Account_Number], da.[Account_Type], da.[Client_Number]
, da.[Tsys_Product_Code], tpc.TSYSProductCode_Desc
, da.[Client_Product_Code], cpc.Client_Product_Code_Desc, cpc.Product_Class, cpc.Institution_Code
, da.[Branch]
, da.[Original_Credit_Limit], da.[Credit_Limit], da.[Cycle_Number]
, da.[Acquisition_Strategy_Code], ascd.Acquisition_Strategy_Code_Desc
, pv.[Dim_Party_Key], pv.[Party_ID], pv.[Account_Number] AS Party_Account_Number, pv.[Party_Type_Code], pv.[Party_Category_Code]

--Unified Party ID:
, br.[Unified_Party_ID], br.[Consent_To_Share], br.[Party_Id] AS Bridge_Party_Id

--Core Banking: (if the Visa Customer is linked to a Core Banking Member)
, br2.[Source_System_Name], br2.[Party_Id] AS Core_Banking_Party_Id

FROM [dbo].[Fact_FinancialAccount_Visa] fa
	LEFT JOIN [dbo].[Dim_FinancialAccount_Visa] da
		ON da.[Dim_FinancialAccount_Key] = fa.[Dim_FinancialAccount_Key]
			
			--link Visa Account to Visa customers:
			LEFT JOIN [dbo].[Dim_Party_Visa] pv
				ON pv.[Account_Number] = da.[Account_Number]
				AND pv.[Party_Type_Code] = 'P' --P= Personal; B= Business
				AND pv.[Party_Category_Code] = '0' --0 = Primary; 2 = Authorized user; 3 = Business
				AND pv.[Party_Deceased_Flag] = 'N'

				--the next 2 filters should ensure only a single record is linked and it is the record that was "current" on the @As_Of_Date.
				AND pv.[Effective_Date] <= @As_Of_Date
				AND ( pv.[End_Date] = '9999/12/31' OR pv.[End_Date] < @As_Of_Date )

					--link to the Unified Party ID bridge table:
					LEFT JOIN [dbo].[Br_Party_Unified] br
						ON br.[Dim_Party_Key] = pv.[Dim_Party_Key]
						AND br.[Source_System_Name] = 'Visa 2'
						AND br.[Effective_Date] <= @As_Of_Date
						AND ( br.[End_Date] = '9999-12-31' OR br.[End_Date] > @As_Of_Date )

							--now link again to the Unified Party ID bridge table to find the Core Banking Party_Id for this same br.[Unified_Party_ID]:
							LEFT JOIN [dbo].[Br_Party_Unified] br2
								ON br2.[Unified_Party_ID] = br.[Unified_Party_ID]
								AND br2.[Source_System_Name] = 'Temenos T24'
								AND br2.[Effective_Date] <= @As_Of_Date
								AND ( br2.[End_Date] = '9999-12-31' OR br2.[End_Date] > @As_Of_Date )
			
			--Here's some look-up table links:
			LEFT JOIN #Visa_ASC ascd
				ON ascd.Acquisition_Strategy_Code = da.[Acquisition_Strategy_Code]
			LEFT JOIN #Visa_TSYSProductCodes tpc
				ON tpc.TSYSProductCode = da.[Tsys_Product_Code]
			LEFT JOIN #Visa_ClientProductCodes cpc
				ON cpc.Client_Product_Code = da.[Client_Product_Code]

WHERE fa.[Business_Date] = @As_Of_Date