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

        // Step 2: Insert data for all payers using subquery structure
        var insertAllStmt = snowflake.createStatement({
            sqlText: `
                INSERT INTO CONFLICTREPORT_SANDBOX.PUBLIC.TEST_PY_DB_CON_PRACTICE 
                    (PAYERID, CRDATEUNIQUE, CONTYPE, CONTYPES, COSTTYPE, VISITTYPE, STATUSFLAG, CO_TO, CO_SP, CO_OP, CO_FP)
                SELECT 
                    PAYERID, 
                    CRDATEUNIQUE, 
                    CONTYPEDESC, 
                    CONTYPEID, 
                    "COSTTYPE", 
                    "VISITTYPE", 
                    "StatusFlag", 
                    "Total", 
                    "ShiftPrice", 
                    "OverlapPrice", 
                    "FinalPrice"
                FROM (
                    SELECT
                        APID AS PAYERID,
                        "CRDATEUNIQUE" AS CRDATEUNIQUE,
                        CONTYPEDESC,
                        CONTYPEID,
                        "COSTTYPE",
                        "VISITTYPE",
                        "StatusFlag",
                        COUNT(DISTINCT "GroupID") AS "Total",
                        SUM(CASE 
                            WHEN "BilledRateMinute" > 0 
                            THEN TIMESTAMPDIFF(MINUTE, "ShVTSTTime", "ShVTENTime") * "BilledRateMinute" 
                            ELSE 0 
                        END) AS "ShiftPrice",
                        SUM(CASE 
                            WHEN "BilledRateMinute" > 0 
                                AND B_ShVTSTTime >= "ShVTSTTime" 
                                AND B_ShVTSTTime <= "ShVTENTime" 
                                AND B_ShVTENTime > "ShVTENTime" 
                            THEN TIMESTAMPDIFF(MINUTE, B_ShVTSTTime, "ShVTENTime") * "BilledRateMinute" 
                            WHEN "BilledRateMinute" > 0 
                                AND "ShVTSTTime" >= B_ShVTSTTime 
                                AND "ShVTSTTime" <= B_ShVTENTime 
                                AND "ShVTENTime" > B_ShVTENTime 
                            THEN TIMESTAMPDIFF(MINUTE, "ShVTSTTime", B_ShVTENTime) * "BilledRateMinute" 
                            WHEN "BilledRateMinute" > 0 
                                AND B_ShVTSTTime >= "ShVTSTTime" 
                                AND B_ShVTENTime <= "ShVTENTime" 
                            THEN TIMESTAMPDIFF(MINUTE, B_ShVTSTTime, B_ShVTENTime) * "BilledRateMinute" 
                            WHEN "BilledRateMinute" > 0 
                                AND "ShVTSTTime" >= B_ShVTSTTime 
                                AND "ShVTENTime" <= B_ShVTENTime 
                            THEN TIMESTAMPDIFF(MINUTE, "ShVTSTTime", "ShVTENTime") * "BilledRateMinute" 
                            WHEN "BilledRateMinute" > 0 
                                AND B_ShVTSTTime < "ShVTSTTime" 
                                AND B_ShVTENTime > "ShVTENTime" 
                            THEN TIMESTAMPDIFF(MINUTE, "ShVTSTTime", "ShVTENTime") * "BilledRateMinute" 
                            WHEN "BilledRateMinute" > 0 
                                AND "ShVTSTTime" < B_ShVTSTTime 
                                AND "ShVTENTime" > B_ShVTENTime 
                            THEN TIMESTAMPDIFF(MINUTE, B_ShVTSTTime, B_ShVTENTime) * "BilledRateMinute" 
                            ELSE 0 
                        END) AS "OverlapPrice",
                        SUM(CASE 
                            WHEN "StatusFlag" = ''R'' AND "BilledRateMinute" > 0 
                                AND B_ShVTSTTime >= "ShVTSTTime" 
                                AND B_ShVTSTTime <= "ShVTENTime" 
                                AND B_ShVTENTime > "ShVTENTime" 
                            THEN TIMESTAMPDIFF(MINUTE, B_ShVTSTTime, "ShVTENTime") * "BilledRateMinute" 
                            WHEN "StatusFlag" = ''R'' AND "BilledRateMinute" > 0 
                                AND "ShVTSTTime" >= B_ShVTSTTime 
                                AND "ShVTSTTime" <= B_ShVTENTime 
                                AND "ShVTENTime" > B_ShVTENTime 
                            THEN TIMESTAMPDIFF(MINUTE, "ShVTSTTime", B_ShVTENTime) * "BilledRateMinute" 
                            WHEN "StatusFlag" = ''R'' AND "BilledRateMinute" > 0 
                                AND B_ShVTSTTime >= "ShVTSTTime" 
                                AND B_ShVTENTime <= "ShVTENTime" 
                            THEN TIMESTAMPDIFF(MINUTE, B_ShVTSTTime, B_ShVTENTime) * "BilledRateMinute" 
                            WHEN "StatusFlag" = ''R'' AND "BilledRateMinute" > 0 
                                AND "ShVTSTTime" >= B_ShVTSTTime 
                                AND "ShVTENTime" <= B_ShVTENTime 
                            THEN TIMESTAMPDIFF(MINUTE, "ShVTSTTime", "ShVTENTime") * "BilledRateMinute" 
                            WHEN "StatusFlag" = ''R'' AND "BilledRateMinute" > 0 
                                AND B_ShVTSTTime < "ShVTSTTime" 
                                AND B_ShVTENTime > "ShVTENTime" 
                            THEN TIMESTAMPDIFF(MINUTE, "ShVTSTTime", "ShVTENTime") * "BilledRateMinute" 
                            WHEN "StatusFlag" = ''R'' AND "BilledRateMinute" > 0 
                                AND "ShVTSTTime" < B_ShVTSTTime 
                                AND "ShVTENTime" > B_ShVTENTime 
                            THEN TIMESTAMPDIFF(MINUTE, B_ShVTSTTime, B_ShVTENTime) * "BilledRateMinute" 
                            ELSE 0 
                        END) AS "FinalPrice"
                    FROM (
                        SELECT
                            a.APID,
                            a."CRDATEUNIQUE",
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
                            a."COSTTYPE",
                            a."VISITTYPE",
                            a."StatusFlag",
                            a."GroupID",
                            a."ShVTSTTime",
                            a."ShVTENTime",
                            a."BilledRateMinute",
                            b."ShVTSTTime" AS B_ShVTSTTime,
                            b."ShVTENTime" AS B_ShVTENTime
                        FROM (
                            SELECT DISTINCT 
                                V1."GroupID",
                                V1."CONFLICTID",
                                V1."ShVTSTTime",
                                V1."ShVTENTime",
                                V1."BilledRateMinute",
                                V1."G_CRDATEUNIQUE",
                                DATE(V1."G_CRDATEUNIQUE") AS CRDATEUNIQUE,
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
                                    WHEN V2."StatusFlag" IN (''R'', ''D'') THEN ''R''
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
                            INNER JOIN (
                                SELECT DISTINCT V1."PayerID" AS APID
                                FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
                                INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2 
                                    ON V2."CONFLICTID" = V1."CONFLICTID"
                                INNER JOIN ANALYTICS_SANDBOX.BI.DIMPAYER AS P
                                    ON P."Payer Id" = V1."PayerID"
                                WHERE P."Is Active" = TRUE 
                                    AND P."Is Demo" = FALSE
                            ) AS ValidPayers ON V1."PayerID" = ValidPayers.APID
                            WHERE (V1."SameSchTimeFlag" = ''Y'' 
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
                                DATE(V1."G_CRDATEUNIQUE") AS CRDATEUNIQUE
                            FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
                            INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2 
                                ON V2."CONFLICTID" = V1."CONFLICTID"
                            INNER JOIN (
                                SELECT DISTINCT V1."PayerID" AS APID
                                FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
                                INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2 
                                    ON V2."CONFLICTID" = V1."CONFLICTID"
                                INNER JOIN ANALYTICS_SANDBOX.BI.DIMPAYER AS P
                                    ON P."Payer Id" = V1."PayerID"
                                WHERE P."Is Active" = TRUE 
                                    AND P."Is Demo" = FALSE
                            ) AS ValidPayers ON V1."PayerID" = ValidPayers.APID
                        ) b ON a."CONFLICTID" <> b."CONFLICTID"
                            AND a."GroupID" = b."GroupID"
                    ) ProcessedData
                    GROUP BY APID, "CRDATEUNIQUE", CONTYPEDESC, CONTYPEID, "COSTTYPE", "VISITTYPE", "StatusFlag"
                ) AggregatedData
            `
        });

        insertAllStmt.execute();

        return `Inserted rows successfully.`;

    } catch (err) {
        throw "ERROR: " + err.message;
    }
';