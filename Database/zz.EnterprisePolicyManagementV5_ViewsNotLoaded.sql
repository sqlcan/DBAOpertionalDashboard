
--Drop the view if it exists.  
IF EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[Policy].[v_PolicyHistory]'))
DROP VIEW [Policy].[v_PolicyHistory]
GO
CREATE VIEW [Policy].[v_PolicyHistory]
AS
--The Policy.v_PolicyHistory view will return all results
--and identify the Policy evaluation result AS PASS, FAIL, or 
--ERROR. The ERROR result indicates that the Policy was not able
--to evaluate against an object.
SELECT PH.PolicyHistoryID
	, PH.EvaluatedServer
	, PH.EvaluationDateTime
	, PH.EvaluatedPolicy
	, PH.PolicyResult
	, PH.ExceptionMessage
	, PH.ResultDetail
	, PH.EvaluatedObject
	, PH.Policy_id
	, PH.CategoryName
	, PH.MonthYear
FROM Policy.PolicyHistoryDetail PH
INNER JOIN msdb.dbo.sysPolicy_policies AS p ON p.name = PH.EvaluatedPolicy
--INNER JOIN msdb.dbo.sysPolicy_Policy_categories AS c ON p.Policy_category_id = c.Policy_category_id
AND PH.EvaluatedPolicy NOT IN (SELECT spp.name 
		FROM msdb.dbo.sysPolicy_policies spp 
		INNER JOIN msdb.dbo.sysPolicy_Policy_categories spc ON spp.Policy_category_id = spc.Policy_category_id
		WHERE spc.name = 'Disabled')
GO


--Drop the view if it exists.  
IF EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[Policy].[v_PolicyHistory_Rank]'))
DROP VIEW Policy.v_PolicyHistory_Rank
GO
CREATE VIEW Policy.v_PolicyHistory_Rank 
AS
SELECT PolicyHistoryID
	, EvaluatedServer
	, EvaluationDateTime
	, EvaluatedPolicy
	, EvaluatedObject
	, PolicyResult
	, ResultDetail
	, ExceptionMessage
	, Policy_id
	, CategoryName
	, MonthYear
	, DENSE_RANK() OVER (
		PARTITION BY EvaluatedPolicy, EvaluatedServer, EvaluatedObject
		ORDER BY EvaluationDateTime DESC) AS EvaluationOrderDesc
FROM Policy.v_PolicyHistory VPH
GO

--Drop the view if it exists.  
IF EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[Policy].[v_PolicyHistory_LastEvaluation]'))
DROP VIEW Policy.v_PolicyHistory_LastEvaluation
GO
CREATE VIEW Policy.v_PolicyHistory_LastEvaluation
AS
--The Policy.v_PolicyHistory_LastEvaluation view will the last result for any given Policy evaluated against an object. 
--This view requires the v_PolicyHistory view exist.
SELECT PolicyHistoryID
	, EvaluatedServer
	, EvaluationDateTime
	, EvaluatedPolicy
	, EvaluatedObject
	, PolicyResult
	, ResultDetail
	, ExceptionMessage
	, Policy_id
	, CategoryName
	, MonthYear
	, EvaluationOrderDesc
FROM Policy.v_PolicyHistory_Rank VPH
WHERE EvaluationOrderDesc = 1
AND NOT EXISTS(
	SELECT *
	FROM Policy.PolicyHistoryDetail PH
	WHERE PH.EvaluatedPolicy = VPH.EvaluatedPolicy
		AND PH.EvaluatedServer = VPH.EvaluatedServer
		AND PH.EvaluationDateTime  > VPH.EvaluationDateTime)
GO

--Create a view to return all errors.  
--Errors will be returned from the table EvaluationErrorHistory and the errors in the PolicyHistory table.
--Drop the view if it exists.  
IF EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[Policy].[v_EvaluationErrorHistory]'))
DROP VIEW Policy.v_EvaluationErrorHistory
GO
CREATE VIEW Policy.v_EvaluationErrorHistory
AS
SELECT EEH.ErrorHistoryID
	, EEH.EvaluatedServer
	, EEH.EvaluationDateTime
	, EEH.EvaluatedPolicy
	, CASE WHEN CHARINDEX('\', EEH.EvaluatedServer) > 0 
		THEN RIGHT(EEH.EvaluatedServer, CHARINDEX('\', REVERSE(EEH.EvaluatedServer)) - 1)	
		ELSE EEH.EvaluatedServer
		END
	AS EvaluatedObject
	, EEH.EvaluationResults
	, p.Policy_id
	, c.name AS CategoryName
	, DATENAME(month, EvaluationDateTime) + ' ' + datename(year, EvaluationDateTime)  AS MonthYear
	, 'ERROR' AS PolicyResult	
FROM Policy.EvaluationErrorHistory AS EEH
INNER JOIN msdb.dbo.sysPolicy_policies AS p ON p.name = EEH.EvaluatedPolicy
INNER JOIN msdb.dbo.sysPolicy_Policy_categories AS c ON p.Policy_category_id = c.Policy_category_id
UNION ALL
SELECT PolicyHistoryID
	, EvaluatedServer
	, EvaluationDateTime
	, EvaluatedPolicy
	, CASE WHEN CHARINDEX('\', REVERSE(EvaluatedObject)) >0 
		THEN RIGHT(EvaluatedObject,CHARINDEX('\', REVERSE(EvaluatedObject)) - 1) 
		ELSE EvaluatedObject 
		END 
	AS EvaluatedObject
	, ExceptionMessage
	, Policy_id
	, CategoryName
	, MonthYear
	, PolicyResult
FROM Policy.v_PolicyHistory_LastEvaluation
WHERE PolicyResult = 'ERROR'
GO
	
--Create a view to return the last error for each Policy against
--an instance.
--Drop the view if it exists.  
IF EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[Policy].[v_EvaluationErrorHistory_LastEvaluation]'))	
DROP VIEW Policy.v_EvaluationErrorHistory_LastEvaluation
GO
CREATE VIEW Policy.v_EvaluationErrorHistory_LastEvaluation
AS
SELECT ErrorHistoryID
	, EvaluatedServer
	, EvaluationDateTime
	, EvaluatedPolicy
	, Policy_ID
	, EvaluatedObject
	, EvaluationResults
	, CategoryName
	, MonthYear
	, PolicyResult
	, DENSE_RANK() OVER (
		PARTITION BY EvaluatedServer, EvaluatedPolicy
		ORDER BY EvaluationDateTime DESC)AS EvaluationOrderDesc
FROM Policy.v_EvaluationErrorHistory EEH
WHERE NOT EXISTS (
	SELECT * 
	FROM Policy.PolicyHistoryDetail PH
	WHERE PH.EvaluatedPolicy = EEH.EvaluatedPolicy
		AND PH.EvaluatedServer = EEH.EvaluatedServer
		AND PH.EvaluationDateTime > EEH.EvaluationDateTime)	
GO
