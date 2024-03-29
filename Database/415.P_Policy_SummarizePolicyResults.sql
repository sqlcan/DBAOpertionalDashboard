USE [SQLOpsDB]
GO
/****** Object:  StoredProcedure [Policy].[SummarizePolicyResults]    Script Date: 11/16/2022 5:03:26 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE OR ALTER PROC [Policy].[SummarizePolicyResults]
AS
BEGIN

	TRUNCATE TABLE [Policy].PolicyHistorySummary;

	WITH CTE AS
	( SELECT   LOWER(EvaluatedServer) AS EvaluatedServer
	 			, EvaluatedObject
				, policy_id
	 			, MAX(EvaluationDateTime) AS LastEval
		FROM [Policy].PolicyHistoryDetail PHD
		WHERE EvaluationDateTime >= DATEADD(DAY,-8,GETDATE())
		GROUP BY LOWER(EvaluatedServer), EvaluatedObject, policy_id
	),
	CTE2 AS
	(SELECT PHD.CategoryName,
			PHD.policy_id,
			CASE WHEN (CHARINDEX('.',CTE.EvaluatedServer) > 0) AND (CHARINDEX('\',CTE.EvaluatedServer) > 0) THEN
				SUBSTRING(CTE.EvaluatedServer,1,CHARINDEX('.',CTE.EvaluatedServer)-1) + SUBSTRING(CTE.EvaluatedServer,CHARINDEX('\',CTE.EvaluatedServer), LEN(CTE.EvaluatedServer))
			WHEN (CHARINDEX('.',CTE.EvaluatedServer) > 0) AND (CHARINDEX('\',CTE.EvaluatedServer) = 0) THEN
				SUBSTRING(CTE.EvaluatedServer,1,CHARINDEX('.',CTE.EvaluatedServer)-1)
			ELSE
				CTE.EvaluatedServer
			END AS EvaluatedServer,
			SUBSTRING(CTE.EvaluatedObject,
			LEN(CTE.EvaluatedObject) - CHARINDEX('\',REVERSE(CTE.EvaluatedObject)) + 2,
			LEN(CTE.EvaluatedObject)) AS ObjectName,
			PHD.EvaluationDateTime,
			PHD.PolicyResult
		FROM [Policy].PolicyHistoryDetail PHD
		JOIN CTE 
			ON PHD.EvaluatedServer = CTE.EvaluatedServer
		AND PHD.EvaluatedObject = CTE.EvaluatedObject
		AND PHD.EvaluationDateTime = CTE.LastEval
		AND PHD.policy_id = CTE.policy_id
		WHERE PolicyResult IN ('Fail','PASS'))
		INSERT INTO [Policy].PolicyHistorySummary
				   (CategoryName
				   ,PolicyName
				   ,policy_id
				   ,EvaluatedServer
				   ,ObjectName
				   ,EvaluationDateTime
				   ,PolicyResult)
		SELECT C.CategoryName, MP.name AS PolicyName, C.policy_id, C.EvaluatedServer, C.ObjectName, C.EvaluationDateTime, C.PolicyResult
		FROM CTE2 C
		JOIN msdb.dbo.syspolicy_policies mp
			ON C.policy_id = mp.policy_id;

	UPDATE Policy.PolicyHistorySummary
			SET ObjectName = REPLACE(ObjectName,'%5C','\')

	UPDATE Policy.PolicyHistorySummary
	set ObjectName = Replace(ObjectName,EvaluatedServer+'.','')


END
