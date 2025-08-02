CREATE OR REPLACE PROCEDURE CONFLICTREPORT_SANDBOX.PUBLIC.LOAD_PAYER_DASHBOARD_DATA_NEW()
RETURNS VARCHAR
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS '
    try {
        // Step 1: Truncate the target table
        var truncate1Stmt = snowflake.createStatement({
            sqlText: `TRUNCATE TABLE CONFLICTREPORT_SANDBOX.PUBLIC.PAYER_DASHBOARD_CON_TYP_NEW`
        });
        truncate1Stmt.execute();

        // Step 2: Fetch payer IDs
        var payerStmt = snowflake.createStatement({
            sqlText: `
                SELECT DISTINCT a.APID 
                FROM ANALYTICS_SANDBOX.BI.DIMPAYER AS P
                JOIN (
                    SELECT DISTINCT 
                        V1."GroupID",
                        V1."CONFLICTID",
                        V1."PayerID" AS APID
                    FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
                    INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2 
                        ON V2."CONFLICTID" = V1."CONFLICTID"
                    WHERE V1."GroupID" IN (
                        SELECT DISTINCT "GroupID"
                        FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS
                    )
                ) a
                LEFT JOIN (
                    SELECT DISTINCT 
                        V1."GroupID",
                        V1."CONFLICTID"
                    FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
                    INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2 
                        ON V2."CONFLICTID" = V1."CONFLICTID"
                    WHERE V1."GroupID" IN (
                        SELECT DISTINCT "GroupID"
                        FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS
                    )
                ) b ON a.CONFLICTID <> b.CONFLICTID
                    AND a."GroupID" = b."GroupID"
                WHERE P."Is Active" = TRUE 
                    AND P."Is Demo" = FALSE 
                    AND P."Payer Id" = a.APID
            `
        });
	
        var payerResult = payerStmt.execute();

        // Step 3: Loop through result set
        while (payerResult.next()) {
            var payerId = payerResult.getColumnValue(1);
            
            //-------------------------PAYER CON TYPE---------------------
            
            var insercontypes = `
                INSERT INTO CONFLICTREPORT_SANDBOX.PUBLIC.PAYER_DASHBOARD_CON_TYP_NEW 
                    (PAYERID, CRDATEUNIQUE, CONTYPE, CONTYPES, CO_TO, CO_SP, CO_OP, CO_FP, COSTTYPE, VISITTYPE, STATUSFLAG)
                SELECT 
                    PAYERID, 
                    "CRDATEUNIQUE", 
                    "ConflictType" AS CONTYPE, 
                    "ConflictTypeF" AS CONTYPES, 
                    SUM("Total") AS CO_TO,
                    SUM("ShiftPrice") AS CO_SP, 
                    SUM("OverlapPrice") AS CO_OP,
                    SUM("FinalPrice") AS CO_FP,
                    "CostType" AS COSTTYPE, 
                    "VisitType" AS VISITTYPE, 
                    "StatusFlag" AS STATUSFLAG
                FROM (
                    SELECT
                        ''${payerId}'' AS PAYERID,
                        a."CRDATEUNIQUE" AS "CRDATEUNIQUE",
                        ''Exact Schedule Time Match'' AS "ConflictType",
                        ''1'' AS "ConflictTypeF",
                        COUNT(DISTINCT a."GroupID") AS "Total",
                        SUM(CASE 
                            WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 
                            THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" 
                            ELSE 0 
                        END) AS "ShiftPrice",
                        SUM(CASE 
                            WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 
                                AND b."ShVTSTTime" >= a."ShVTSTTime" 
                                AND b."ShVTSTTime" <= a."ShVTENTime" 
                                AND b."ShVTENTime" > a."ShVTENTime" 
                            THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" 
                            WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 
                                AND a."ShVTSTTime" >= b."ShVTSTTime" 
                                AND a."ShVTSTTime" <= b."ShVTENTime" 
                                AND a."ShVTENTime" > b."ShVTENTime" 
                            THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" 
                            WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 
                                AND b."ShVTSTTime" >= a."ShVTSTTime" 
                                AND b."ShVTENTime" <= a."ShVTENTime" 
                            THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" 
                            WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 
                                AND a."ShVTSTTime" >= b."ShVTSTTime" 
                                AND a."ShVTENTime" <= b."ShVTENTime" 
                            THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" 
                            WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 
                                AND b."ShVTSTTime" < a."ShVTSTTime" 
                                AND b."ShVTENTime" > a."ShVTENTime" 
                            THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" 
                            WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 
                                AND a."ShVTSTTime" < b."ShVTSTTime" 
                                AND a."ShVTENTime" > b."ShVTENTime" 
                            THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" 
                            ELSE 0 
                        END) AS "OverlapPrice",
                        SUM(CASE 
                            WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 
                                AND b."ShVTSTTime" >= a."ShVTSTTime" 
                                AND b."ShVTSTTime" <= a."ShVTENTime" 
                                AND b."ShVTENTime" > a."ShVTENTime" 
                            THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" 
                            WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 
                                AND a."ShVTSTTime" >= b."ShVTSTTime" 
                                AND a."ShVTSTTime" <= b."ShVTENTime" 
                                AND a."ShVTENTime" > b."ShVTENTime" 
                            THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" 
                            WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 
                                AND b."ShVTSTTime" >= a."ShVTSTTime" 
                                AND b."ShVTENTime" <= a."ShVTENTime" 
                            THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" 
                            WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 
                                AND a."ShVTSTTime" >= b."ShVTSTTime" 
                                AND a."ShVTENTime" <= b."ShVTENTime" 
                            THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" 
                            WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 
                                AND b."ShVTSTTime" < a."ShVTSTTime" 
                                AND b."ShVTENTime" > a."ShVTENTime" 
                            THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" 
                            WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 
                                AND a."ShVTSTTime" < b."ShVTSTTime" 
                                AND a."ShVTENTime" > b."ShVTENTime" 
                            THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" 
                            ELSE 0 
                        END) AS "FinalPrice",
                        CASE 
                            WHEN a."Billed" = ''yes'' THEN ''Recovery''
                            ELSE ''Avoidance''
                        END AS "CostType",
                        CASE 
                            WHEN a."VisitStartTime" IS NULL THEN ''Scheduled''
                            WHEN a."VisitStartTime" IS NOT NULL AND a."Billed" != ''yes'' THEN ''Confirmed''
                            WHEN a."Billed" = ''no'' OR a."Billed" IS NULL THEN ''Billed''
                            ELSE ''Confirmed''
                        END AS "VisitType",
                        a."OriginalStatusFlag" AS "StatusFlag"
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
                            V1."Billed",
                            V1."VisitStartTime",
                            V2."StatusFlag" AS "OriginalStatusFlag",
                            CASE
                                WHEN V2."StatusFlag" IN(''R'', ''D'') THEN ''R''
                                WHEN V2."StatusFlag" IN (''N'') THEN ''N''
                                ELSE ''U''
                            END AS "StatusFlag"
                        FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
                        INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2 
                            ON V2."CONFLICTID" = V1."CONFLICTID"
                        WHERE V1."GroupID" IN (
                            SELECT DISTINCT "GroupID"
                            FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS
                            WHERE "PayerID" = ''${payerId}''
                                AND "SameSchTimeFlag" = ''Y''
                        )
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
                    ) b ON a.CONFLICTID <> b.CONFLICTID
                        AND a."GroupID" = b."GroupID"
                    GROUP BY a.CRDATEUNIQUE, a."Billed", a."VisitStartTime", a."OriginalStatusFlag"
				UNION ALL
					SELECT
						''${payerId}'' AS PAYERID,
						a."CRDATEUNIQUE" AS "CRDATEUNIQUE",
						''Exact Visit Time Match'' AS "ConflictType",
						''2'' AS "ConflictTypeF",
						COUNT(DISTINCT a."GroupID") AS "Total",
						SUM(CASE WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" ELSE 0 END) AS "ShiftPrice",
						SUM( CASE WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTSTTime" <= a."ShVTENTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTSTTime" <= b."ShVTENTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" < a."ShVTSTTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" < b."ShVTSTTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" ELSE 0 END ) AS "OverlapPrice",
						SUM( CASE WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTSTTime" <= a."ShVTENTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTSTTime" <= b."ShVTENTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" < a."ShVTSTTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" < b."ShVTSTTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" ELSE 0 END ) AS "FinalPrice",
						CASE 
							WHEN a."Billed" = ''yes'' THEN ''Recovery''
							ELSE ''Avoidance''
						END AS "CostType",
						CASE 
							WHEN a."VisitStartTime" IS NULL THEN ''Scheduled''
							WHEN a."VisitStartTime" IS NOT NULL AND a."Billed" != ''yes'' THEN ''Confirmed''
							WHEN a."Billed" = ''no'' OR a."Billed" IS NULL THEN ''Billed''
							ELSE ''Confirmed''
						END AS "VisitType",
						a."OriginalStatusFlag" AS "StatusFlag"
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
							V1."Billed",
							V1."VisitStartTime",
							V2."StatusFlag" AS "OriginalStatusFlag",
							CASE
								WHEN V2."StatusFlag" IN(''R'', ''D'') THEN ''R''
								WHEN V2."StatusFlag" IN (''N'') THEN ''N''
								ELSE ''U''
							END AS "StatusFlag"
						FROM
							CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
						INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2 ON
							V2."CONFLICTID" = V1."CONFLICTID"
						WHERE
							V1."GroupID" IN (
							SELECT
								DISTINCT "GroupID"
							FROM
								CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS
							WHERE
								"PayerID" = ''${payerId}''
									AND "SameVisitTimeFlag" = ''Y'' ) ) a
					LEFT JOIN (
						SELECT
							DISTINCT V1."GroupID",
							V1."CONFLICTID",
							V1."ShVTSTTime",
							V1."ShVTENTime",
							TO_CHAR(V1."G_CRDATEUNIQUE", ''YYYY-MM-DD'') AS CRDATEUNIQUE
						FROM
							CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
						INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2 ON
							V2."CONFLICTID" = V1."CONFLICTID"
						WHERE
							V1."GroupID" IN (
							SELECT
								DISTINCT "GroupID"
							FROM
								CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS
							WHERE
								"PayerID" = ''${payerId}'' ) ) b ON
						a.CONFLICTID <> b.CONFLICTID
						AND a."GroupID" = b."GroupID"
						GROUP BY a.CRDATEUNIQUE, a."Billed", a."VisitStartTime", a."OriginalStatusFlag"
				UNION ALL
					SELECT
						''${payerId}'' AS PAYERID,
						a."CRDATEUNIQUE" AS "CRDATEUNIQUE",
						''Exact Schedule and Visit Time Match'' AS "ConflictType",
						''3'' AS "ConflictTypeF",
						COUNT(DISTINCT a."GroupID") AS "Total",
						SUM(CASE WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" ELSE 0 END) AS "ShiftPrice",
						SUM( CASE WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTSTTime" <= a."ShVTENTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTSTTime" <= b."ShVTENTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" < a."ShVTSTTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" < b."ShVTSTTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" ELSE 0 END ) AS "OverlapPrice",
						SUM( CASE WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTSTTime" <= a."ShVTENTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTSTTime" <= b."ShVTENTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" < a."ShVTSTTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" < b."ShVTSTTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" ELSE 0 END ) AS "FinalPrice",
						CASE 
							WHEN a."Billed" = ''yes'' THEN ''Recovery''
							ELSE ''Avoidance''
						END AS "CostType",
						CASE 
							WHEN a."VisitStartTime" IS NULL THEN ''Scheduled''
							WHEN a."VisitStartTime" IS NOT NULL AND a."Billed" != ''yes'' THEN ''Confirmed''
							WHEN a."Billed" = ''no'' OR a."Billed" IS NULL THEN ''Billed''
							ELSE ''Confirmed''
						END AS "VisitType",
						a."OriginalStatusFlag" AS "StatusFlag"
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
							V1."Billed",
							V1."VisitStartTime",
							V2."StatusFlag" AS "OriginalStatusFlag",
							CASE
								WHEN V2."StatusFlag" IN(''R'', ''D'') THEN ''R''
								WHEN V2."StatusFlag" IN (''N'') THEN ''N''
								ELSE ''U''
							END AS "StatusFlag"
						FROM
							CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
						INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2 ON
							V2."CONFLICTID" = V1."CONFLICTID"
						WHERE
							V1."GroupID" IN (
							SELECT
								DISTINCT "GroupID"
							FROM
								CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS
							WHERE
								"PayerID" = ''${payerId}''
									AND "SchAndVisitTimeSameFlag" = ''Y'' ) ) a
					LEFT JOIN (
						SELECT
							DISTINCT V1."GroupID",
							V1."CONFLICTID",
							V1."ShVTSTTime",
							V1."ShVTENTime",
							TO_CHAR(V1."G_CRDATEUNIQUE", ''YYYY-MM-DD'') AS CRDATEUNIQUE
						FROM
							CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
						INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2 ON
							V2."CONFLICTID" = V1."CONFLICTID"
						WHERE
							V1."GroupID" IN (
							SELECT
								DISTINCT "GroupID"
							FROM
								CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS
							WHERE
								"PayerID" = ''${payerId}'' ) ) b ON
						a.CONFLICTID <> b.CONFLICTID
						AND a."GroupID" = b."GroupID"
						GROUP BY a.CRDATEUNIQUE, a."Billed", a."VisitStartTime", a."OriginalStatusFlag"
				UNION ALL
					SELECT
						''${payerId}'' AS PAYERID,
						a."CRDATEUNIQUE" AS "CRDATEUNIQUE",
						''Schedule time overlap'' AS "ConflictType",
						''4'' AS "ConflictTypeF",
						COUNT(DISTINCT a."GroupID") AS "Total",
						SUM(CASE WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" ELSE 0 END) AS "ShiftPrice",
						SUM( CASE WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTSTTime" <= a."ShVTENTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTSTTime" <= b."ShVTENTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" < a."ShVTSTTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" < b."ShVTSTTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" ELSE 0 END ) AS "OverlapPrice",
						SUM( CASE WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTSTTime" <= a."ShVTENTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTSTTime" <= b."ShVTENTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" < a."ShVTSTTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" < b."ShVTSTTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" ELSE 0 END ) AS "FinalPrice",
						CASE 
							WHEN a."Billed" = ''yes'' THEN ''Recovery''
							ELSE ''Avoidance''
						END AS "CostType",
						CASE 
							WHEN a."VisitStartTime" IS NULL THEN ''Scheduled''
							WHEN a."VisitStartTime" IS NOT NULL AND a."Billed" != ''yes'' THEN ''Confirmed''
							WHEN a."Billed" = ''no'' OR a."Billed" IS NULL THEN ''Billed''
							ELSE ''Confirmed''
						END AS "VisitType",
						a."OriginalStatusFlag" AS "StatusFlag"
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
							V1."Billed",
							V1."VisitStartTime",
							V2."StatusFlag" AS "OriginalStatusFlag",
							CASE
								WHEN V2."StatusFlag" IN(''R'', ''D'') THEN ''R''
								WHEN V2."StatusFlag" IN (''N'') THEN ''N''
								ELSE ''U''
							END AS "StatusFlag"
						FROM
							CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
						INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2 ON
							V2."CONFLICTID" = V1."CONFLICTID"
						WHERE
							V1."GroupID" IN (
							SELECT
								DISTINCT "GroupID"
							FROM
								CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS
							WHERE
								"PayerID" = ''${payerId}''
									AND "SchOverAnotherSchTimeFlag" = ''Y'' ) ) a
					LEFT JOIN (
						SELECT
							DISTINCT V1."GroupID",
							V1."CONFLICTID",
							V1."ShVTSTTime",
							V1."ShVTENTime",
							TO_CHAR(V1."G_CRDATEUNIQUE", ''YYYY-MM-DD'') AS CRDATEUNIQUE
						FROM
							CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
						INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2 ON
							V2."CONFLICTID" = V1."CONFLICTID"
						WHERE
							V1."GroupID" IN (
							SELECT
								DISTINCT "GroupID"
							FROM
								CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS
							WHERE
								"PayerID" = ''${payerId}'' ) ) b ON
						a.CONFLICTID <> b.CONFLICTID
						AND a."GroupID" = b."GroupID"
						GROUP BY a.CRDATEUNIQUE, a."Billed", a."VisitStartTime", a."OriginalStatusFlag"
				UNION ALL
					SELECT
						''${payerId}'' AS PAYERID,
						a."CRDATEUNIQUE" AS "CRDATEUNIQUE",
						''Visit Time Overlap'' AS "ConflictType",
						''5'' AS "ConflictTypeF",
						COUNT(DISTINCT a."GroupID") AS "Total",
						SUM(CASE WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" ELSE 0 END) AS "ShiftPrice",
						SUM( CASE WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTSTTime" <= a."ShVTENTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTSTTime" <= b."ShVTENTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" < a."ShVTSTTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" < b."ShVTSTTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" ELSE 0 END ) AS "OverlapPrice",
						SUM( CASE WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTSTTime" <= a."ShVTENTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTSTTime" <= b."ShVTENTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" < a."ShVTSTTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" < b."ShVTSTTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" ELSE 0 END ) AS "FinalPrice",
						CASE 
							WHEN a."Billed" = ''yes'' THEN ''Recovery''
							ELSE ''Avoidance''
						END AS "CostType",
						CASE 
							WHEN a."VisitStartTime" IS NULL THEN ''Scheduled''
							WHEN a."VisitStartTime" IS NOT NULL AND a."Billed" != ''yes'' THEN ''Confirmed''
							WHEN a."Billed" = ''no'' OR a."Billed" IS NULL THEN ''Billed''
							ELSE ''Confirmed''
						END AS "VisitType",
						a."OriginalStatusFlag" AS "StatusFlag"
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
							V1."Billed",
							V1."VisitStartTime",
							V2."StatusFlag" AS "OriginalStatusFlag",
							CASE
								WHEN V2."StatusFlag" IN(''R'', ''D'') THEN ''R''
								WHEN V2."StatusFlag" IN (''N'') THEN ''N''
								ELSE ''U''
							END AS "StatusFlag"
						FROM
							CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
						INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2 ON
							V2."CONFLICTID" = V1."CONFLICTID"
						WHERE
							V1."GroupID" IN (
							SELECT
								DISTINCT "GroupID"
							FROM
								CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS
							WHERE
								"PayerID" = ''${payerId}''
									AND "VisitTimeOverAnotherVisitTimeFlag" = ''Y'' ) ) a
					LEFT JOIN (
						SELECT
							DISTINCT V1."GroupID",
							V1."CONFLICTID",
							V1."ShVTSTTime",
							V1."ShVTENTime",
							TO_CHAR(V1."G_CRDATEUNIQUE", ''YYYY-MM-DD'') AS CRDATEUNIQUE
						FROM
							CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
						INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2 ON
							V2."CONFLICTID" = V1."CONFLICTID"
						WHERE
							V1."GroupID" IN (
							SELECT
								DISTINCT "GroupID"
							FROM
								CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS
							WHERE
								"PayerID" = ''${payerId}'' ) ) b ON
						a.CONFLICTID <> b.CONFLICTID
						AND a."GroupID" = b."GroupID"
						GROUP BY a.CRDATEUNIQUE, a."Billed", a."VisitStartTime", a."OriginalStatusFlag"
				UNION ALL
					SELECT
						''${payerId}'' AS PAYERID,
						a."CRDATEUNIQUE" AS "CRDATEUNIQUE",
						''Schedule and Visit time overlap'' AS "ConflictType",
						''6'' AS "ConflictTypeF",
						COUNT(DISTINCT a."GroupID") AS "Total",
						SUM(CASE WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" ELSE 0 END) AS "ShiftPrice",
						SUM( CASE WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTSTTime" <= a."ShVTENTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTSTTime" <= b."ShVTENTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" < a."ShVTSTTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" < b."ShVTSTTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" ELSE 0 END ) AS "OverlapPrice",
						SUM( CASE WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTSTTime" <= a."ShVTENTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTSTTime" <= b."ShVTENTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" < a."ShVTSTTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" < b."ShVTSTTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" ELSE 0 END ) AS "FinalPrice",
						CASE 
							WHEN a."Billed" = ''yes'' THEN ''Recovery''
							ELSE ''Avoidance''
						END AS "CostType",
						CASE 
							WHEN a."VisitStartTime" IS NULL THEN ''Scheduled''
							WHEN a."VisitStartTime" IS NOT NULL AND a."Billed" != ''yes'' THEN ''Confirmed''
							WHEN a."Billed" = ''no'' OR a."Billed" IS NULL THEN ''Billed''
							ELSE ''Confirmed''
						END AS "VisitType",
						a."OriginalStatusFlag" AS "StatusFlag"
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
							V1."Billed",
							V1."VisitStartTime",
							V2."StatusFlag" AS "OriginalStatusFlag",
							CASE
								WHEN V2."StatusFlag" IN(''R'', ''D'') THEN ''R''
								WHEN V2."StatusFlag" IN (''N'') THEN ''N''
								ELSE ''U''
							END AS "StatusFlag"
						FROM
							CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
						INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2 ON
							V2."CONFLICTID" = V1."CONFLICTID"
						WHERE
							V1."GroupID" IN (
							SELECT
								DISTINCT "GroupID"
							FROM
								CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS
							WHERE
								"PayerID" = ''${payerId}''
									AND "SchTimeOverVisitTimeFlag" = ''Y'' ) ) a
					LEFT JOIN (
						SELECT
							DISTINCT V1."GroupID",
							V1."CONFLICTID",
							V1."ShVTSTTime",
							V1."ShVTENTime",
							TO_CHAR(V1."G_CRDATEUNIQUE", ''YYYY-MM-DD'') AS CRDATEUNIQUE
						FROM
							CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
						INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2 ON
							V2."CONFLICTID" = V1."CONFLICTID"
						WHERE
							V1."GroupID" IN (
							SELECT
								DISTINCT "GroupID"
							FROM
								CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS
							WHERE
								"PayerID" = ''${payerId}'' ) ) b ON
						a.CONFLICTID <> b.CONFLICTID
						AND a."GroupID" = b."GroupID"
						GROUP BY a.CRDATEUNIQUE, a."Billed", a."VisitStartTime", a."OriginalStatusFlag"
				UNION ALL
					SELECT
						''${payerId}'' AS PAYERID,
						a."CRDATEUNIQUE" AS "CRDATEUNIQUE",
						''Time- Distance'' AS "ConflictType",
						''7'' AS "ConflictTypeF",
						COUNT(DISTINCT a."GroupID") AS "Total",
						SUM(CASE WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" ELSE 0 END) AS "ShiftPrice",
						SUM( CASE WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTSTTime" <= a."ShVTENTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTSTTime" <= b."ShVTENTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" < a."ShVTSTTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" < b."ShVTSTTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" ELSE 0 END ) AS "OverlapPrice",
						SUM( CASE WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTSTTime" <= a."ShVTENTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTSTTime" <= b."ShVTENTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" < a."ShVTSTTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" < b."ShVTSTTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" ELSE 0 END ) AS "FinalPrice",
						CASE 
							WHEN a."Billed" = ''yes'' THEN ''Recovery''
							ELSE ''Avoidance''
						END AS "CostType",
						CASE 
							WHEN a."VisitStartTime" IS NULL THEN ''Scheduled''
							WHEN a."VisitStartTime" IS NOT NULL AND a."Billed" != ''yes'' THEN ''Confirmed''
							WHEN a."Billed" = ''no'' OR a."Billed" IS NULL THEN ''Billed''
							ELSE ''Confirmed''
						END AS "VisitType",
						a."OriginalStatusFlag" AS "StatusFlag"
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
							V1."Billed",
							V1."VisitStartTime",
							V2."StatusFlag" AS "OriginalStatusFlag",
							CASE
								WHEN V2."StatusFlag" IN(''R'', ''D'') THEN ''R''
								WHEN V2."StatusFlag" IN (''N'') THEN ''N''
								ELSE ''U''
							END AS "StatusFlag"
						FROM
							CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
						INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2 ON
							V2."CONFLICTID" = V1."CONFLICTID"
						WHERE
							V1."GroupID" IN (
							SELECT
								DISTINCT "GroupID"
							FROM
								CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS
							WHERE
								"PayerID" = ''${payerId}''
									AND "DistanceFlag" = ''Y'' ) ) a
					LEFT JOIN (
						SELECT
							DISTINCT V1."GroupID",
							V1."CONFLICTID",
							V1."ShVTSTTime",
							V1."ShVTENTime",
							TO_CHAR(V1."G_CRDATEUNIQUE", ''YYYY-MM-DD'') AS CRDATEUNIQUE
						FROM
							CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
						INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2 ON
							V2."CONFLICTID" = V1."CONFLICTID"
						WHERE
							V1."GroupID" IN (
							SELECT
								DISTINCT "GroupID"
							FROM
								CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS
							WHERE
								"PayerID" = ''${payerId}'' ) ) b ON
						a.CONFLICTID <> b.CONFLICTID
						AND a."GroupID" = b."GroupID"
						GROUP BY a.CRDATEUNIQUE, a."Billed", a."VisitStartTime", a."OriginalStatusFlag"
				UNION ALL
					SELECT
						''${payerId}'' AS PAYERID,
						a."CRDATEUNIQUE" AS "CRDATEUNIQUE",
						''In-Service'' AS "ConflictType",
						''8'' AS "ConflictTypeF",
						COUNT(DISTINCT a."GroupID") AS "Total",
						SUM(CASE WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" ELSE 0 END) AS "ShiftPrice",
						SUM( CASE WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTSTTime" <= a."ShVTENTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTSTTime" <= b."ShVTENTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" < a."ShVTSTTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" < b."ShVTSTTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" ELSE 0 END ) AS "OverlapPrice",
						SUM( CASE WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTSTTime" <= a."ShVTENTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTSTTime" <= b."ShVTENTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" < a."ShVTSTTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" < b."ShVTSTTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" ELSE 0 END ) AS "FinalPrice",
						CASE 
							WHEN a."Billed" = ''yes'' THEN ''Recovery''
							ELSE ''Avoidance''
						END AS "CostType",
						CASE 
							WHEN a."VisitStartTime" IS NULL THEN ''Scheduled''
							WHEN a."VisitStartTime" IS NOT NULL AND a."Billed" != ''yes'' THEN ''Confirmed''
							WHEN a."Billed" = ''no'' OR a."Billed" IS NULL THEN ''Billed''
							ELSE ''Confirmed''
						END AS "VisitType",
						a."OriginalStatusFlag" AS "StatusFlag"
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
							V1."Billed",
							V1."VisitStartTime",
							V2."StatusFlag" AS "OriginalStatusFlag",
							CASE
								WHEN V2."StatusFlag" IN(''R'', ''D'') THEN ''R''
								WHEN V2."StatusFlag" IN (''N'') THEN ''N''
								ELSE ''U''
							END AS "StatusFlag"
						FROM
							CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
						INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2 ON
							V2."CONFLICTID" = V1."CONFLICTID"
						WHERE
							V1."GroupID" IN (
							SELECT
								DISTINCT "GroupID"
							FROM
								CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS
							WHERE
								"PayerID" = ''${payerId}''
									AND "InServiceFlag" = ''Y'' ) ) a
					LEFT JOIN (
						SELECT
							DISTINCT V1."GroupID",
							V1."CONFLICTID",
							V1."ShVTSTTime",
							V1."ShVTENTime",
							TO_CHAR(V1."G_CRDATEUNIQUE", ''YYYY-MM-DD'') AS CRDATEUNIQUE
						FROM
							CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
						INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2 ON
							V2."CONFLICTID" = V1."CONFLICTID"
						WHERE
							V1."GroupID" IN (
							SELECT
								DISTINCT "GroupID"
							FROM
								CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS
							WHERE
								"PayerID" = ''${payerId}'' ) ) b ON
						a.CONFLICTID <> b.CONFLICTID
						AND a."GroupID" = b."GroupID"
						GROUP BY a.CRDATEUNIQUE, a."Billed", a."VisitStartTime", a."OriginalStatusFlag"
				UNION ALL
					SELECT
						''${payerId}'' AS PAYERID,
						a."CRDATEUNIQUE" AS "CRDATEUNIQUE",
						''PTO'' AS "ConflictType",
						''9'' AS "ConflictTypeF",
						COUNT(DISTINCT a."GroupID") AS "Total",
						SUM(CASE WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" ELSE 0 END) AS "ShiftPrice",
						SUM( CASE WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTSTTime" <= a."ShVTENTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTSTTime" <= b."ShVTENTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" < a."ShVTSTTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" < b."ShVTSTTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" ELSE 0 END ) AS "OverlapPrice",
						SUM( CASE WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTSTTime" <= a."ShVTENTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTSTTime" <= b."ShVTENTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" >= a."ShVTSTTime" AND b."ShVTENTime" <= a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" >= b."ShVTSTTime" AND a."ShVTENTime" <= b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND b."ShVTSTTime" < a."ShVTSTTime" AND b."ShVTENTime" > a."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, a."ShVTSTTime", a."ShVTENTime") * a."BilledRateMinute" WHEN a.APID = ''${payerId}'' AND a."StatusFlag" = ''R'' AND a."BilledRateMinute" > 0 AND a."ShVTSTTime" < b."ShVTSTTime" AND a."ShVTENTime" > b."ShVTENTime" THEN TIMESTAMPDIFF(MINUTE, b."ShVTSTTime", b."ShVTENTime") * a."BilledRateMinute" ELSE 0 END ) AS "FinalPrice",
						CASE 
							WHEN a."Billed" = ''yes'' THEN ''Recovery''
							ELSE ''Avoidance''
						END AS "CostType",
						CASE 
							WHEN a."VisitStartTime" IS NULL THEN ''Scheduled''
							WHEN a."VisitStartTime" IS NOT NULL AND a."Billed" != ''yes'' THEN ''Confirmed''
							WHEN a."Billed" = ''no'' OR a."Billed" IS NULL THEN ''Billed''
							ELSE ''Confirmed''
						END AS "VisitType",
						a."OriginalStatusFlag" AS "StatusFlag"
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
							V1."Billed",
							V1."VisitStartTime",
							V2."StatusFlag" AS "OriginalStatusFlag",
							CASE
								WHEN V2."StatusFlag" IN(''R'', ''D'') THEN ''R''
								WHEN V2."StatusFlag" IN (''N'') THEN ''N''
								ELSE ''U''
							END AS "StatusFlag"
						FROM
							CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
						INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2 ON
							V2."CONFLICTID" = V1."CONFLICTID"
						WHERE
							V1."GroupID" IN (
							SELECT
								DISTINCT "GroupID"
							FROM
								CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS
							WHERE
								"PayerID" = ''${payerId}''
									AND "PTOFlag" = ''Y'' ) ) a
					LEFT JOIN (
						SELECT
							DISTINCT V1."GroupID",
							V1."CONFLICTID",
							V1."ShVTSTTime",
							V1."ShVTENTime",
							TO_CHAR(V1."G_CRDATEUNIQUE", ''YYYY-MM-DD'') AS CRDATEUNIQUE
						FROM
							CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
						INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2 ON
							V2."CONFLICTID" = V1."CONFLICTID"
						WHERE
							V1."GroupID" IN (
							SELECT
								DISTINCT "GroupID"
							FROM
								CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS
							WHERE
								"PayerID" = ''${payerId}'' ) ) b ON
						a.CONFLICTID <> b.CONFLICTID
						AND a."GroupID" = b."GroupID"
						GROUP BY a.CRDATEUNIQUE, a."Billed", a."VisitStartTime", a."OriginalStatusFlag"
					) subquery
					GROUP BY PAYERID, "CRDATEUNIQUE", "ConflictType", "ConflictTypeF", "CostType", "VisitType", "StatusFlag"
					`;
	
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