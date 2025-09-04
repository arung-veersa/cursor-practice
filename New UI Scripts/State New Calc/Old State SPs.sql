CREATE OR REPLACE PROCEDURE CONFLICTREPORT_SANDBOX.PUBLIC.LOAD_STATE_DASHBOARD_AGENCY_DATA()
RETURNS VARCHAR
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS '
try {
    var truncateSql = `TRUNCATE TABLE CONFLICTREPORT_SANDBOX.PUBLIC.STATE_DASHBOARD_AGENCY`;
    
    var insertSql = `
    INSERT INTO CONFLICTREPORT_SANDBOX.PUBLIC.STATE_DASHBOARD_AGENCY (
        PAYERID, PROVIDERID, CRDATEUNIQUE, P_NAME,
        STATUSFLAG, COSTTYPE, VISITTYPE, COUNTY, SERVICECODE,
        CON_TO, CON_SP, CON_OP, CON_FP
    )
    SELECT
        CVM."PayerID",
        CVM."ProviderID",
        TO_CHAR(CVM."CRDATEUNIQUE", ''YYYY-MM-DD''),
        CVM."ProviderName" AS P_NAME,
        CVM."StatusFlag",
        CASE WHEN CVM."Billed" != ''yes'' THEN ''Avoidance'' ELSE ''Recovery'' END AS COSTTYPE,
        CASE 
            WHEN CVM."VisitStartTime" IS NULL THEN ''Scheduled'' 
            WHEN CVM."Billed" != ''yes'' THEN ''Confirmed'' 
            ELSE ''Billed'' 
        END AS VISITTYPE,
        COALESCE(CVM."PA_PCounty", CVM."P_PCounty") AS COUNTY,
        CVM."ServiceCode",
        COUNT(DISTINCT CVM.CONFLICTID) AS CON_TO,
        SUM(CVMCH."ShiftPrice") AS CON_SP,
        SUM(CVMCH."OverlapPrice") AS CON_OP,
        SUM(CASE WHEN V2_Status."StatusFlag" IN (''R'', ''D'') THEN CVMCH."OverlapPrice" ELSE 0 END) AS CON_FP
    FROM
        CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS CVM
    INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2_Status ON 
        V2_Status."CONFLICTID" = CVM."CONFLICTID"
		INNER JOIN (
        SELECT "GroupID", COUNT(DISTINCT "CONFLICTID") AS "GroupSize"
        FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS
        GROUP BY "GroupID"
    ) grp ON grp."GroupID" = CVM."GroupID"
    LEFT JOIN (
        SELECT
			CVM1."CONFLICTID",
            CASE
                WHEN CVM1."BilledRateMinute" > 0 AND CVM1."BILLABLEMINUTESFULLSHIFT" IS NOT NULL THEN CVM1."BILLABLEMINUTESFULLSHIFT" * CVM1."BilledRateMinute"
                WHEN CVM1."BilledRateMinute" > 0 THEN TIMESTAMPDIFF(MINUTE, CVM1."ShVTSTTime", CVM1."ShVTENTime") * CVM1."BilledRateMinute"
                ELSE 0
            END AS "ShiftPrice",
            
            CASE
                WHEN CVM1."BilledRateMinute" <= 0 THEN 0
				WHEN CVM1."BILLABLEMINUTESOVERLAP" IS NOT NULL AND (grp."GroupSize" <= 2 OR CVM1."DistanceFlag" = ''Y'') THEN CVM1."BILLABLEMINUTESOVERLAP" * CVM1."BilledRateMinute" 
				WHEN CVM1."BILLABLEMINUTESOVERLAP" IS NULL AND CVM1."DistanceFlag" = ''Y'' THEN 0
                WHEN CVM1."CShVTSTTime" >= CVM1."ShVTSTTime" AND CVM1."CShVTSTTime" <= CVM1."ShVTENTime" AND CVM1."CShVTENTime" > CVM1."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."CShVTSTTime", CVM1."ShVTENTime") * CVM1."BilledRateMinute"
                WHEN CVM1."ShVTSTTime" >= CVM1."CShVTSTTime" AND CVM1."ShVTSTTime" <= CVM1."CShVTENTime" AND CVM1."ShVTENTime" > CVM1."CShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."ShVTSTTime", CVM1."CShVTENTime") * CVM1."BilledRateMinute"
                WHEN CVM1."CShVTSTTime" >= CVM1."ShVTSTTime" AND CVM1."CShVTENTime" <= CVM1."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."CShVTSTTime", CVM1."CShVTENTime") * CVM1."BilledRateMinute"
                WHEN CVM1."ShVTSTTime" >= CVM1."CShVTSTTime" AND CVM1."ShVTENTime" <= CVM1."CShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."ShVTSTTime", CVM1."ShVTENTime") * CVM1."BilledRateMinute"
                WHEN CVM1."CShVTSTTime" < CVM1."ShVTSTTime" AND CVM1."CShVTENTime" > CVM1."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."ShVTSTTime", CVM1."ShVTENTime") * CVM1."BilledRateMinute"
                WHEN CVM1."ShVTSTTime" < CVM1."CShVTSTTime" AND CVM1."ShVTENTime" > CVM1."CShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."CShVTSTTime", CVM1."CShVTENTime") * CVM1."BilledRateMinute"
                ELSE 0
            END AS "OverlapPrice"
        FROM(
            -- Inner subquery to rank the rows
            SELECT *,
                ROW_NUMBER() OVER (PARTITION BY CVM1."CONFLICTID" ORDER BY CASE WHEN CVM1."CShVTSTTime" >= CVM1."ShVTSTTime" AND CVM1."CShVTSTTime" <= CVM1."ShVTENTime" AND CVM1."CShVTENTime" > CVM1."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."CShVTSTTime", CVM1."ShVTENTime") WHEN CVM1."ShVTSTTime" >= CVM1."CShVTSTTime" AND CVM1."ShVTSTTime" <= CVM1."CShVTENTime" AND CVM1."ShVTENTime" > CVM1."CShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."ShVTSTTime", CVM1."CShVTENTime") WHEN CVM1."CShVTSTTime" >= CVM1."ShVTSTTime" AND CVM1."CShVTENTime" <= CVM1."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."CShVTSTTime", CVM1."CShVTENTime") WHEN CVM1."ShVTSTTime" >= CVM1."CShVTSTTime" AND CVM1."ShVTENTime" <= CVM1."CShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."ShVTSTTime", CVM1."ShVTENTime") WHEN CVM1."CShVTSTTime" < CVM1."ShVTSTTime" AND CVM1."CShVTENTime" > CVM1."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."ShVTSTTime", CVM1."ShVTENTime") WHEN CVM1."ShVTSTTime" < CVM1."CShVTSTTime" AND CVM1."ShVTENTime" > CVM1."CShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."CShVTSTTime", CVM1."CShVTENTime") ELSE 0 END DESC) AS RN
            FROM
			CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS CVM1
			WHERE
                NOT (CVM1."PTOFlag" = ''Y'' AND CVM1."SameSchTimeFlag" = ''N'' AND CVM1."SameVisitTimeFlag" = ''N'' AND CVM1."SchAndVisitTimeSameFlag" = ''N'' AND CVM1."SchOverAnotherSchTimeFlag" = ''N'' AND CVM1."VisitTimeOverAnotherVisitTimeFlag" = ''N'' AND CVM1."SchTimeOverVisitTimeFlag" = ''N'' AND CVM1."DistanceFlag" = ''N'' AND CVM1."InServiceFlag" = ''N'')
                AND CVM1."Contract" IS NOT NULL
        ) AS CVM1
		INNER JOIN (
            SELECT "GroupID", COUNT(DISTINCT "CONFLICTID") AS "GroupSize"
            FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS
            GROUP BY "GroupID"
        ) grp ON grp."GroupID" = CVM1."GroupID"
			WHERE CVM1.RN = 1
    )AS CVMCH ON CVMCH."CONFLICTID" = CVM."CONFLICTID"
    WHERE 
        NOT (CVM."PTOFlag" = ''Y'' AND CVM."SameSchTimeFlag" = ''N'' AND CVM."SameVisitTimeFlag" = ''N'' AND CVM."SchAndVisitTimeSameFlag" = ''N'' AND CVM."SchOverAnotherSchTimeFlag" = ''N'' AND CVM."VisitTimeOverAnotherVisitTimeFlag" = ''N'' AND CVM."SchTimeOverVisitTimeFlag" = ''N'' AND CVM."DistanceFlag" = ''N'' AND CVM."InServiceFlag" = ''N'')
        AND CVM."ProviderName" IS NOT NULL
    GROUP BY
        CVM."PayerID", CVM."ProviderID", TO_CHAR(CVM."CRDATEUNIQUE", ''YYYY-MM-DD''), CVM."ProviderName",
        CVM."StatusFlag", COSTTYPE, VISITTYPE, COUNTY, CVM."ServiceCode"
    `;

    snowflake.execute({ sqlText: truncateSql });
    snowflake.execute({ sqlText: insertSql });
    
    return "State Agency Dashboard Data Loaded Successfully.";

} catch (err) {
    return "ERROR: " + err.message;
}
';

