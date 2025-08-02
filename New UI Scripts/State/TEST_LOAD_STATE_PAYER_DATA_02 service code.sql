CREATE OR REPLACE PROCEDURE CONFLICTREPORT_SANDBOX.PUBLIC.TEST_LOAD_STATE_PAYER_DATA_02()
RETURNS VARCHAR
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS '
	try {
		// Step 1: TRUNCATE the table
		var truncate1Stmt = snowflake.createStatement({
			sqlText: `TRUNCATE TABLE CONFLICTREPORT_SANDBOX.PUBLIC.TEST_STATE_PAYER_02`
		});
		truncate1Stmt.execute();

		// Step 2: Fetch payer IDs
		var payerStmt = snowflake.createStatement({
			sqlText: `
				SELECT DISTINCT V1."PayerID" AS APID
				FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
				INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2 
					ON V2."CONFLICTID" = V1."CONFLICTID"
				INNER JOIN ANALYTICS_SANDBOX.BI.DIMPAYER AS P 
					ON P."Payer Id" = V1."PayerID"
				WHERE P."Is Active" = TRUE 
					AND P."Is Demo" = FALSE
			`
		});

		var payerResult = payerStmt.execute();

		// Step 3: Loop through result set
		while (payerResult.next()) {
			var payerId = payerResult.getColumnValue(1);
			
			//-------------------------PAYER CON TYPE---------------------
			var insercontypes = `
				INSERT INTO CONFLICTREPORT_SANDBOX.PUBLIC.TEST_STATE_PAYER_02(
					PAYERSTATE, PAYERID, PROVIDERID, CRDATEUNIQUE, CONTYPE, CONTYPES, STATUSFLAG, 
					COSTTYPE, VISITTYPE, COUNTY, SERVICECODE, CO_TO, CO_SP, CO_OP, CO_FP
				)
				SELECT *
				FROM (
					-- Time Overlap Query (Consolidated from ConflictTypeF 1-6)
					SELECT
						a.PAYERSTATE AS PAYERSTATE,
						''${payerId}'' AS PAYERID,
						a."ProviderID" AS PROVIDERID,
						a."CRDATEUNIQUE" AS "CRDATEUNIQUE",
						''Time Overlap'' AS "ConflictType",
						''100'' AS "ConflictTypeF",
						a."StatusFlag" AS "STATUSFLAG",
						CASE 
							WHEN a."Billed" = ''yes'' THEN ''Recovery'' 
							ELSE ''Avoidance'' 
						END AS "COSTTYPE",
						CASE 
							WHEN a."VisitStartTime" IS NULL THEN ''Scheduled'' 
							WHEN a."VisitStartTime" IS NOT NULL AND a."Billed" != ''yes'' THEN ''Confirmed'' 
							WHEN a."VisitStartTime" IS NOT NULL AND a."Billed" = ''yes'' THEN ''Billed'' 
						END AS "VISITTYPE",
						a.COUNTY AS COUNTY,
						a.SERVICECODE AS SERVICECODE,
						COUNT(DISTINCT a."CONFLICTID") AS "Total",
						SUM(
							CASE 
								WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."BILLABLEMINUTESFULLSHIFT" IS NOT NULL 
									THEN a."BILLABLEMINUTESFULLSHIFT" * a."BilledRateMinute" 
								WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 
									THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" 
								ELSE 0 
							END
						) AS "ShiftPrice",
						SUM(
							CASE 
								WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."BILLABLEMINUTESOVERLAP" IS NOT NULL 
									THEN a."BILLABLEMINUTESOVERLAP" * a."BilledRateMinute" 
								WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTSTTime" <= a."ShVTENTime" AND b."ShVTENTime" > a."ShVTENTime" 
									THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" 
								WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTSTTime" <= b."ShVTENTime" AND a."ShVTENTime" > b."ShVTENTime" 
									THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" 
								WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTENTime" <= a."ShVTENTime" 
									THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" 
								WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTENTime" <= b."ShVTENTime" 
									THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" 
								WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" < a."ShVTSTTime" AND b."ShVTENTime" > a."ShVTENTime" 
									THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" 
								WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" < b."ShVTSTTime" AND b."ShVTENTime" > b."ShVTENTime" 
									THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" 
								ELSE 0 
							END
						) AS "OverlapPrice",
						SUM(
							CASE 
								WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."BILLABLEMINUTESOVERLAP" IS NOT NULL 
									THEN a."BILLABLEMINUTESOVERLAP" * a."BilledRateMinute" 
								WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTSTTime" <= a."ShVTENTime" AND b."ShVTENTime" > a."ShVTENTime" 
									THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" 
								WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTSTTime" <= b."ShVTENTime" AND a."ShVTENTime" > b."ShVTENTime" 
									THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" 
								WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTENTime" <= a."ShVTENTime" 
									THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" 
								WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTENTime" <= b."ShVTENTime" 
									THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" 
								WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" < a."ShVTSTTime" AND b."ShVTENTime" > a."ShVTENTime" 
									THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" 
								WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" < b."ShVTSTTime" AND a."ShVTENTime" > b."ShVTENTime" 
									THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" 
								ELSE 0 
							END
						) AS "FinalPrice"
											FROM (
							SELECT DISTINCT 
								V1."GroupID",
								V1."CONFLICTID",
								V1."ShVTSTTime",
								V1."ShVTENTime",
								V1."BilledRateMinute",
								V1."G_CRDATEUNIQUE",
								V1."BILLABLEMINUTESFULLSHIFT",
								V1."BILLABLEMINUTESOVERLAP",
								TO_CHAR(V1."G_CRDATEUNIQUE", ''YYYY-MM-DD'') AS CRDATEUNIQUE,
								V1."PayerID" AS APID,
								V1."ProviderID",
								V1."PayerState" AS PAYERSTATE,
								COALESCE(V1."P_PCounty", V1."PA_PCounty") AS COUNTY,
								V1."ServiceCode" AS SERVICECODE,
								CASE
									WHEN V2."StatusFlag" IN(''R'', ''D'') THEN ''R''
									WHEN V2."StatusFlag" IN (''N'') THEN ''N''
									ELSE ''U''
								END AS "StatusFlag",
								V1."Billed",
								V1."VisitStartTime"
							FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
							INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2 
								ON V2."CONFLICTID" = V1."CONFLICTID"
							WHERE V1."GroupID" IN (
								SELECT DISTINCT "GroupID"
								FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS
								WHERE "PayerID" = ''${payerId}''
									AND (
										"SameSchTimeFlag" = ''Y'' OR 
										"SameVisitTimeFlag" = ''Y'' OR 
										"SchAndVisitTimeSameFlag" = ''Y'' OR 
										"SchOverAnotherSchTimeFlag" = ''Y'' OR 
										"VisitTimeOverAnotherVisitTimeFlag" = ''Y'' OR 
										"SchTimeOverVisitTimeFlag" = ''Y''
									)
							)
							AND NOT (V1."PTOFlag" = ''Y'' 
							AND V1."SameSchTimeFlag" = ''N'' 
							AND V1."SameVisitTimeFlag" = ''N'' 
							AND V1."SchAndVisitTimeSameFlag" = ''N'' 
							AND V1."SchOverAnotherSchTimeFlag" = ''N'' 
							AND V1."VisitTimeOverAnotherVisitTimeFlag" = ''N'' 
							AND V1."SchTimeOverVisitTimeFlag" = ''N'' 
							AND V1."DistanceFlag" = ''N'' 
							AND V1."InServiceFlag" = ''N'')
						) a
					LEFT JOIN (
						SELECT DISTINCT 
							V1."GroupID",
							V1."CONFLICTID",
							V1."ShVTSTTime",
							V1."ShVTENTime",
							TO_CHAR(V1."G_CRDATEUNIQUE", ''YYYY-MM-DD'') AS CRDATEUNIQUE
						FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
						INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2 
							ON V2."CONFLICTID" = V1."CONFLICTID"
						WHERE V1."GroupID" IN (
							SELECT DISTINCT "GroupID"
							FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS
							WHERE "PayerID" = ''${payerId}''
						)
					) b ON a.CONFLICTID <> b.CONFLICTID AND a."GroupID" = b."GroupID"
					GROUP BY 
						a.PAYERSTATE,
						a."ProviderID",
						a.CRDATEUNIQUE, 
						a."StatusFlag", 
						CASE WHEN a."Billed" = ''yes'' THEN ''Recovery'' ELSE ''Avoidance'' END, 
						CASE 
							WHEN a."VisitStartTime" IS NULL THEN ''Scheduled'' 
							WHEN a."VisitStartTime" IS NOT NULL AND a."Billed" != ''yes'' THEN ''Confirmed'' 
							WHEN a."VisitStartTime" IS NOT NULL AND a."Billed" = ''yes'' THEN ''Billed'' 
						END,
						a.COUNTY,
						a.SERVICECODE

					UNION ALL

					-- Time-Distance Query (ConflictTypeF 7)
					SELECT
						a.PAYERSTATE AS PAYERSTATE,
						''${payerId}'' AS PAYERID,
						a."ProviderID" AS PROVIDERID,
						a."CRDATEUNIQUE" AS "CRDATEUNIQUE",
						''Time Distance'' AS "ConflictType",
						''7'' AS "ConflictTypeF",
						a."StatusFlag" AS "STATUSFLAG",
						CASE 
							WHEN a."Billed" = ''yes'' THEN ''Recovery'' 
							ELSE ''Avoidance'' 
						END AS "COSTTYPE",
						CASE 
							WHEN a."VisitStartTime" IS NULL THEN ''Scheduled'' 
							WHEN a."VisitStartTime" IS NOT NULL AND a."Billed" != ''yes'' THEN ''Confirmed'' 
							WHEN a."VisitStartTime" IS NOT NULL AND a."Billed" = ''yes'' THEN ''Billed'' 
						END AS "VISITTYPE",
						a.COUNTY AS COUNTY,
						a.SERVICECODE AS SERVICECODE,
						COUNT(DISTINCT a."CONFLICTID") AS "Total",
						SUM(
							CASE 
								WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."BILLABLEMINUTESFULLSHIFT" IS NOT NULL 
									THEN a."BILLABLEMINUTESFULLSHIFT" * a."BilledRateMinute" 
								WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 
									THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" 
								ELSE 0 
							END
						) AS "ShiftPrice",
						SUM(
							CASE 
								WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."BILLABLEMINUTESOVERLAP" IS NOT NULL 
									THEN a."BILLABLEMINUTESOVERLAP" * a."BilledRateMinute" 
								WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTSTTime" <= a."ShVTENTime" AND b."ShVTENTime" > a."ShVTENTime" 
									THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" 
								WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTSTTime" <= b."ShVTENTime" AND a."ShVTENTime" > b."ShVTENTime" 
									THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" 
								WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTENTime" <= a."ShVTENTime" 
									THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" 
								WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTENTime" <= b."ShVTENTime" 
									THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" 
								WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" < a."ShVTSTTime" AND b."ShVTENTime" > a."ShVTENTime" 
									THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" 
								WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" < b."ShVTSTTime" AND a."ShVTENTime" > b."ShVTENTime" 
									THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" 
								ELSE 0 
							END
						) AS "OverlapPrice",
						SUM(
							CASE 
								WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."BILLABLEMINUTESOVERLAP" IS NOT NULL 
									THEN a."BILLABLEMINUTESOVERLAP" * a."BilledRateMinute" 
								WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTSTTime" <= a."ShVTENTime" AND b."ShVTENTime" > a."ShVTENTime" 
									THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" 
								WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTSTTime" <= b."ShVTENTime" AND a."ShVTENTime" > b."ShVTENTime" 
									THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" 
								WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTENTime" <= a."ShVTENTime" 
									THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" 
								WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTENTime" <= b."ShVTENTime" 
									THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" 
								WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" < a."ShVTSTTime" AND b."ShVTENTime" > a."ShVTENTime" 
									THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" 
								WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" < b."ShVTSTTime" AND a."ShVTENTime" > b."ShVTENTime" 
									THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" 
								ELSE 0 
							END
						) AS "FinalPrice"
					FROM (
						SELECT DISTINCT 
							V1."GroupID",
							V1."CONFLICTID",
							V1."ShVTSTTime",
							V1."ShVTENTime",
							V1."BilledRateMinute",
							V1."G_CRDATEUNIQUE",
							TO_CHAR(V1."G_CRDATEUNIQUE", ''YYYY-MM-DD'') AS CRDATEUNIQUE,
							V1."PayerID" AS APID,
							V1."ProviderID",
							V1."PayerState" AS PAYERSTATE,
							COALESCE(V1."P_PCounty", V1."PA_PCounty") AS COUNTY,
							V1."ServiceCode" AS SERVICECODE,
							V1."BILLABLEMINUTESFULLSHIFT",
							V1."BILLABLEMINUTESOVERLAP",
							CASE
								WHEN V2."StatusFlag" IN(''R'', ''D'') THEN ''R''
								WHEN V2."StatusFlag" IN (''N'') THEN ''N''
								ELSE ''U''
							END AS "StatusFlag",
							V1."Billed",
							V1."VisitStartTime"
						FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
						INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2 
							ON V2."CONFLICTID" = V1."CONFLICTID"
						WHERE V1."GroupID" IN (
							SELECT DISTINCT "GroupID"
							FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS
							WHERE "PayerID" = ''${payerId}'' AND "DistanceFlag" = ''Y''
						)
						AND NOT (V1."PTOFlag" = ''Y'' 
						AND V1."SameSchTimeFlag" = ''N'' 
						AND V1."SameVisitTimeFlag" = ''N'' 
						AND V1."SchAndVisitTimeSameFlag" = ''N'' 
						AND V1."SchOverAnotherSchTimeFlag" = ''N'' 
						AND V1."VisitTimeOverAnotherVisitTimeFlag" = ''N'' 
						AND V1."SchTimeOverVisitTimeFlag" = ''N'' 
						AND V1."DistanceFlag" = ''N'' 
						AND V1."InServiceFlag" = ''N'')
					) a
					LEFT JOIN (
						SELECT DISTINCT 
							V1."GroupID",
							V1."CONFLICTID",
							V1."ShVTSTTime",
							V1."ShVTENTime",
							TO_CHAR(V1."G_CRDATEUNIQUE", ''YYYY-MM-DD'') AS CRDATEUNIQUE
						FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
						INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2 
							ON V2."CONFLICTID" = V1."CONFLICTID"
						WHERE V1."GroupID" IN (
							SELECT DISTINCT "GroupID"
							FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS
							WHERE "PayerID" = ''${payerId}''
						)
					) b ON a.CONFLICTID <> b.CONFLICTID AND a."GroupID" = b."GroupID"
					GROUP BY 
						a.PAYERSTATE,
						a."ProviderID",
						a.CRDATEUNIQUE, 
						a."StatusFlag", 
						CASE WHEN a."Billed" = ''yes'' THEN ''Recovery'' ELSE ''Avoidance'' END, 
						CASE 
							WHEN a."VisitStartTime" IS NULL THEN ''Scheduled'' 
							WHEN a."VisitStartTime" IS NOT NULL AND a."Billed" != ''yes'' THEN ''Confirmed'' 
							WHEN a."VisitStartTime" IS NOT NULL AND a."Billed" = ''yes'' THEN ''Billed'' 
						END,
						a.COUNTY,
						a.SERVICECODE

					UNION ALL

					-- In-Service Query (ConflictTypeF 8)
					SELECT
						a.PAYERSTATE AS PAYERSTATE,
						''${payerId}'' AS PAYERID,
						a."ProviderID" AS PROVIDERID,
						a."CRDATEUNIQUE" AS "CRDATEUNIQUE",
						''In-Service'' AS "ConflictType",
						''8'' AS "ConflictTypeF",
						a."StatusFlag" AS "STATUSFLAG",
						CASE 
							WHEN a."Billed" = ''yes'' THEN ''Recovery'' 
							ELSE ''Avoidance'' 
						END AS "COSTTYPE",
						CASE 
							WHEN a."VisitStartTime" IS NULL THEN ''Scheduled'' 
							WHEN a."VisitStartTime" IS NOT NULL AND a."Billed" != ''yes'' THEN ''Confirmed'' 
							WHEN a."VisitStartTime" IS NOT NULL AND a."Billed" = ''yes'' THEN ''Billed'' 
						END AS "VISITTYPE",
						a.COUNTY AS COUNTY,
						a.SERVICECODE AS SERVICECODE,
						COUNT(DISTINCT a."CONFLICTID") AS "Total",
						SUM(
							CASE 
								WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."BILLABLEMINUTESFULLSHIFT" IS NOT NULL 
									THEN a."BILLABLEMINUTESFULLSHIFT" * a."BilledRateMinute" 
								WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 
									THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" 
								ELSE 0 
							END
						) AS "ShiftPrice",
						SUM(
							CASE 
								WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."BILLABLEMINUTESOVERLAP" IS NOT NULL 
									THEN a."BILLABLEMINUTESOVERLAP" * a."BilledRateMinute" 
								WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTSTTime" <= a."ShVTENTime" AND b."ShVTENTime" > a."ShVTENTime" 
									THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" 
								WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTSTTime" <= b."ShVTENTime" AND a."ShVTENTime" > b."ShVTENTime" 
									THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" 
								WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTENTime" <= a."ShVTENTime" 
									THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" 
								WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTENTime" <= b."ShVTENTime" 
									THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" 
								WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" < a."ShVTSTTime" AND b."ShVTENTime" > a."ShVTENTime" 
									THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" 
								WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" < b."ShVTSTTime" AND a."ShVTENTime" > b."ShVTENTime" 
									THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" 
								ELSE 0 
							END
						) AS "OverlapPrice",
						SUM(
							CASE 
								WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."BILLABLEMINUTESOVERLAP" IS NOT NULL 
									THEN a."BILLABLEMINUTESOVERLAP" * a."BilledRateMinute" 
								WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTSTTime" <= a."ShVTENTime" AND b."ShVTENTime" > a."ShVTENTime" 
									THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" 
								WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTSTTime" <= b."ShVTENTime" AND a."ShVTENTime" > b."ShVTENTime" 
									THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" 
								WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTENTime" <= a."ShVTENTime" 
									THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" 
								WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTENTime" <= b."ShVTENTime" 
									THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" 
								WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" < a."ShVTSTTime" AND b."ShVTENTime" > a."ShVTENTime" 
									THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" 
								WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" < b."ShVTSTTime" AND a."ShVTENTime" > b."ShVTENTime" 
									THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" 
								ELSE 0 
							END
						) AS "FinalPrice"
					FROM (
						SELECT DISTINCT 
							V1."GroupID",
							V1."CONFLICTID",
							V1."ShVTSTTime",
							V1."ShVTENTime",
							V1."BilledRateMinute",
							V1."G_CRDATEUNIQUE",
							V1."BILLABLEMINUTESFULLSHIFT",
							V1."BILLABLEMINUTESOVERLAP",
							TO_CHAR(V1."G_CRDATEUNIQUE", ''YYYY-MM-DD'') AS CRDATEUNIQUE,
							V1."PayerID" AS APID,
							V1."ProviderID",
							V1."PayerState" AS PAYERSTATE,
							COALESCE(V1."P_PCounty", V1."PA_PCounty") AS COUNTY,
							V1."ServiceCode" AS SERVICECODE,
							CASE
								WHEN V2."StatusFlag" IN(''R'', ''D'') THEN ''R''
								WHEN V2."StatusFlag" IN (''N'') THEN ''N''
								ELSE ''U''
							END AS "StatusFlag",
							V1."Billed",
							V1."VisitStartTime"
						FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
						INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2 
							ON V2."CONFLICTID" = V1."CONFLICTID"
						WHERE V1."GroupID" IN (
							SELECT DISTINCT "GroupID"
							FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS
							WHERE "PayerID" = ''${payerId}'' AND "InServiceFlag" = ''Y''
						)
						AND NOT (V1."PTOFlag" = ''Y'' 
						AND V1."SameSchTimeFlag" = ''N'' 
						AND V1."SameVisitTimeFlag" = ''N'' 
						AND V1."SchAndVisitTimeSameFlag" = ''N'' 
						AND V1."SchOverAnotherSchTimeFlag" = ''N'' 
						AND V1."VisitTimeOverAnotherVisitTimeFlag" = ''N'' 
						AND V1."SchTimeOverVisitTimeFlag" = ''N'' 
						AND V1."DistanceFlag" = ''N'' 
						AND V1."InServiceFlag" = ''N'')
					) a
					LEFT JOIN (
						SELECT DISTINCT 
							V1."GroupID",
							V1."CONFLICTID",
							V1."ShVTSTTime",
							V1."ShVTENTime",
							TO_CHAR(V1."G_CRDATEUNIQUE", ''YYYY-MM-DD'') AS CRDATEUNIQUE
						FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
						INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2 
							ON V2."CONFLICTID" = V1."CONFLICTID"
						WHERE V1."GroupID" IN (
							SELECT DISTINCT "GroupID"
							FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS
							WHERE "PayerID" = ''${payerId}''
						)
					) b ON a.CONFLICTID <> b.CONFLICTID AND a."GroupID" = b."GroupID"
					GROUP BY 
						a.PAYERSTATE,
						a.CRDATEUNIQUE,
						a."ProviderID",
						a."StatusFlag", 
						CASE WHEN a."Billed" = ''yes'' THEN ''Recovery'' ELSE ''Avoidance'' END, 
						CASE 
							WHEN a."VisitStartTime" IS NULL THEN ''Scheduled'' 
							WHEN a."VisitStartTime" IS NOT NULL AND a."Billed" != ''yes'' THEN ''Confirmed'' 
							WHEN a."VisitStartTime" IS NOT NULL AND a."Billed" = ''yes'' THEN ''Billed'' 
						END,
						a.COUNTY,
						a.SERVICECODE
				)
			`;

			var dashboard_top1Stmt = snowflake.createStatement({
				sqlText: insercontypes
			});

			dashboard_top1Stmt.execute();
			//-------------------------END PAYER CON TYPE---------------------
		}

		return `Inserted rows successfully.`;

	} catch (err) {
		throw err;
	}
';