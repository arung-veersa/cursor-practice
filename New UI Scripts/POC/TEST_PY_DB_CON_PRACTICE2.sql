CREATE OR REPLACE PROCEDURE CONFLICTREPORT_SANDBOX.PUBLIC.TEST_PY_DB_CON_PRACTICE_DATA()
RETURNS VARCHAR
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS '
    try {
        // Step 1: Truncate the target table
        var truncate1Stmt = snowflake.createStatement({
            sqlText: `TRUNCATE TABLE CONFLICTREPORT_SANDBOX.PUBLIC.TEST_PY_DB_CON_PRACTICE`
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
                INSERT INTO CONFLICTREPORT_SANDBOX.PUBLIC.TEST_PY_DB_CON_PRACTICE 
                    (PAYERID, CRDATEUNIQUE, CONTYPE, CONTYPES, COSTTYPE, VISITTYPE, STATUSFLAG, CO_TO, CO_SP, CO_OP, CO_FP)
                SELECT PAYERID, CRDATEUNIQUE, CONTYPEDESC, CONTYPEID, "COSTTYPE", "VISITTYPE", "STATUSFLAG", "Total", "ShiftPrice", "OverlapPrice", "FinalPrice"
                FROM (
                    SELECT
                        ''${payerId}'' AS PAYERID,
                        a."CRDATEUNIQUE" AS "CRDATEUNIQUE",
                        CASE 
                            WHEN a."SameSchTimeFlag" = ''Y'' 
                                OR a."SameVisitTimeFlag" = ''Y''
                                OR a."SchAndVisitTimeSameFlag" = ''Y''
                                OR a."SchOverAnotherSchTimeFlag" = ''Y''
                                OR a."VisitTimeOverAnotherVisitTimeFlag" = ''Y''
                                OR a."SchTimeOverVisitTimeFlag" = ''Y'' THEN ''Time Overlap''
                            WHEN a."DistanceFlag" = ''Y'' THEN ''Time- Distance''
                            WHEN a."InServiceFlag" = ''Y'' THEN ''In-Service''
                            WHEN a."PTOFlag" = ''Y'' THEN ''PTO''
                        END AS CONTYPEDESC,
                        CASE 
                            WHEN a."SameSchTimeFlag" = ''Y'' 
                                OR a."SameVisitTimeFlag" = ''Y''
                                OR a."SchAndVisitTimeSameFlag" = ''Y''
                                OR a."SchOverAnotherSchTimeFlag" = ''Y''
                                OR a."VisitTimeOverAnotherVisitTimeFlag" = ''Y''
                                OR a."SchTimeOverVisitTimeFlag" = ''Y'' THEN ''100''
                            WHEN a."DistanceFlag" = ''Y'' THEN ''7''
                            WHEN a."InServiceFlag" = ''Y'' THEN ''8''
                            WHEN a."PTOFlag" = ''Y'' THEN ''9''
                        END AS CONTYPEID,
                        a."COSTTYPE" AS "COSTTYPE",
                        a."VISITTYPE" AS "VISITTYPE",
                        a."StatusFlag" AS "STATUSFLAG",
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
                        END) AS "FinalPrice"
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
                            V1."SameSchTimeFlag",
                            V1."SameVisitTimeFlag",
                            V1."SchAndVisitTimeSameFlag",
                            V1."SchOverAnotherSchTimeFlag",
                            V1."VisitTimeOverAnotherVisitTimeFlag",
                            V1."SchTimeOverVisitTimeFlag",
                            V1."DistanceFlag",
                            V1."InServiceFlag",
                            V1."PTOFlag",
                            CASE
                                WHEN V2."StatusFlag" IN(''R'', ''D'') THEN ''R''
                                WHEN V2."StatusFlag" IN (''N'') THEN ''N''
                                ELSE ''U''
                            END AS "StatusFlag",
                            CASE
                                WHEN V1."Billed" = ''no'' OR V1."Billed" IS NULL THEN ''Avoidance''
                                WHEN V1."Billed" = ''yes'' THEN ''Recovery''
                                ELSE ''Avoidance''
                            END AS "COSTTYPE",
                            CASE
                                WHEN V1."VisitStartTime" IS NULL THEN ''Scheduled''
                                WHEN V1."VisitStartTime" IS NOT NULL AND V1."Billed" != ''yes'' THEN ''Confirmed''
                                WHEN V1."Billed" = ''yes'' THEN ''Billed''
                                ELSE ''Scheduled''
                            END AS "VISITTYPE"
                        FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
                        INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2 
                            ON V2."CONFLICTID" = V1."CONFLICTID"
                        WHERE V1."PayerID" = ''${payerId}''
                            AND (V1."SameSchTimeFlag" = ''Y'' 
                                 OR V1."SameVisitTimeFlag" = ''Y''
                                 OR V1."SchAndVisitTimeSameFlag" = ''Y''
                                 OR V1."SchOverAnotherSchTimeFlag" = ''Y''
                                 OR V1."VisitTimeOverAnotherVisitTimeFlag" = ''Y''
                                 OR V1."SchTimeOverVisitTimeFlag" = ''Y''
                                 OR V1."DistanceFlag" = ''Y''
                                 OR V1."InServiceFlag" = ''Y''
                                 OR V1."PTOFlag" = ''Y'')
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
                    GROUP BY a."CRDATEUNIQUE",CONTYPEDESC,CONTYPEID,a."COSTTYPE",a."VISITTYPE",a."StatusFlag"
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
        throw "ERROR: " + err.message;
    }
';