CREATE OR REPLACE PROCEDURE CONFLICTREPORT_SANDBOX.PUBLIC.LOAD_STATE_DASHBOARD_CAREGIVER_DATA()
RETURNS VARCHAR
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS '
try {
    var truncateSql = `TRUNCATE TABLE CONFLICTREPORT_SANDBOX.PUBLIC.STATE_DASHBOARD_CAREGIVER`;
    
    var insertSql = `
    INSERT INTO CONFLICTREPORT_SANDBOX.PUBLIC.STATE_DASHBOARD_CAREGIVER (
        PAYERID, PROVIDERID, CRDATEUNIQUE, SSN, C_NAME,
        STATUSFLAG, COSTTYPE, VISITTYPE, COUNTY, SERVICECODE,
        CON_TO, CON_SP, CON_OP, CON_FP
    )
    SELECT
        CVM."PayerID",
        CVM."ProviderID",
        TO_CHAR(CVM."CRDATEUNIQUE", ''YYYY-MM-DD''),
        CVM."SSN",
        MAX(CVM."AideName") AS C_NAME,
        CVM."StatusFlag",
        CASE WHEN CVM."Billed" != ''yes'' THEN ''Avoidance'' ELSE ''Recovery'' END AS COSTTYPE,
        CASE 
            WHEN CVM."VisitStartTime" IS NULL THEN ''Scheduled'' 
            WHEN CVM."Billed" != ''yes'' THEN ''Confirmed'' 
            ELSE ''Billed'' 
        END AS VISITTYPE,
        COALESCE(CVM."PA_PCounty", CVM."P_PCounty") AS COUNTY,
        CVM."ServiceCode",
        COUNT(DISTINCT CVM.CONFLICTID) AS CON_TO,
        SUM(CVMCH."ShiftPrice") AS CON_SP,
        SUM(CVMCH."OverlapPrice") AS CON_OP,
        SUM(CASE WHEN V2_Status."StatusFlag" IN (''R'', ''D'') THEN CVMCH."OverlapPrice" ELSE 0 END) AS CON_FP
    FROM
        CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS CVM
    INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2_Status ON 
        V2_Status."CONFLICTID" = CVM."CONFLICTID"
	INNER JOIN (
        SELECT "GroupID", COUNT(DISTINCT "CONFLICTID") AS "GroupSize"
        FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS
        GROUP BY "GroupID"
    ) grp ON grp."GroupID" = CVM."GroupID"
    LEFT JOIN (
        SELECT
            CVM1."CONFLICTID",
            CASE
                WHEN CVM1."BilledRateMinute" > 0 AND CVM1."BILLABLEMINUTESFULLSHIFT" IS NOT NULL THEN CVM1."BILLABLEMINUTESFULLSHIFT" * CVM1."BilledRateMinute"
                WHEN CVM1."BilledRateMinute" > 0 THEN TIMESTAMPDIFF(MINUTE, CVM1."ShVTSTTime", CVM1."ShVTENTime") * CVM1."BilledRateMinute"
                ELSE 0
            END AS "ShiftPrice",
            CASE
                WHEN CVM1."BilledRateMinute" <= 0 THEN 0
				WHEN CVM1."BILLABLEMINUTESOVERLAP" IS NOT NULL AND (grp."GroupSize" <= 2 OR CVM1."DistanceFlag" = ''Y'') THEN CVM1."BILLABLEMINUTESOVERLAP" * CVM1."BilledRateMinute" 
				WHEN CVM1."BILLABLEMINUTESOVERLAP" IS NULL AND CVM1."DistanceFlag" = ''Y'' THEN 0
                WHEN CVM1."CShVTSTTime" >= CVM1."ShVTSTTime" AND CVM1."CShVTSTTime" <= CVM1."ShVTENTime" AND CVM1."CShVTENTime" > CVM1."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."CShVTSTTime", CVM1."ShVTENTime") * CVM1."BilledRateMinute"
                WHEN CVM1."ShVTSTTime" >= CVM1."CShVTSTTime" AND CVM1."ShVTSTTime" <= CVM1."CShVTENTime" AND CVM1."ShVTENTime" > CVM1."CShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."ShVTSTTime", CVM1."CShVTENTime") * CVM1."BilledRateMinute"
                WHEN CVM1."CShVTSTTime" >= CVM1."ShVTSTTime" AND CVM1."CShVTENTime" <= CVM1."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."CShVTSTTime", CVM1."CShVTENTime") * CVM1."BilledRateMinute"
                WHEN CVM1."ShVTSTTime" >= CVM1."CShVTSTTime" AND CVM1."ShVTENTime" <= CVM1."CShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."ShVTSTTime", CVM1."ShVTENTime") * CVM1."BilledRateMinute"
                WHEN CVM1."CShVTSTTime" < CVM1."ShVTSTTime" AND CVM1."CShVTENTime" > CVM1."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."ShVTSTTime", CVM1."ShVTENTime") * CVM1."BilledRateMinute"
                WHEN CVM1."ShVTSTTime" < CVM1."CShVTSTTime" AND CVM1."ShVTENTime" > CVM1."CShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."CShVTSTTime", CVM1."CShVTENTime") * CVM1."BilledRateMinute"
                ELSE 0
            END AS "OverlapPrice"
        FROM(
            -- Inner subquery to rank the rows
            SELECT *,
                ROW_NUMBER() OVER (PARTITION BY CVM1."CONFLICTID" ORDER BY CASE WHEN CVM1."CShVTSTTime" >= CVM1."ShVTSTTime" AND CVM1."CShVTSTTime" <= CVM1."ShVTENTime" AND CVM1."CShVTENTime" > CVM1."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."CShVTSTTime", CVM1."ShVTENTime") WHEN CVM1."ShVTSTTime" >= CVM1."CShVTSTTime" AND CVM1."ShVTSTTime" <= CVM1."CShVTENTime" AND CVM1."ShVTENTime" > CVM1."CShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."ShVTSTTime", CVM1."CShVTENTime") WHEN CVM1."CShVTSTTime" >= CVM1."ShVTSTTime" AND CVM1."CShVTENTime" <= CVM1."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."CShVTSTTime", CVM1."CShVTENTime") WHEN CVM1."ShVTSTTime" >= CVM1."CShVTSTTime" AND CVM1."ShVTENTime" <= CVM1."CShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."ShVTSTTime", CVM1."ShVTENTime") WHEN CVM1."CShVTSTTime" < CVM1."ShVTSTTime" AND CVM1."CShVTENTime" > CVM1."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."ShVTSTTime", CVM1."ShVTENTime") WHEN CVM1."ShVTSTTime" < CVM1."CShVTSTTime" AND CVM1."ShVTENTime" > CVM1."CShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."CShVTSTTime", CVM1."CShVTENTime") ELSE 0 END DESC) AS RN
            FROM
			CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS CVM1
			 WHERE
                NOT (CVM1."PTOFlag" = ''Y'' AND CVM1."SameSchTimeFlag" = ''N'' AND CVM1."SameVisitTimeFlag" = ''N'' AND CVM1."SchAndVisitTimeSameFlag" = ''N'' AND CVM1."SchOverAnotherSchTimeFlag" = ''N'' AND CVM1."VisitTimeOverAnotherVisitTimeFlag" = ''N'' AND CVM1."SchTimeOverVisitTimeFlag" = ''N'' AND CVM1."DistanceFlag" = ''N'' AND CVM1."InServiceFlag" = ''N'')
                AND CVM1."Contract" IS NOT NULL
        ) AS CVM1
		INNER JOIN (
            SELECT "GroupID", COUNT(DISTINCT "CONFLICTID") AS "GroupSize"
            FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS
            GROUP BY "GroupID"
        ) grp ON grp."GroupID" = CVM1."GroupID"
		WHERE CVM1.RN = 1
    ) AS CVMCH ON CVMCH."CONFLICTID" = CVM."CONFLICTID"
    WHERE 
        NOT (CVM."PTOFlag" = ''Y'' AND CVM."SameSchTimeFlag" = ''N'' AND CVM."SameVisitTimeFlag" = ''N'' AND CVM."SchAndVisitTimeSameFlag" = ''N'' AND CVM."SchOverAnotherSchTimeFlag" = ''N'' AND CVM."VisitTimeOverAnotherVisitTimeFlag" = ''N'' AND CVM."SchTimeOverVisitTimeFlag" = ''N'' AND CVM."DistanceFlag" = ''N'' AND CVM."InServiceFlag" = ''N'')
        AND CVM."SSN" IS NOT NULL
    GROUP BY
        CVM."PayerID", CVM."ProviderID", TO_CHAR(CVM."CRDATEUNIQUE", ''YYYY-MM-DD''), CVM."SSN",
        CVM."StatusFlag", COSTTYPE, VISITTYPE, COUNTY, CVM."ServiceCode"
    `;

    snowflake.execute({ sqlText: truncateSql });
    snowflake.execute({ sqlText: insertSql });
    
    return "State Caregiver Dashboard Data Loaded Successfully.";

} catch (err) {
    return "ERROR: " + err.message;
}
';

