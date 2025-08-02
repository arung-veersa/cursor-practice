CREATE OR REPLACE PROCEDURE CONFLICTREPORT_SANDBOX.PUBLIC.TEST_LOAD_STATE_PROVIDER_DATA_02()
RETURNS VARCHAR
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS '
	
	var SQL3 = `TRUNCATE TABLE CONFLICTREPORT_SANDBOX.PUBLIC.TEST_STATE_PROVIDER_02`;
	var SQL4 = `INSERT INTO CONFLICTREPORT_SANDBOX.PUBLIC.TEST_STATE_PROVIDER_02 (PAYERSTATE, PAYERID, PROVIDERID, CRDATEUNIQUE, STATUSFLAG, COSTTYPE, VISITTYPE, COUNTY, SERVICECODE, TO_TO, TO_SP, TO_OP, TO_FP, TD_TO, TD_SP, TD_OP, TD_FP, IN_TO, IN_SP, IN_OP, IN_FP)
	SELECT
		CVM."PayerState" AS PAYERSTATE,
		CVM."PayerID" AS PAYERID,
		CVM."ProviderID" AS PROVIDERID,
		TO_CHAR(CVM."CRDATEUNIQUE", ''YYYY-MM-DD'') AS CRDATEUNIQUE,
		CVM."StatusFlag" AS STATUSFLAG,
		CASE WHEN CVM."Billed" != ''yes'' THEN ''Avoidance'' ELSE ''Recovery'' END AS COSTTYPE,
		CASE 
			WHEN CVM."VisitStartTime" IS NULL THEN ''Scheduled'' 
			WHEN CVM."Billed" != ''yes'' THEN ''Confirmed'' 
			ELSE ''Billed'' 
		END AS VISITTYPE,
		COALESCE(CVM."P_PCounty", CVM."PA_PCounty") AS COUNTY,
		CVM."ServiceCode" AS SERVICECODE,
		COUNT(DISTINCT CASE WHEN (
			CVM."SameSchTimeFlag" = ''Y'' OR 
			CVM."SameVisitTimeFlag" = ''Y'' OR 
			CVM."SchAndVisitTimeSameFlag" = ''Y'' OR 
			CVM."SchOverAnotherSchTimeFlag" = ''Y'' OR 
			CVM."VisitTimeOverAnotherVisitTimeFlag" = ''Y'' OR 
			CVM."SchTimeOverVisitTimeFlag" = ''Y''
		) THEN CVM.CONFLICTID END) AS TO_TO,
		SUM( CASE WHEN (
			CVM."SameSchTimeFlag" = ''Y'' OR 
			CVM."SameVisitTimeFlag" = ''Y'' OR 
			CVM."SchAndVisitTimeSameFlag" = ''Y'' OR 
			CVM."SchOverAnotherSchTimeFlag" = ''Y'' OR 
			CVM."VisitTimeOverAnotherVisitTimeFlag" = ''Y'' OR 
			CVM."SchTimeOverVisitTimeFlag" = ''Y''
		) THEN CVMCH."ShiftPrice" ELSE 0 END ) AS TO_SP,
		SUM( CASE WHEN (
			CVM."SameSchTimeFlag" = ''Y'' OR 
			CVM."SameVisitTimeFlag" = ''Y'' OR 
			CVM."SchAndVisitTimeSameFlag" = ''Y'' OR 
			CVM."SchOverAnotherSchTimeFlag" = ''Y'' OR 
			CVM."VisitTimeOverAnotherVisitTimeFlag" = ''Y'' OR 
			CVM."SchTimeOverVisitTimeFlag" = ''Y''
		) THEN CVMCH."OverlapPrice" ELSE 0 END ) AS TO_OP,
		SUM( CASE WHEN (
			CVM."SameSchTimeFlag" = ''Y'' OR 
			CVM."SameVisitTimeFlag" = ''Y'' OR 
			CVM."SchAndVisitTimeSameFlag" = ''Y'' OR 
			CVM."SchOverAnotherSchTimeFlag" = ''Y'' OR 
			CVM."VisitTimeOverAnotherVisitTimeFlag" = ''Y'' OR 
			CVM."SchTimeOverVisitTimeFlag" = ''Y''
		) AND V2."StatusFlag" IN (''R'', ''D'') THEN CVMCH."OverlapPrice" ELSE 0 END ) AS TO_FP,
		COUNT(DISTINCT CASE WHEN CVM."DistanceFlag" = ''Y'' THEN CVM.CONFLICTID END) AS TD_TO,
		SUM( CASE WHEN CVM."DistanceFlag" = ''Y'' THEN CVMCH."ShiftPrice" ELSE 0 END ) AS TD_SP,
		SUM( CASE WHEN CVM."DistanceFlag" = ''Y'' THEN CVMCH."OverlapPrice" ELSE 0 END ) AS TD_OP,
		SUM( CASE WHEN CVM."DistanceFlag" = ''Y'' AND V2."StatusFlag" IN (''R'', ''D'') THEN CVMCH."OverlapPrice" ELSE 0 END ) AS TD_FP,
		COUNT(DISTINCT CASE WHEN CVM."InServiceFlag" = ''Y'' THEN CVM.CONFLICTID END) AS IN_TO,
		SUM( CASE WHEN CVM."InServiceFlag" = ''Y'' THEN CVMCH."ShiftPrice" ELSE 0 END ) AS IN_SP,
		SUM( CASE WHEN CVM."InServiceFlag" = ''Y'' THEN CVMCH."OverlapPrice" ELSE 0 END ) AS IN_OP,
		SUM( CASE WHEN CVM."InServiceFlag" = ''Y'' AND V2."StatusFlag" IN (''R'', ''D'') THEN CVMCH."OverlapPrice" ELSE 0 END ) AS IN_FP
	FROM
		CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS CVM
	INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2 ON
		V2."CONFLICTID" = CVM."CONFLICTID"
	LEFT JOIN (
		SELECT
			CVM1.ID,
			CASE
			    WHEN CVM1."BilledRateMinute" > 0 AND CVM1."BILLABLEMINUTESFULLSHIFT" IS NOT NULL THEN CVM1."BILLABLEMINUTESFULLSHIFT" * CVM1."BilledRateMinute"
				WHEN CVM1."BilledRateMinute" > 0 THEN TIMESTAMPDIFF(MINUTE, CVM1."ShVTSTTime", CVM1."ShVTENTime") * CVM1."BilledRateMinute"
				ELSE 0
			END AS "ShiftPrice",
			ROW_NUMBER() OVER (PARTITION BY CVM1."CONFLICTID"
		ORDER BY
			CASE
				WHEN CVM1."CShVTSTTime" >= CVM1."ShVTSTTime"
				AND CVM1."CShVTSTTime" <= CVM1."ShVTENTime"
				AND CVM1."CShVTENTime" > CVM1."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."CShVTSTTime", CVM1."ShVTENTime")
				WHEN CVM1."ShVTSTTime" >= CVM1."CShVTSTTime"
					AND CVM1."ShVTSTTime" <= CVM1."CShVTENTime"
					AND CVM1."ShVTENTime" > CVM1."CShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."ShVTSTTime", CVM1."CShVTENTime")
					WHEN CVM1."CShVTSTTime" >= CVM1."ShVTSTTime"
						AND CVM1."CShVTENTime" <= CVM1."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."CShVTSTTime", CVM1."CShVTENTime")
						WHEN CVM1."ShVTSTTime" >= CVM1."CShVTSTTime"
							AND CVM1."ShVTENTime" <= CVM1."CShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."ShVTSTTime", CVM1."ShVTENTime")
							WHEN CVM1."CShVTSTTime" < CVM1."ShVTSTTime"
								AND CVM1."CShVTENTime" > CVM1."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."ShVTSTTime", CVM1."ShVTENTime")
								WHEN CVM1."ShVTSTTime" < CVM1."CShVTSTTime"
									AND CVM1."ShVTENTime" > CVM1."CShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."CShVTSTTime", CVM1."CShVTENTime")
									ELSE 0
								END DESC) AS RN,
			CASE
			    WHEN CVM1."BilledRateMinute" > 0 AND CVM1."BILLABLEMINUTESOVERLAP" IS NOT NULL THEN CVM1."BILLABLEMINUTESOVERLAP" * CVM1."BilledRateMinute"
				WHEN CVM1."BilledRateMinute" > 0
					AND CVM1."CShVTSTTime" >= CVM1."ShVTSTTime"
					AND CVM1."CShVTSTTime" <= CVM1."ShVTENTime"
					AND CVM1."CShVTENTime" > CVM1."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."CShVTSTTime", CVM1."ShVTENTime") * CVM1."BilledRateMinute"
					WHEN CVM1."BilledRateMinute" > 0
						AND CVM1."ShVTSTTime" >= CVM1."CShVTSTTime"
						AND CVM1."ShVTSTTime" <= CVM1."CShVTENTime"
						AND CVM1."ShVTENTime" > CVM1."CShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."ShVTSTTime", CVM1."CShVTENTime") * CVM1."BilledRateMinute"
						WHEN CVM1."BilledRateMinute" > 0
							AND CVM1."CShVTSTTime" >= CVM1."ShVTSTTime"
							AND CVM1."CShVTENTime" <= CVM1."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."CShVTSTTime", CVM1."CShVTENTime") * CVM1."BilledRateMinute"
							WHEN CVM1."BilledRateMinute" > 0
								AND CVM1."ShVTSTTime" >= CVM1."CShVTSTTime"
								AND CVM1."ShVTENTime" <= CVM1."CShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."ShVTSTTime", CVM1."ShVTENTime") * CVM1."BilledRateMinute"
								WHEN CVM1."BilledRateMinute" > 0
									AND CVM1."CShVTSTTime" < CVM1."ShVTSTTime"
									AND CVM1."CShVTENTime" > CVM1."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."ShVTSTTime", CVM1."ShVTENTime") * CVM1."BilledRateMinute"
									WHEN CVM1."BilledRateMinute" > 0
										AND CVM1."ShVTSTTime" < CVM1."CShVTSTTime"
										AND CVM1."ShVTENTime" > CVM1."CShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."CShVTSTTime", CVM1."CShVTENTime") * CVM1."BilledRateMinute"
										ELSE 0
									END AS "OverlapPrice"
		FROM
			CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS CVM1
		 ) AS CVMCH ON CVMCH.ID = CVM.ID AND CVMCH.RN = 1
		WHERE NOT (CVM."PTOFlag" = ''Y'' 
			AND CVM."SameSchTimeFlag" = ''N'' 
			AND CVM."SameVisitTimeFlag" = ''N'' 
			AND CVM."SchAndVisitTimeSameFlag" = ''N'' 
			AND CVM."SchOverAnotherSchTimeFlag" = ''N'' 
			AND CVM."VisitTimeOverAnotherVisitTimeFlag" = ''N'' 
			AND CVM."SchTimeOverVisitTimeFlag" = ''N'' 
			AND CVM."DistanceFlag" = ''N'' 
			AND CVM."InServiceFlag" = ''N'')
		GROUP BY CVM."PayerState", CVM."PayerID", TO_CHAR(CVM."CRDATEUNIQUE", ''YYYY-MM-DD''), CVM."ProviderID", CVM."StatusFlag", CASE WHEN CVM."Billed" != ''yes'' THEN ''Avoidance'' ELSE ''Recovery'' END, CASE WHEN CVM."VisitStartTime" IS NULL THEN ''Scheduled'' WHEN CVM."Billed" != ''yes'' THEN ''Confirmed'' ELSE ''Billed'' END, COALESCE(CVM."P_PCounty", CVM."PA_PCounty"), CVM."ServiceCode"
	`;

  try {
      
      snowflake.execute({ sqlText: SQL3 });
		snowflake.execute({ sqlText: SQL4 });
      
      return "Provider Dashboard Data Loaded Successfully.";
  } catch (err) {
      throw "ERROR: " + err.message;
  }
';