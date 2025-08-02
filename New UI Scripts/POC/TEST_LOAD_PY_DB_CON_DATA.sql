CREATE OR REPLACE PROCEDURE TEST_LOAD_PY_DB_CON_DATA()
RETURNS VARCHAR
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS '
	try {

	    var truncate1Stmt = snowflake.createStatement({
	        sqlText: `TRUNCATE TABLE TEST_PY_DB_CON`
	    });
	    truncate1Stmt.execute();
	
	    // Step 2: Fetch payer IDs
	    var payerStmt = snowflake.createStatement({
	        sqlText: `SELECT DISTINCT a.APID FROM
		ANALYTICS.BI.DIMPAYER AS P
		JOIN
		    (
		    SELECT
		        DISTINCT V1."GroupID",
		        V1."CONFLICTID",
		        V1."PayerID" AS APID
		    FROM
		        CONFLICTVISITMAPS AS V1
		    INNER JOIN CONFLICTS AS V2 ON
		        V2."CONFLICTID" = V1."CONFLICTID"
		    WHERE
		        V1."GroupID" IN (
		        SELECT
		            DISTINCT "GroupID"
		        FROM
		            CONFLICTVISITMAPS
		        --WHERE
		          --  ("SchOverAnotherSchTimeFlag" = ''Y''
		           --     OR "VisitTimeOverAnotherVisitTimeFlag" = ''Y'')
				 ) ) a
		LEFT JOIN (
		    SELECT
		        DISTINCT V1."GroupID",
		        V1."CONFLICTID"
		    FROM
		        CONFLICTVISITMAPS AS V1
		    INNER JOIN CONFLICTS AS V2 ON
		        V2."CONFLICTID" = V1."CONFLICTID"
		    WHERE
		        V1."GroupID" IN (
		        SELECT
		            DISTINCT "GroupID"
		        FROM
		            CONFLICTVISITMAPS
		        --WHERE
		           -- ("SchOverAnotherSchTimeFlag" = ''Y''
		             --   OR "VisitTimeOverAnotherVisitTimeFlag" = ''Y'')
		             ) ) b ON
		    a.CONFLICTID <> b.CONFLICTID
		    AND a."GroupID" = b."GroupID"
		    WHERE P."Is Active" = TRUE AND P."Is Demo" = FALSE AND P."Payer Id" = a.APID`
	    });
	
	    var payerResult = payerStmt.execute();
	
	    // Step 3: Loop through result set
	    while (payerResult.next()) {
	        var payerId = payerResult.getColumnValue(1);
			
			//-------------------------PAYER CON TYPE---------------------
	
			var insercontypes = `
				INSERT INTO TEST_PY_DB_CON (PAYERID, CRDATEUNIQUE, CONTYPE, CONTYPES, SERVICECODE, STATUSFLAG, BILLED, ISCONFIRMED, CO_TO, CO_SP, CO_OP, CO_FP)
				SELECT
				*
				FROM
					(
					SELECT
						''${payerId}'' AS PAYERID,
						a."CRDATEUNIQUE" AS "CRDATEUNIQUE",
						''Exact Schedule Time Match'' AS "CONTYPE",
						1 AS "CONTYPES",
						a."ServiceCode" AS "SERVICECODE",
						a."StatusFlag" AS "STATUSFLAG",
						a."Billed" AS "BILLED",
						a."IsConfirmed" AS "ISCONFIRMED",
						COUNT(DISTINCT a."GroupID") AS "CO_TO",
						SUM(CASE WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" ELSE 0 END) AS "CO_SP",
						SUM( CASE WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTSTTime" <= a."ShVTENTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTSTTime" <= b."ShVTENTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" < a."ShVTSTTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" < b."ShVTSTTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" ELSE 0 END ) AS "CO_OP",
						SUM( CASE WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTSTTime" <= a."ShVTENTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTSTTime" <= b."ShVTENTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" < a."ShVTSTTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" < b."ShVTSTTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" ELSE 0 END ) AS "CO_FP"
					FROM
						(
						SELECT
							DISTINCT V1."GroupID",
							V1."CONFLICTID",
							V1."ShVTSTTime",
							V1."ShVTENTime",
							V1."BilledRateMinute",
							V1."G_CRDATEUNIQUE",
							TO_CHAR(V1."G_CRDATEUNIQUE", ''YYYY-MM-DD'') AS CRDATEUNIQUE,
							V1."PayerID" AS APID,
							V1."ServiceCode" AS "ServiceCode",
							V1."StatusFlag" AS "StatusFlag",
							V1."Billed" AS "Billed",
							CASE WHEN V1."VisitStartTime" IS NOT NULL THEN ''Confirmed'' ELSE ''Scheduled'' END AS "IsConfirmed",
							CASE
								WHEN V2."StatusFlag" IN(''R'', ''D'') THEN ''R''
								WHEN V2."StatusFlag" IN (''N'') THEN ''N''
								ELSE ''U''
							END AS "ConflictStatusFlag"
						FROM
							CONFLICTVISITMAPS AS V1
						INNER JOIN CONFLICTS AS V2 ON
							V2."CONFLICTID" = V1."CONFLICTID"
						WHERE
							V1."GroupID" IN (
							SELECT
								DISTINCT "GroupID"
							FROM
								CONFLICTVISITMAPS
							WHERE
								"PayerID" = ''${payerId}''
									AND "SameSchTimeFlag" = ''Y'' ) ) a
					LEFT JOIN (
						SELECT
							DISTINCT V1."GroupID",
							V1."CONFLICTID",
							V1."ShVTSTTime",
							V1."ShVTENTime",
							TO_CHAR(V1."G_CRDATEUNIQUE", ''YYYY-MM-DD'') AS CRDATEUNIQUE,
						FROM
							CONFLICTVISITMAPS AS V1
						INNER JOIN CONFLICTS AS V2 ON
							V2."CONFLICTID" = V1."CONFLICTID"
						WHERE
							V1."GroupID" IN (
							SELECT
								DISTINCT "GroupID"
							FROM
								CONFLICTVISITMAPS
							WHERE
								"PayerID" = ''${payerId}''
								) ) b ON
						a.CONFLICTID <> b.CONFLICTID
						AND a."GroupID" = b."GroupID"
						GROUP BY a.CRDATEUNIQUE, a."ServiceCode", a."StatusFlag", a."Billed", a."IsConfirmed"
				UNION ALL
					SELECT
						''${payerId}'' AS PAYERID,
						a."CRDATEUNIQUE" AS "CRDATEUNIQUE",
						''Exact Visit Time Match'' AS "CONTYPE",
						2 AS "CONTYPES",
						a."ServiceCode" AS "SERVICECODE",
						a."StatusFlag" AS "STATUSFLAG",
						a."Billed" AS "BILLED",
						a."IsConfirmed" AS "ISCONFIRMED",
						COUNT(DISTINCT a."GroupID") AS "CO_TO",
						SUM(CASE WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" ELSE 0 END) AS "CO_SP",
						SUM( CASE WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTSTTime" <= a."ShVTENTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTSTTime" <= b."ShVTENTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" < a."ShVTSTTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" < b."ShVTSTTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" ELSE 0 END ) AS "CO_OP",
						SUM( CASE WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTSTTime" <= a."ShVTENTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTSTTime" <= b."ShVTENTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" < a."ShVTSTTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" < b."ShVTSTTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" ELSE 0 END ) AS "CO_FP"
					FROM
						(
						SELECT
							DISTINCT V1."GroupID",
							V1."CONFLICTID",
							V1."ShVTSTTime",
							V1."ShVTENTime",
							V1."BilledRateMinute",
							V1."G_CRDATEUNIQUE",
							TO_CHAR(V1."G_CRDATEUNIQUE", ''YYYY-MM-DD'') AS CRDATEUNIQUE,
							V1."PayerID" AS APID,
							V1."ServiceCode" AS "ServiceCode",
							V1."StatusFlag" AS "StatusFlag",
							V1."Billed" AS "Billed",
							CASE WHEN V1."VisitStartTime" IS NOT NULL THEN ''Confirmed'' ELSE ''Scheduled'' END AS "IsConfirmed",
							CASE
								WHEN V2."StatusFlag" IN(''R'', ''D'') THEN ''R''
								WHEN V2."StatusFlag" IN (''N'') THEN ''N''
								ELSE ''U''
							END AS "ConflictStatusFlag"
						FROM
							CONFLICTVISITMAPS AS V1
						INNER JOIN CONFLICTS AS V2 ON
							V2."CONFLICTID" = V1."CONFLICTID"
						WHERE
							V1."GroupID" IN (
							SELECT
								DISTINCT "GroupID"
							FROM
								CONFLICTVISITMAPS
							WHERE
								"PayerID" = ''${payerId}''
									AND "SameVisitTimeFlag" = ''Y'' ) ) a
					LEFT JOIN (
						SELECT
							DISTINCT V1."GroupID",
							V1."CONFLICTID",
							V1."ShVTSTTime",
							V1."ShVTENTime",
							TO_CHAR(V1."G_CRDATEUNIQUE", ''YYYY-MM-DD'') AS CRDATEUNIQUE,
						FROM
							CONFLICTVISITMAPS AS V1
						INNER JOIN CONFLICTS AS V2 ON
							V2."CONFLICTID" = V1."CONFLICTID"
						WHERE
							V1."GroupID" IN (
							SELECT
								DISTINCT "GroupID"
							FROM
								CONFLICTVISITMAPS
							WHERE
								"PayerID" = ''${payerId}'' ) ) b ON
						a.CONFLICTID <> b.CONFLICTID
						AND a."GroupID" = b."GroupID"
						GROUP BY a.CRDATEUNIQUE, a."ServiceCode", a."StatusFlag", a."Billed", a."IsConfirmed"
				UNION ALL
					SELECT
						''${payerId}'' AS PAYERID,
						a."CRDATEUNIQUE" AS "CRDATEUNIQUE",
						''Exact Schedule and Visit Time Match'' AS "CONTYPE",
						3 AS "CONTYPES",
						a."ServiceCode" AS "SERVICECODE",
						a."StatusFlag" AS "STATUSFLAG",
						a."Billed" AS "BILLED",
						a."IsConfirmed" AS "ISCONFIRMED",
						COUNT(DISTINCT a."GroupID") AS "CO_TO",
						SUM(CASE WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" ELSE 0 END) AS "CO_SP",
						SUM( CASE WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTSTTime" <= a."ShVTENTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTSTTime" <= b."ShVTENTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" < a."ShVTSTTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" < b."ShVTSTTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" ELSE 0 END ) AS "CO_OP",
						SUM( CASE WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTSTTime" <= a."ShVTENTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTSTTime" <= b."ShVTENTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" < a."ShVTSTTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" < b."ShVTSTTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" ELSE 0 END ) AS "CO_FP"
					FROM
						(
						SELECT
							DISTINCT V1."GroupID",
							V1."CONFLICTID",
							V1."ShVTSTTime",
							V1."ShVTENTime",
							V1."BilledRateMinute",
							V1."G_CRDATEUNIQUE",
							TO_CHAR(V1."G_CRDATEUNIQUE", ''YYYY-MM-DD'') AS CRDATEUNIQUE,
							V1."PayerID" AS APID,
							V1."ServiceCode" AS "ServiceCode",
							V1."StatusFlag" AS "StatusFlag",
							V1."Billed" AS "Billed",
							CASE WHEN V1."VisitStartTime" IS NOT NULL THEN ''Confirmed'' ELSE ''Scheduled'' END AS "IsConfirmed",
							CASE
								WHEN V2."StatusFlag" IN(''R'', ''D'') THEN ''R''
								WHEN V2."StatusFlag" IN (''N'') THEN ''N''
								ELSE ''U''
							END AS "ConflictStatusFlag"
						FROM
							CONFLICTVISITMAPS AS V1
						INNER JOIN CONFLICTS AS V2 ON
							V2."CONFLICTID" = V1."CONFLICTID"
						WHERE
							V1."GroupID" IN (
							SELECT
								DISTINCT "GroupID"
							FROM
								CONFLICTVISITMAPS
							WHERE
								"PayerID" = ''${payerId}''
									AND "SameVisitTimeFlag" = ''Y'' ) ) a
					LEFT JOIN (
						SELECT
							DISTINCT V1."GroupID",
							V1."CONFLICTID",
							V1."ShVTSTTime",
							V1."ShVTENTime",
							TO_CHAR(V1."G_CRDATEUNIQUE", ''YYYY-MM-DD'') AS CRDATEUNIQUE,
						FROM
							CONFLICTVISITMAPS AS V1
						INNER JOIN CONFLICTS AS V2 ON
							V2."CONFLICTID" = V1."CONFLICTID"
						WHERE
							V1."GroupID" IN (
							SELECT
								DISTINCT "GroupID"
							FROM
								CONFLICTVISITMAPS
							WHERE
								"PayerID" = ''${payerId}'' ) ) b ON
						a.CONFLICTID <> b.CONFLICTID
						AND a."GroupID" = b."GroupID"
						GROUP BY a.CRDATEUNIQUE, a."ServiceCode", a."StatusFlag", a."Billed", a."IsConfirmed"
				UNION ALL
					SELECT
						''${payerId}'' AS PAYERID,
						a."CRDATEUNIQUE" AS "CRDATEUNIQUE",
						''Schedule time overlap'' AS "CONTYPE",
						4 AS "CONTYPES",
						a."ServiceCode" AS "SERVICECODE",
						a."StatusFlag" AS "STATUSFLAG",
						a."Billed" AS "BILLED",
						a."IsConfirmed" AS "ISCONFIRMED",
						COUNT(DISTINCT a."GroupID") AS "CO_TO",
						SUM(CASE WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" ELSE 0 END) AS "CO_SP",
						SUM( CASE WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTSTTime" <= a."ShVTENTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTSTTime" <= b."ShVTENTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" < a."ShVTSTTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" < b."ShVTSTTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" ELSE 0 END ) AS "CO_OP",
						SUM( CASE WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTSTTime" <= a."ShVTENTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTSTTime" <= b."ShVTENTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" < a."ShVTSTTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" < b."ShVTSTTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" ELSE 0 END ) AS "CO_FP"
					FROM
						(
						SELECT
							DISTINCT V1."GroupID",
							V1."CONFLICTID",
							V1."ShVTSTTime",
							V1."ShVTENTime",
							V1."BilledRateMinute",
							V1."G_CRDATEUNIQUE",
							TO_CHAR(V1."G_CRDATEUNIQUE", ''YYYY-MM-DD'') AS CRDATEUNIQUE,
							V1."PayerID" AS APID,
							V1."ServiceCode" AS "ServiceCode",
							V1."StatusFlag" AS "StatusFlag",
							V1."Billed" AS "Billed",
							CASE WHEN V1."VisitStartTime" IS NOT NULL THEN ''Confirmed'' ELSE ''Scheduled'' END AS "IsConfirmed",
							CASE
								WHEN V2."StatusFlag" IN(''R'', ''D'') THEN ''R''
								WHEN V2."StatusFlag" IN (''N'') THEN ''N''
								ELSE ''U''
							END AS "ConflictStatusFlag"
						FROM
							CONFLICTVISITMAPS AS V1
						INNER JOIN CONFLICTS AS V2 ON
							V2."CONFLICTID" = V1."CONFLICTID"
						WHERE
							V1."GroupID" IN (
							SELECT
								DISTINCT "GroupID"
							FROM
								CONFLICTVISITMAPS
							WHERE
								"PayerID" = ''${payerId}''
									AND "SchOverAnotherSchTimeFlag" = ''Y'' ) ) a
					LEFT JOIN (
						SELECT
							DISTINCT V1."GroupID",
							V1."CONFLICTID",
							V1."ShVTSTTime",
							V1."ShVTENTime",
							TO_CHAR(V1."G_CRDATEUNIQUE", ''YYYY-MM-DD'') AS CRDATEUNIQUE,
						FROM
							CONFLICTVISITMAPS AS V1
						INNER JOIN CONFLICTS AS V2 ON
							V2."CONFLICTID" = V1."CONFLICTID"
						WHERE
							V1."GroupID" IN (
							SELECT
								DISTINCT "GroupID"
							FROM
								CONFLICTVISITMAPS
							WHERE
								"PayerID" = ''${payerId}'' ) ) b ON
						a.CONFLICTID <> b.CONFLICTID
						AND a."GroupID" = b."GroupID"
						GROUP BY a.CRDATEUNIQUE, a."ServiceCode", a."StatusFlag", a."Billed", a."IsConfirmed"
				UNION ALL
					SELECT
						''${payerId}'' AS PAYERID,
						a."CRDATEUNIQUE" AS "CRDATEUNIQUE",
						''Visit Time Overlap'' AS "CONTYPE",
						5 AS "CONTYPES",
						a."ServiceCode" AS "SERVICECODE",
						a."StatusFlag" AS "STATUSFLAG",
						a."Billed" AS "BILLED",
						a."IsConfirmed" AS "ISCONFIRMED",
						COUNT(DISTINCT a."GroupID") AS "CO_TO",
						SUM(CASE WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" ELSE 0 END) AS "CO_SP",
						SUM( CASE WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTSTTime" <= a."ShVTENTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTSTTime" <= b."ShVTENTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" < a."ShVTSTTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" < b."ShVTSTTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" ELSE 0 END ) AS "CO_OP",
						SUM( CASE WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTSTTime" <= a."ShVTENTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTSTTime" <= b."ShVTENTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" < a."ShVTSTTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" < b."ShVTSTTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" ELSE 0 END ) AS "CO_FP"
					FROM
						(
						SELECT
							DISTINCT V1."GroupID",
							V1."CONFLICTID",
							V1."ShVTSTTime",
							V1."ShVTENTime",
							V1."BilledRateMinute",
							V1."G_CRDATEUNIQUE",
							TO_CHAR(V1."G_CRDATEUNIQUE", ''YYYY-MM-DD'') AS CRDATEUNIQUE,
							V1."PayerID" AS APID,
							V1."ServiceCode" AS "ServiceCode",
							V1."StatusFlag" AS "StatusFlag",
							V1."Billed" AS "Billed",
							CASE WHEN V1."VisitStartTime" IS NOT NULL THEN ''Confirmed'' ELSE ''Scheduled'' END AS "IsConfirmed",
							CASE
								WHEN V2."StatusFlag" IN(''R'', ''D'') THEN ''R''
								WHEN V2."StatusFlag" IN (''N'') THEN ''N''
								ELSE ''U''
							END AS "ConflictStatusFlag"
						FROM
							CONFLICTVISITMAPS AS V1
						INNER JOIN CONFLICTS AS V2 ON
							V2."CONFLICTID" = V1."CONFLICTID"
						WHERE
							V1."GroupID" IN (
							SELECT
								DISTINCT "GroupID"
							FROM
								CONFLICTVISITMAPS
							WHERE
								"PayerID" = ''${payerId}''
									AND "VisitTimeOverAnotherVisitTimeFlag" = ''Y'' ) ) a
					LEFT JOIN (
						SELECT
							DISTINCT V1."GroupID",
							V1."CONFLICTID",
							V1."ShVTSTTime",
							V1."ShVTENTime",
							TO_CHAR(V1."G_CRDATEUNIQUE", ''YYYY-MM-DD'') AS CRDATEUNIQUE,
						FROM
							CONFLICTVISITMAPS AS V1
						INNER JOIN CONFLICTS AS V2 ON
							V2."CONFLICTID" = V1."CONFLICTID"
						WHERE
							V1."GroupID" IN (
							SELECT
								DISTINCT "GroupID"
							FROM
								CONFLICTVISITMAPS
							WHERE
								"PayerID" = ''${payerId}'' ) ) b ON
						a.CONFLICTID <> b.CONFLICTID
						AND a."GroupID" = b."GroupID"
						GROUP BY a.CRDATEUNIQUE, a."ServiceCode", a."StatusFlag", a."Billed", a."IsConfirmed"
				UNION ALL
					SELECT
						''${payerId}'' AS PAYERID,
						a."CRDATEUNIQUE" AS "CRDATEUNIQUE",
						''Schedule and Visit time overlap'' AS "CONTYPE",
						6 AS "CONTYPES",
						a."ServiceCode" AS "SERVICECODE",
						a."StatusFlag" AS "STATUSFLAG",
						a."Billed" AS "BILLED",
						a."IsConfirmed" AS "ISCONFIRMED",
						COUNT(DISTINCT a."GroupID") AS "CO_TO",
						SUM(CASE WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" ELSE 0 END) AS "CO_SP",
						SUM( CASE WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTSTTime" <= a."ShVTENTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTSTTime" <= b."ShVTENTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" < a."ShVTSTTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" < b."ShVTSTTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" ELSE 0 END ) AS "CO_OP",
						SUM( CASE WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTSTTime" <= a."ShVTENTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTSTTime" <= b."ShVTENTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" < a."ShVTSTTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" < b."ShVTSTTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" ELSE 0 END ) AS "CO_FP"
					FROM
						(
						SELECT
							DISTINCT V1."GroupID",
							V1."CONFLICTID",
							V1."ShVTSTTime",
							V1."ShVTENTime",
							V1."BilledRateMinute",
							V1."G_CRDATEUNIQUE",
							TO_CHAR(V1."G_CRDATEUNIQUE", ''YYYY-MM-DD'') AS CRDATEUNIQUE,
							V1."PayerID" AS APID,
							V1."ServiceCode" AS "ServiceCode",
							V1."StatusFlag" AS "StatusFlag",
							V1."Billed" AS "Billed",
							CASE WHEN V1."VisitStartTime" IS NOT NULL THEN ''Confirmed'' ELSE ''Scheduled'' END AS "IsConfirmed",
							CASE
								WHEN V2."StatusFlag" IN(''R'', ''D'') THEN ''R''
								WHEN V2."StatusFlag" IN (''N'') THEN ''N''
								ELSE ''U''
							END AS "ConflictStatusFlag"
						FROM
							CONFLICTVISITMAPS AS V1
						INNER JOIN CONFLICTS AS V2 ON
							V2."CONFLICTID" = V1."CONFLICTID"
						WHERE
							V1."GroupID" IN (
							SELECT
								DISTINCT "GroupID"
							FROM
								CONFLICTVISITMAPS
							WHERE
								"PayerID" = ''${payerId}''
									AND "SchTimeOverVisitTimeFlag" = ''Y'' ) ) a
					LEFT JOIN (
						SELECT
							DISTINCT V1."GroupID",
							V1."CONFLICTID",
							V1."ShVTSTTime",
							V1."ShVTENTime",
							TO_CHAR(V1."G_CRDATEUNIQUE", ''YYYY-MM-DD'') AS CRDATEUNIQUE,
						FROM
							CONFLICTVISITMAPS AS V1
						INNER JOIN CONFLICTS AS V2 ON
							V2."CONFLICTID" = V1."CONFLICTID"
						WHERE
							V1."GroupID" IN (
							SELECT
								DISTINCT "GroupID"
							FROM
								CONFLICTVISITMAPS
							WHERE
								"PayerID" = ''${payerId}'' ) ) b ON
						a.CONFLICTID <> b.CONFLICTID
						AND a."GroupID" = b."GroupID"
						GROUP BY a.CRDATEUNIQUE, a."ServiceCode", a."StatusFlag", a."Billed", a."IsConfirmed"
				UNION ALL
					SELECT
						''${payerId}'' AS PAYERID,
						a."CRDATEUNIQUE" AS "CRDATEUNIQUE",
						''Time- Distance'' AS "CONTYPE",
						7 AS "CONTYPES",
						a."ServiceCode" AS "SERVICECODE",
						a."StatusFlag" AS "STATUSFLAG",
						a."Billed" AS "BILLED",
						a."IsConfirmed" AS "ISCONFIRMED",
						COUNT(DISTINCT a."GroupID") AS "CO_TO",
						SUM(CASE WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" ELSE 0 END) AS "CO_SP",
						SUM( CASE WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTSTTime" <= a."ShVTENTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTSTTime" <= b."ShVTENTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" < a."ShVTSTTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" < b."ShVTSTTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" ELSE 0 END ) AS "CO_OP",
						SUM( CASE WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTSTTime" <= a."ShVTENTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTSTTime" <= b."ShVTENTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" < a."ShVTSTTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" < b."ShVTSTTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" ELSE 0 END ) AS "CO_FP"
					FROM
						(
						SELECT
							DISTINCT V1."GroupID",
							V1."CONFLICTID",
							V1."ShVTSTTime",
							V1."ShVTENTime",
							V1."BilledRateMinute",
							V1."G_CRDATEUNIQUE",
							TO_CHAR(V1."G_CRDATEUNIQUE", ''YYYY-MM-DD'') AS CRDATEUNIQUE,
							V1."PayerID" AS APID,
							V1."ServiceCode" AS "ServiceCode",
							V1."StatusFlag" AS "StatusFlag",
							V1."Billed" AS "Billed",
							CASE WHEN V1."VisitStartTime" IS NOT NULL THEN ''Confirmed'' ELSE ''Scheduled'' END AS "IsConfirmed",
							CASE
								WHEN V2."StatusFlag" IN(''R'', ''D'') THEN ''R''
								WHEN V2."StatusFlag" IN (''N'') THEN ''N''
								ELSE ''U''
							END AS "ConflictStatusFlag"
						FROM
							CONFLICTVISITMAPS AS V1
						INNER JOIN CONFLICTS AS V2 ON
							V2."CONFLICTID" = V1."CONFLICTID"
						WHERE
							V1."GroupID" IN (
							SELECT
								DISTINCT "GroupID"
							FROM
								CONFLICTVISITMAPS
							WHERE
								"PayerID" = ''${payerId}''
									AND "DistanceFlag" = ''Y'' ) ) a
					LEFT JOIN (
						SELECT
							DISTINCT V1."GroupID",
							V1."CONFLICTID",
							V1."ShVTSTTime",
							V1."ShVTENTime",
							TO_CHAR(V1."G_CRDATEUNIQUE", ''YYYY-MM-DD'') AS CRDATEUNIQUE,
						FROM
							CONFLICTVISITMAPS AS V1
						INNER JOIN CONFLICTS AS V2 ON
							V2."CONFLICTID" = V1."CONFLICTID"
						WHERE
							V1."GroupID" IN (
							SELECT
								DISTINCT "GroupID"
							FROM
								CONFLICTVISITMAPS
							WHERE
								"PayerID" = ''${payerId}'' ) ) b ON
						a.CONFLICTID <> b.CONFLICTID
						AND a."GroupID" = b."GroupID"
						GROUP BY a.CRDATEUNIQUE, a."ServiceCode", a."StatusFlag", a."Billed", a."IsConfirmed"
				UNION ALL
					SELECT
						''${payerId}'' AS PAYERID,
						a."CRDATEUNIQUE" AS "CRDATEUNIQUE",
						''In-Service'' AS "CONTYPE",
						8 AS "CONTYPES",
						a."ServiceCode" AS "SERVICECODE",
						a."StatusFlag" AS "STATUSFLAG",
						a."Billed" AS "BILLED",
						a."IsConfirmed" AS "ISCONFIRMED",
						COUNT(DISTINCT a."GroupID") AS "CO_TO",
						SUM(CASE WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" ELSE 0 END) AS "CO_SP",
						SUM( CASE WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTSTTime" <= a."ShVTENTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTSTTime" <= b."ShVTENTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" < a."ShVTSTTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" < b."ShVTSTTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" ELSE 0 END ) AS "CO_OP",
						SUM( CASE WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTSTTime" <= a."ShVTENTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTSTTime" <= b."ShVTENTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" < a."ShVTSTTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" < b."ShVTSTTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" ELSE 0 END ) AS "CO_FP"
					FROM
						(
						SELECT
							DISTINCT V1."GroupID",
							V1."CONFLICTID",
							V1."ShVTSTTime",
							V1."ShVTENTime",
							V1."BilledRateMinute",
							V1."G_CRDATEUNIQUE",
							TO_CHAR(V1."G_CRDATEUNIQUE", ''YYYY-MM-DD'') AS CRDATEUNIQUE,
							V1."PayerID" AS APID,
							V1."ServiceCode" AS "ServiceCode",
							V1."StatusFlag" AS "StatusFlag",
							V1."Billed" AS "Billed",
							CASE WHEN V1."VisitStartTime" IS NOT NULL THEN ''Confirmed'' ELSE ''Scheduled'' END AS "IsConfirmed",
							CASE
								WHEN V2."StatusFlag" IN(''R'', ''D'') THEN ''R''
								WHEN V2."StatusFlag" IN (''N'') THEN ''N''
								ELSE ''U''
							END AS "ConflictStatusFlag"
						FROM
							CONFLICTVISITMAPS AS V1
						INNER JOIN CONFLICTS AS V2 ON
							V2."CONFLICTID" = V1."CONFLICTID"
						WHERE
							V1."GroupID" IN (
							SELECT
								DISTINCT "GroupID"
							FROM
								CONFLICTVISITMAPS
							WHERE
								"PayerID" = ''${payerId}''
									AND "InServiceFlag" = ''Y'' ) ) a
					LEFT JOIN (
						SELECT
							DISTINCT V1."GroupID",
							V1."CONFLICTID",
							V1."ShVTSTTime",
							V1."ShVTENTime",
							TO_CHAR(V1."G_CRDATEUNIQUE", ''YYYY-MM-DD'') AS CRDATEUNIQUE,
						FROM
							CONFLICTVISITMAPS AS V1
						INNER JOIN CONFLICTS AS V2 ON
							V2."CONFLICTID" = V1."CONFLICTID"
						WHERE
							V1."GroupID" IN (
							SELECT
								DISTINCT "GroupID"
							FROM
								CONFLICTVISITMAPS
							WHERE
								"PayerID" = ''${payerId}'' ) ) b ON
						a.CONFLICTID <> b.CONFLICTID
						AND a."GroupID" = b."GroupID"
						GROUP BY a.CRDATEUNIQUE, a."ServiceCode", a."StatusFlag", a."Billed", a."IsConfirmed"
				UNION ALL
					SELECT
						''${payerId}'' AS PAYERID,
						a."CRDATEUNIQUE" AS "CRDATEUNIQUE",
						''PTO'' AS "CONTYPE",
						9 AS "CONTYPES",
						a."ServiceCode" AS "SERVICECODE",
						a."StatusFlag" AS "STATUSFLAG",
						a."Billed" AS "BILLED",
						a."IsConfirmed" AS "ISCONFIRMED",
						COUNT(DISTINCT a."GroupID") AS "CO_TO",
						SUM(CASE WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" ELSE 0 END) AS "CO_SP",
						SUM( CASE WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTSTTime" <= a."ShVTENTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTSTTime" <= b."ShVTENTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" < a."ShVTSTTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" < b."ShVTSTTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" ELSE 0 END ) AS "CO_OP",
						SUM( CASE WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTSTTime" <= a."ShVTENTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTSTTime" <= b."ShVTENTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" < a."ShVTSTTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" < b."ShVTSTTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" ELSE 0 END ) AS "CO_FP"
					FROM
						(
						SELECT
							DISTINCT V1."GroupID",
							V1."CONFLICTID",
							V1."ShVTSTTime",
							V1."ShVTENTime",
							V1."BilledRateMinute",
							V1."G_CRDATEUNIQUE",
							TO_CHAR(V1."G_CRDATEUNIQUE", ''YYYY-MM-DD'') AS CRDATEUNIQUE,
							V1."PayerID" AS APID,
							V1."ServiceCode" AS "ServiceCode",
							V1."StatusFlag" AS "StatusFlag",
							V1."Billed" AS "Billed",
							CASE WHEN V1."VisitStartTime" IS NOT NULL THEN ''Confirmed'' ELSE ''Scheduled'' END AS "IsConfirmed",
							CASE
								WHEN V2."StatusFlag" IN(''R'', ''D'') THEN ''R''
								WHEN V2."StatusFlag" IN (''N'') THEN ''N''
								ELSE ''U''
							END AS "ConflictStatusFlag"
						FROM
							CONFLICTVISITMAPS AS V1
						INNER JOIN CONFLICTS AS V2 ON
							V2."CONFLICTID" = V1."CONFLICTID"
						WHERE
							V1."GroupID" IN (
							SELECT
								DISTINCT "GroupID"
							FROM
								CONFLICTVISITMAPS
							WHERE
								"PayerID" = ''${payerId}''
									AND "PTOFlag" = ''Y'' ) ) a
					LEFT JOIN (
						SELECT
							DISTINCT V1."GroupID",
							V1."CONFLICTID",
							V1."ShVTSTTime",
							V1."ShVTENTime",
							TO_CHAR(V1."G_CRDATEUNIQUE", ''YYYY-MM-DD'') AS CRDATEUNIQUE,
						FROM
							CONFLICTVISITMAPS AS V1
						INNER JOIN CONFLICTS AS V2 ON
							V2."CONFLICTID" = V1."CONFLICTID"
						WHERE
							V1."GroupID" IN (
							SELECT
								DISTINCT "GroupID"
							FROM
								CONFLICTVISITMAPS
							WHERE
								"PayerID" = ''${payerId}'' ) ) b ON
						a.CONFLICTID <> b.CONFLICTID
						AND a."GroupID" = b."GroupID"
						GROUP BY a.CRDATEUNIQUE, a."ServiceCode", a."StatusFlag", a."Billed", a."IsConfirmed"
					)`;
	
			var dashboard_top1Stmt = snowflake.createStatement({
				sqlText: insercontypes
			});
	
			dashboard_top1Stmt.execute();
			//-------------------------END PAYER CON TYPE---------------------
	
	    }
	
	    return `Inserted rows successfully.`;
	
	} catch (err) {
	    throw "ERROR: " + err.message;
	}
';