CREATE OR REPLACE PROCEDURE CONFLICTREPORT_SANDBOX.PUBLIC.LOAD_STATE_DASHBOARD_DATA()
RETURNS VARCHAR
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS '
	
	var SQL3 = `TRUNCATE TABLE CONFLICTREPORT_SANDBOX.PUBLIC.STATE_DASHBOARD_CON_TYPE`;
	var SQL4 = `INSERT INTO CONFLICTREPORT_SANDBOX.PUBLIC.STATE_DASHBOARD_CON_TYPE (PAYERID, PROVIDERID, CRDATEUNIQUE, STATUSFLAG, COSTTYPE, VISITTYPE, COUNTY, SERVICECODE, TO_TO, TO_SP, TO_OP, TO_FP, TD_TO, TD_SP, TD_OP, TD_FP, IN_TO, IN_SP, IN_OP, IN_FP)
	SELECT
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
		COALESCE(CVM."PA_PCounty", CVM."P_PCounty") AS COUNTY,
		CVM."ServiceCode" AS SERVICECODE,
		COUNT(DISTINCT CASE WHEN (
			CVM."SameSchTimeFlag" = ''Y'' OR 
			CVM."SameVisitTimeFlag" = ''Y'' OR 
			CVM."SchAndVisitTimeSameFlag" = ''Y'' OR 
			CVM."SchOverAnotherSchTimeFlag" = ''Y'' OR 
			CVM."VisitTimeOverAnotherVisitTimeFlag" = ''Y'' OR 
			CVM."SchTimeOverVisitTimeFlag" = ''Y''
		) THEN CVM.CONFLICTID END) AS TO_TO,
		SUM(CASE WHEN (
			CVM."SameSchTimeFlag" = ''Y'' OR 
			CVM."SameVisitTimeFlag" = ''Y'' OR 
			CVM."SchAndVisitTimeSameFlag" = ''Y'' OR 
			CVM."SchOverAnotherSchTimeFlag" = ''Y'' OR 
			CVM."VisitTimeOverAnotherVisitTimeFlag" = ''Y'' OR 
			CVM."SchTimeOverVisitTimeFlag" = ''Y''
		) THEN CVMCH."ShiftPrice" ELSE 0 END ) AS TO_SP,
		SUM(CASE WHEN (
			CVM."SameSchTimeFlag" = ''Y'' OR 
			CVM."SameVisitTimeFlag" = ''Y'' OR 
			CVM."SchAndVisitTimeSameFlag" = ''Y'' OR 
			CVM."SchOverAnotherSchTimeFlag" = ''Y'' OR 
			CVM."VisitTimeOverAnotherVisitTimeFlag" = ''Y'' OR 
			CVM."SchTimeOverVisitTimeFlag" = ''Y''
		) THEN CVMCH."OverlapPrice" ELSE 0 END ) AS TO_OP,
		SUM(CASE WHEN (
			CVM."SameSchTimeFlag" = ''Y'' OR 
			CVM."SameVisitTimeFlag" = ''Y'' OR 
			CVM."SchAndVisitTimeSameFlag" = ''Y'' OR 
			CVM."SchOverAnotherSchTimeFlag" = ''Y'' OR 
			CVM."VisitTimeOverAnotherVisitTimeFlag" = ''Y'' OR 
			CVM."SchTimeOverVisitTimeFlag" = ''Y''
		) AND V2."StatusFlag" IN (''R'', ''D'') THEN CVMCH."OverlapPrice" ELSE 0 END ) AS TO_FP,
		COUNT(DISTINCT CASE WHEN CVM."DistanceFlag" = ''Y'' THEN CVM.CONFLICTID END) AS TD_TO,
		SUM(CASE WHEN CVM."DistanceFlag" = ''Y'' THEN CVMCH."ShiftPrice" ELSE 0 END ) AS TD_SP,
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
		INNER JOIN (
        SELECT "GroupID", COUNT(DISTINCT "CONFLICTID") AS "GroupSize"
        FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS
        GROUP BY "GroupID"
    ) grp ON grp."GroupID" = CVM."GroupID"
	LEFT JOIN (
		SELECT
			CVM1.CONFLICTID,
			CASE
			    WHEN CVM1."BilledRateMinute" > 0 AND CVM1."BILLABLEMINUTESFULLSHIFT" IS NOT NULL THEN CVM1."BILLABLEMINUTESFULLSHIFT" * CVM1."BilledRateMinute"
				WHEN CVM1."BilledRateMinute" > 0 THEN TIMESTAMPDIFF(MINUTE, CVM1."ShVTSTTime", CVM1."ShVTENTime") * CVM1."BilledRateMinute"
				ELSE 0
			END AS "ShiftPrice",
			ROW_NUMBER() OVER (PARTITION BY CVM1."CONFLICTID"
		ORDER BY
			CASE
				WHEN CVM1."CShVTSTTime" >= CVM1."ShVTSTTime" AND CVM1."CShVTSTTime" <= CVM1."ShVTENTime" AND CVM1."CShVTENTime" > CVM1."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."CShVTSTTime", CVM1."ShVTENTime")
				WHEN CVM1."ShVTSTTime" >= CVM1."CShVTSTTime" AND CVM1."ShVTSTTime" <= CVM1."CShVTENTime" AND CVM1."ShVTENTime" > CVM1."CShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."ShVTSTTime", CVM1."CShVTENTime")
				WHEN CVM1."CShVTSTTime" >= CVM1."ShVTSTTime" AND CVM1."CShVTENTime" <= CVM1."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."CShVTSTTime", CVM1."CShVTENTime")
				WHEN CVM1."ShVTSTTime" >= CVM1."CShVTSTTime" AND CVM1."ShVTENTime" <= CVM1."CShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."ShVTSTTime", CVM1."ShVTENTime")
				WHEN CVM1."CShVTSTTime" < CVM1."ShVTSTTime" AND CVM1."CShVTENTime" > CVM1."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."ShVTSTTime", CVM1."ShVTENTime")
				WHEN CVM1."ShVTSTTime" < CVM1."CShVTSTTime" AND CVM1."ShVTENTime" > CVM1."CShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."CShVTSTTime", CVM1."CShVTENTime")
				ELSE 0
			END DESC) AS RN,
			CASE
				WHEN CVM1."BilledRateMinute" <= 0 THEN 0
				WHEN CVM1."BILLABLEMINUTESOVERLAP" IS NOT NULL AND (grp."GroupSize" <= 2 OR CVM1."DistanceFlag" = ''Y'') THEN CVM1."BILLABLEMINUTESOVERLAP" * CVM1."BilledRateMinute" 
				WHEN CVM1."BILLABLEMINUTESOVERLAP" IS NULL AND CVM1."DistanceFlag" = ''Y'' THEN 0
				WHEN CVM1."CShVTSTTime" >= CVM1."ShVTSTTime" AND CVM1."CShVTSTTime" <= CVM1."ShVTENTime" AND CVM1."CShVTENTime" > CVM1."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."CShVTSTTime", CVM1."ShVTENTime") * CVM1."BilledRateMinute"
				WHEN CVM1."ShVTSTTime" >= CVM1."CShVTSTTime" AND CVM1."ShVTSTTime" <= CVM1."CShVTENTime" AND CVM1."ShVTENTime" > CVM1."CShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."ShVTSTTime", CVM1."CShVTENTime") * CVM1."BilledRateMinute"
				WHEN CVM1."CShVTSTTime" >= CVM1."ShVTSTTime" AND CVM1."CShVTENTime" <= CVM1."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."CShVTSTTime", CVM1."CShVTENTime") * CVM1."BilledRateMinute"
				WHEN CVM1."ShVTSTTime" >= CVM1."CShVTSTTime" AND CVM1."ShVTENTime" <= CVM1."CShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."ShVTSTTime", CVM1."ShVTENTime") * CVM1."BilledRateMinute"
				WHEN CVM1."CShVTSTTime" < CVM1."ShVTSTTime" AND CVM1."CShVTENTime" > CVM1."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."ShVTSTTime", CVM1."ShVTENTime") * CVM1."BilledRateMinute"
				WHEN CVM1."ShVTSTTime" < CVM1."CShVTSTTime" AND CVM1."ShVTENTime" > CVM1."CShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."CShVTSTTime", CVM1."CShVTENTime") * CVM1."BilledRateMinute"
				ELSE 0
			END AS "OverlapPrice"
		FROM
			CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS CVM1
        INNER JOIN (
            SELECT "GroupID", COUNT(DISTINCT "CONFLICTID") AS "GroupSize"
            FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS
            GROUP BY "GroupID"
        ) grp ON grp."GroupID" = CVM1."GroupID"
	) AS CVMCH ON CVMCH.CONFLICTID= CVM.CONFLICTID AND CVMCH.RN = 1
	WHERE NOT (CVM."PTOFlag" = ''Y'' 
		AND CVM."SameSchTimeFlag" = ''N'' 
		AND CVM."SameVisitTimeFlag" = ''N'' 
		AND CVM."SchAndVisitTimeSameFlag" = ''N'' 
		AND CVM."SchOverAnotherSchTimeFlag" = ''N'' 
		AND CVM."VisitTimeOverAnotherVisitTimeFlag" = ''N'' 
		AND CVM."SchTimeOverVisitTimeFlag" = ''N'' 
		AND CVM."DistanceFlag" = ''N'' 
		AND CVM."InServiceFlag" = ''N'')
	GROUP BY CVM."PayerID", TO_CHAR(CVM."CRDATEUNIQUE", ''YYYY-MM-DD''), CVM."ProviderID", CVM."StatusFlag", CASE WHEN CVM."Billed" != ''yes'' THEN ''Avoidance'' ELSE ''Recovery'' END, CASE WHEN CVM."VisitStartTime" IS NULL THEN ''Scheduled'' WHEN CVM."Billed" != ''yes'' THEN ''Confirmed'' ELSE ''Billed'' END, COALESCE(CVM."PA_PCounty", CVM."P_PCounty"), CVM."ServiceCode"
	`;

  try {
    	snowflake.execute({ sqlText: SQL3 });
		snowflake.execute({ sqlText: SQL4 });
      return "State Conflict Type Dashboard Data Loaded Successfully.";
  } catch (err) {
      throw "ERROR: " + err.message;
  }
';

CREATE OR REPLACE PROCEDURE CONFLICTREPORT_SANDBOX.PUBLIC.LOAD_STATE_DASHBOARD_PATIENT_DATA()
RETURNS VARCHAR
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS '
try {
    var truncateSql = `TRUNCATE TABLE CONFLICTREPORT_SANDBOX.PUBLIC.STATE_DASHBOARD_PATIENT`;
    
    var insertSql = `
    INSERT INTO CONFLICTREPORT_SANDBOX.PUBLIC.STATE_DASHBOARD_PATIENT (
        PAYERID, PROVIDERID, CRDATEUNIQUE, PATIENTID, PNAME,
        STATUSFLAG, COSTTYPE, VISITTYPE, COUNTY, SERVICECODE,
        CON_TO, CON_SP, CON_OP, CON_FP
    )
    SELECT
        CVM."PayerID" AS PAYERID,
        CVM."ProviderID" AS PROVIDERID,
        TO_CHAR(CVM."CRDATEUNIQUE", ''YYYY-MM-DD'') AS CRDATEUNIQUE,
        CVM."PA_PatientID" AS PATIENTID,
        CVM."PA_PName" AS PNAME,
        CVM."StatusFlag" AS STATUSFLAG,
        CASE WHEN CVM."Billed" != ''yes'' THEN ''Avoidance'' ELSE ''Recovery'' END AS COSTTYPE,
        CASE 
            WHEN CVM."VisitStartTime" IS NULL THEN ''Scheduled'' 
            WHEN CVM."Billed" != ''yes'' THEN ''Confirmed'' 
            ELSE ''Billed'' 
        END AS VISITTYPE,
        COALESCE(CVM."PA_PCounty", CVM."P_PCounty") AS COUNTY,
        CVM."ServiceCode" AS SERVICECODE,
        
        -- Consolidated Metrics
        COUNT(DISTINCT CVM.CONFLICTID) AS CON_TO,
        SUM(CVMCH."ShiftPrice") AS CON_SP,
        SUM(CVMCH."OverlapPrice") AS CON_OP,
        SUM(CASE WHEN V2."StatusFlag" IN (''R'', ''D'') THEN CVMCH."OverlapPrice" ELSE 0 END) AS CON_FP
        
    FROM
        CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS CVM
    INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2 ON
        V2."CONFLICTID" = CVM."CONFLICTID"
	INNER JOIN (
        SELECT "GroupID", COUNT(DISTINCT "CONFLICTID") AS "GroupSize"
        FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS
        GROUP BY "GroupID"
    ) grp ON grp."GroupID" = CVM."GroupID"
    LEFT JOIN (
        SELECT
            CVM1.CONFLICTID,
            CASE
                WHEN CVM1."BilledRateMinute" > 0 AND CVM1."BILLABLEMINUTESFULLSHIFT" IS NOT NULL THEN CVM1."BILLABLEMINUTESFULLSHIFT" * CVM1."BilledRateMinute"
                WHEN CVM1."BilledRateMinute" > 0 THEN TIMESTAMPDIFF(MINUTE, CVM1."ShVTSTTime", CVM1."ShVTENTime") * CVM1."BilledRateMinute"
                ELSE 0
            END AS "ShiftPrice",
            ROW_NUMBER() OVER (PARTITION BY CVM1."CONFLICTID" ORDER BY CASE WHEN CVM1."CShVTSTTime" >= CVM1."ShVTSTTime" AND CVM1."CShVTSTTime" <= CVM1."ShVTENTime" AND CVM1."CShVTENTime" > CVM1."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."CShVTSTTime", CVM1."ShVTENTime") WHEN CVM1."ShVTSTTime" >= CVM1."CShVTSTTime" AND CVM1."ShVTSTTime" <= CVM1."CShVTENTime" AND CVM1."ShVTENTime" > CVM1."CShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."ShVTSTTime", CVM1."CShVTENTime") WHEN CVM1."CShVTSTTime" >= CVM1."ShVTSTTime" AND CVM1."CShVTENTime" <= CVM1."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."CShVTSTTime", CVM1."CShVTENTime") WHEN CVM1."ShVTSTTime" >= CVM1."CShVTSTTime" AND CVM1."ShVTENTime" <= CVM1."CShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."ShVTSTTime", CVM1."ShVTENTime") WHEN CVM1."CShVTSTTime" < CVM1."ShVTSTTime" AND CVM1."CShVTENTime" > CVM1."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."ShVTSTTime", CVM1."ShVTENTime") WHEN CVM1."ShVTSTTime" < CVM1."CShVTSTTime" AND CVM1."ShVTENTime" > CVM1."CShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."CShVTSTTime", CVM1."CShVTENTime") ELSE 0 END DESC) AS RN,
            CASE
				WHEN CVM1."BilledRateMinute" <= 0 THEN 0
				WHEN CVM1."BILLABLEMINUTESOVERLAP" IS NOT NULL AND (grp."GroupSize" <= 2 OR CVM1."DistanceFlag" = ''Y'') THEN CVM1."BILLABLEMINUTESOVERLAP" * CVM1."BilledRateMinute" 
				WHEN CVM1."BILLABLEMINUTESOVERLAP" IS NULL AND CVM1."DistanceFlag" = ''Y'' THEN 0
				WHEN CVM1."CShVTSTTime" >= CVM1."ShVTSTTime" AND CVM1."CShVTSTTime" <= CVM1."ShVTENTime" AND CVM1."CShVTENTime" > CVM1."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."CShVTSTTime", CVM1."ShVTENTime") * CVM1."BilledRateMinute"
                WHEN CVM1."ShVTSTTime" >= CVM1."CShVTSTTime" AND CVM1."ShVTSTTime" <= CVM1."CShVTENTime" AND CVM1."ShVTENTime" > CVM1."CShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."ShVTSTTime", CVM1."CShVTENTime") * CVM1."BilledRateMinute"
                WHEN CVM1."CShVTSTTime" >= CVM1."ShVTSTTime" AND CVM1."CShVTENTime" <= CVM1."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."CShVTSTTime", CVM1."CShVTENTime") * CVM1."BilledRateMinute"
                WHEN CVM1."ShVTSTTime" >= CVM1."CShVTSTTime" AND CVM1."ShVTENTime" <= CVM1."CShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."ShVTSTTime", CVM1."ShVTENTime") * CVM1."BilledRateMinute"
                WHEN CVM1."CShVTSTTime" < CVM1."ShVTSTTime" AND CVM1."CShVTENTime" > CVM1."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."ShVTSTTime", CVM1."ShVTENTime") * CVM1."BilledRateMinute"
                WHEN CVM1."ShVTSTTime" < CVM1."CShVTSTTime" AND CVM1."ShVTENTime" > CVM1."CShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."CShVTSTTime", CVM1."CShVTENTime") * CVM1."BilledRateMinute"
                ELSE 0
            END AS "OverlapPrice"
        FROM
            CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS CVM1
		INNER JOIN (
            SELECT "GroupID", COUNT(DISTINCT "CONFLICTID") AS "GroupSize"
            FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS
            GROUP BY "GroupID"
        ) grp ON grp."GroupID" = CVM1."GroupID"
    ) AS CVMCH ON CVMCH.CONFLICTID = CVM.CONFLICTID AND CVMCH.RN = 1
    WHERE 
        NOT (CVM."PTOFlag" = ''Y'' AND CVM."SameSchTimeFlag" = ''N'' AND CVM."SameVisitTimeFlag" = ''N'' AND CVM."SchAndVisitTimeSameFlag" = ''N'' AND CVM."SchOverAnotherSchTimeFlag" = ''N'' AND CVM."VisitTimeOverAnotherVisitTimeFlag" = ''N'' AND CVM."SchTimeOverVisitTimeFlag" = ''N'' AND CVM."DistanceFlag" = ''N'' AND CVM."InServiceFlag" = ''N'')
        AND CVM."PA_PName" IS NOT NULL
    GROUP BY 
        CVM."PayerID", 
        CVM."ProviderID", 
        TO_CHAR(CVM."CRDATEUNIQUE", ''YYYY-MM-DD''), 
        CVM."PA_PatientID",
        CVM."PA_PName",
        CVM."StatusFlag", 
        COSTTYPE, 
        VISITTYPE, 
        COUNTY, 
        CVM."ServiceCode"
    `;

    snowflake.execute({ sqlText: truncateSql });
    snowflake.execute({ sqlText: insertSql });
    
    return "State Patient Dashboard Data Loaded Successfully.";

} catch (err) {
    return "ERROR: " + err.message;
}
';

CREATE OR REPLACE PROCEDURE CONFLICTREPORT_SANDBOX.PUBLIC.LOAD_STATE_DASHBOARD_PAYER_DATA()
RETURNS VARCHAR
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS '
try {
    var truncateSql = `TRUNCATE TABLE CONFLICTREPORT_SANDBOX.PUBLIC.STATE_DASHBOARD_PAYER`;
    
    var insertSql = `
    INSERT INTO CONFLICTREPORT_SANDBOX.PUBLIC.STATE_DASHBOARD_PAYER (
        PAYERID, PROVIDERID, CRDATEUNIQUE, PNAME,
        STATUSFLAG, COSTTYPE, VISITTYPE, COUNTY, SERVICECODE,
        CON_TO, CON_SP, CON_OP, CON_FP
    )
    SELECT
        CVM."PayerID",
        CVM."ProviderID",
        TO_CHAR(CVM."CRDATEUNIQUE", ''YYYY-MM-DD''),
        CVM."Contract" AS PNAME,
        CVM."StatusFlag",
        CASE WHEN CVM."Billed" != ''yes'' THEN ''Avoidance'' ELSE ''Recovery'' END AS COSTTYPE,
        CASE 
            WHEN CVM."VisitStartTime" IS NULL THEN ''Scheduled'' 
            WHEN CVM."Billed" != ''yes'' THEN ''Confirmed'' 
            ELSE ''Billed'' 
        END AS VISITTYPE,
        COALESCE(CVM."PA_PCounty", CVM."P_PCounty") AS COUNTY,
        CVM."ServiceCode",
        COUNT(DISTINCT CVM.CONFLICTID) AS CON_TO,
        SUM(CVMCH."ShiftPrice") AS CON_SP,
        SUM(CVMCH."OverlapPrice") AS CON_OP,
        SUM(CASE WHEN V2."StatusFlag" IN (''R'', ''D'') THEN CVMCH."OverlapPrice" ELSE 0 END) AS CON_FP
    FROM
        CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS CVM
    INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2 ON 
        V2."CONFLICTID" = CVM."CONFLICTID"
	INNER JOIN (
        SELECT "GroupID", COUNT(DISTINCT "CONFLICTID") AS "GroupSize"
        FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS
        GROUP BY "GroupID"
    ) grp ON grp."GroupID" = CVM."GroupID"
    LEFT JOIN (
        
        SELECT
            CVM1."CONFLICTID",
            CASE
                WHEN CVM1."BilledRateMinute" > 0 AND CVM1."BILLABLEMINUTESFULLSHIFT" IS NOT NULL THEN CVM1."BILLABLEMINUTESFULLSHIFT" * CVM1."BilledRateMinute"
                WHEN CVM1."BilledRateMinute" > 0 THEN TIMESTAMPDIFF(MINUTE, CVM1."ShVTSTTime", CVM1."ShVTENTime") * CVM1."BilledRateMinute"
                ELSE 0
            END AS "ShiftPrice",
            CASE
				WHEN CVM1."BilledRateMinute" <= 0 THEN 0
				WHEN CVM1."BILLABLEMINUTESOVERLAP" IS NOT NULL AND (grp."GroupSize" <= 2 OR CVM1."DistanceFlag" = ''Y'') THEN CVM1."BILLABLEMINUTESOVERLAP" * CVM1."BilledRateMinute" 
				WHEN CVM1."BILLABLEMINUTESOVERLAP" IS NULL AND CVM1."DistanceFlag" = ''Y'' THEN 0
                WHEN CVM1."CShVTSTTime" >= CVM1."ShVTSTTime" AND CVM1."CShVTSTTime" <= CVM1."ShVTENTime" AND CVM1."CShVTENTime" > CVM1."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."CShVTSTTime", CVM1."ShVTENTime") * CVM1."BilledRateMinute"
                WHEN CVM1."ShVTSTTime" >= CVM1."CShVTSTTime" AND CVM1."ShVTSTTime" <= CVM1."CShVTENTime" AND CVM1."ShVTENTime" > CVM1."CShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."ShVTSTTime", CVM1."CShVTENTime") * CVM1."BilledRateMinute"
                WHEN CVM1."CShVTSTTime" >= CVM1."ShVTSTTime" AND CVM1."CShVTENTime" <= CVM1."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."CShVTSTTime", CVM1."CShVTENTime") * CVM1."BilledRateMinute"
                WHEN CVM1."ShVTSTTime" >= CVM1."CShVTSTTime" AND CVM1."ShVTENTime" <= CVM1."CShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."ShVTSTTime", CVM1."ShVTENTime") * CVM1."BilledRateMinute"
                WHEN CVM1."CShVTSTTime" < CVM1."ShVTSTTime" AND CVM1."CShVTENTime" > CVM1."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."ShVTSTTime", CVM1."ShVTENTime") * CVM1."BilledRateMinute"
                WHEN CVM1."ShVTSTTime" < CVM1."CShVTSTTime" AND CVM1."ShVTENTime" > CVM1."CShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."CShVTSTTime", CVM1."CShVTENTime") * CVM1."BilledRateMinute"
                ELSE 0
            END AS "OverlapPrice"
        FROM (
            -- Inner subquery to rank the rows
            SELECT *,
                ROW_NUMBER() OVER (PARTITION BY CVM1."CONFLICTID" ORDER BY CASE WHEN CVM1."CShVTSTTime" >= CVM1."ShVTSTTime" AND CVM1."CShVTSTTime" <= CVM1."ShVTENTime" AND CVM1."CShVTENTime" > CVM1."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."CShVTSTTime", CVM1."ShVTENTime") WHEN CVM1."ShVTSTTime" >= CVM1."CShVTSTTime" AND CVM1."ShVTSTTime" <= CVM1."CShVTENTime" AND CVM1."ShVTENTime" > CVM1."CShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."ShVTSTTime", CVM1."CShVTENTime") WHEN CVM1."CShVTSTTime" >= CVM1."ShVTSTTime" AND CVM1."CShVTENTime" <= CVM1."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."CShVTSTTime", CVM1."CShVTENTime") WHEN CVM1."ShVTSTTime" >= CVM1."CShVTSTTime" AND CVM1."ShVTENTime" <= CVM1."CShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."ShVTSTTime", CVM1."ShVTENTime") WHEN CVM1."CShVTSTTime" < CVM1."ShVTSTTime" AND CVM1."CShVTENTime" > CVM1."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."ShVTSTTime", CVM1."ShVTENTime") WHEN CVM1."ShVTSTTime" < CVM1."CShVTSTTime" AND CVM1."ShVTENTime" > CVM1."CShVTENTime" THEN TIMESTAMPDIFF(MINUTE, CVM1."CShVTSTTime", CVM1."CShVTENTime") ELSE 0 END DESC) AS RN
            FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS CVM1
            WHERE
                NOT (CVM1."PTOFlag" = ''Y'' AND CVM1."SameSchTimeFlag" = ''N'' AND CVM1."SameVisitTimeFlag" = ''N'' AND CVM1."SchAndVisitTimeSameFlag" = ''N'' AND CVM1."SchOverAnotherSchTimeFlag" = ''N'' AND CVM1."VisitTimeOverAnotherVisitTimeFlag" = ''N'' AND CVM1."SchTimeOverVisitTimeFlag" = ''N'' AND CVM1."DistanceFlag" = ''N'' AND CVM1."InServiceFlag" = ''N'')
                AND CVM1."Contract" IS NOT NULL
        ) AS CVM1
        INNER JOIN (
            SELECT "GroupID", COUNT(DISTINCT "CONFLICTID") AS "GroupSize"
            FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS
            GROUP BY "GroupID"
        ) grp ON grp."GroupID" = CVM1."GroupID"
        WHERE CVM1.RN = 1
    ) AS CVMCH ON CVMCH."CONFLICTID" = CVM."CONFLICTID" -- CORRECTED JOIN CONDITION
     WHERE
        NOT (CVM."PTOFlag" = ''Y'' AND CVM."SameSchTimeFlag" = ''N'' AND CVM."SameVisitTimeFlag" = ''N'' AND CVM."SchAndVisitTimeSameFlag" = ''N'' AND CVM."SchOverAnotherSchTimeFlag" = ''N'' AND CVM."VisitTimeOverAnotherVisitTimeFlag" = ''N'' AND CVM."SchTimeOverVisitTimeFlag" = ''N'' AND CVM."DistanceFlag" = ''N'' AND CVM."InServiceFlag" = ''N'')
		AND CVM."Contract" IS NOT NULL
    GROUP BY
        CVM."PayerID",
        CVM."ProviderID",
        TO_CHAR(CVM."CRDATEUNIQUE", ''YYYY-MM-DD''),
        CVM."Contract",
        CVM."StatusFlag",
        COSTTYPE,
        VISITTYPE,
        COUNTY,
        CVM."ServiceCode"
    `;

    snowflake.execute({ sqlText: truncateSql });
    snowflake.execute({ sqlText: insertSql });
    
    return "State Payer Dashboard Data Loaded Successfully.";

} catch (err) {
    return "ERROR: " + err.message;
}
';