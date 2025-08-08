-- Stored Procedure to populate PAYER_DASHBOARD_CON_TYP_NEW_CALC table

CREATE OR REPLACE PROCEDURE CONFLICTREPORT_SANDBOX.PUBLIC.LOAD_PAYER_DASHBOARD_CON_TYP_NEW_CALC()
RETURNS STRING
LANGUAGE JAVASCRIPT
AS
$$
    try {
        // Clear existing data from the target table
        var clearQuery = `TRUNCATE TABLE CONFLICTREPORT_SANDBOX.PUBLIC.PAYER_DASHBOARD_CON_TYP_NEW_CALC`;
        snowflake.execute({sqlText: clearQuery});
        
        // Use the optimized SQL query that processes all payers in a single statement
        var optimizedQuery = `
            INSERT INTO CONFLICTREPORT_SANDBOX.PUBLIC.PAYER_DASHBOARD_CON_TYP_NEW_CALC (
                PAYERID, CRDATEUNIQUE, CONTYPE, CONTYPEDESC, STATUSFLAG, COSTTYPE, VISITTYPE,
                CO_TO, CO_SP, CO_OP, CO_FP
            )
            WITH PAYER_LIST AS (
                -- Get all distinct PayerIds from active, non-demo payers (pre-filtered for performance)
                SELECT DISTINCT V1."PayerID" AS APID
                FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
                INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2 
                    ON V2."CONFLICTID" = V1."CONFLICTID"
                INNER JOIN ANALYTICS_SANDBOX.BI.DIMPAYER AS P 
                    ON P."Payer Id" = V1."PayerID"
                WHERE P."Is Active" = TRUE 
                    AND P."Is Demo" = FALSE
            ),
            CONFLICT_ANALYSIS AS (
                -- Combined CTE: Pre-filter, deduplicate, and analyze conflicts in one pass
                SELECT 
                    "CONFLICTID",
                    "VisitID",
                    "ConVisitID",
                    "ShVTSTTime",
                    "ShVTENTime",
                    "CShVTSTTime",
                    "CShVTENTime",
                    "BilledRateMinute",
                    "StatusFlag",
                    "Billed",
                    "VisitStartTime",
                    "PROCESSING_PAYERID",
                    -- Create Boolean flags for each conflict type (modularized approach)
                    CASE 
                        WHEN ("SameSchTimeFlag" = ''Y'' OR "SameVisitTimeFlag" = ''Y'' OR "SchAndVisitTimeSameFlag" = ''Y'' 
                              OR "SchOverAnotherSchTimeFlag" = ''Y'' OR "VisitTimeOverAnotherVisitTimeFlag" = ''Y'' 
                              OR "SchTimeOverVisitTimeFlag" = ''Y'') THEN 1
                        ELSE 0
                    END AS HAS_TIME_OVERLAP,
                    CASE WHEN "DistanceFlag" = ''Y'' THEN 1 ELSE 0 END AS HAS_TIME_DISTANCE,
                    CASE WHEN "InServiceFlag" = ''Y'' THEN 1 ELSE 0 END AS HAS_IN_SERVICE,
                    -- Determine conflict type using modular Boolean flags
                    CASE 
                        WHEN HAS_TIME_OVERLAP = 1 AND HAS_TIME_DISTANCE = 0 AND HAS_IN_SERVICE = 0 THEN ''only_to''
                        WHEN HAS_TIME_OVERLAP = 0 AND HAS_TIME_DISTANCE = 1 AND HAS_IN_SERVICE = 0 THEN ''only_td''
                        WHEN HAS_TIME_OVERLAP = 0 AND HAS_TIME_DISTANCE = 0 AND HAS_IN_SERVICE = 1 THEN ''only_is''
                        WHEN HAS_TIME_OVERLAP = 1 AND HAS_TIME_DISTANCE = 1 AND HAS_IN_SERVICE = 0 THEN ''both_to_td''
                        WHEN HAS_TIME_OVERLAP = 1 AND HAS_TIME_DISTANCE = 0 AND HAS_IN_SERVICE = 1 THEN ''both_to_is''
                        WHEN HAS_TIME_OVERLAP = 0 AND HAS_TIME_DISTANCE = 1 AND HAS_IN_SERVICE = 1 THEN ''both_td_is''
                        WHEN HAS_TIME_OVERLAP = 1 AND HAS_TIME_DISTANCE = 1 AND HAS_IN_SERVICE = 1 THEN ''all_to_td_is''
                        ELSE NULL
                    END AS CONTYPE,
                    -- Determine conflict type description using the same Boolean flags
                    CASE 
                        WHEN HAS_TIME_OVERLAP = 1 AND HAS_TIME_DISTANCE = 0 AND HAS_IN_SERVICE = 0 THEN ''Time Overlap Only''
                        WHEN HAS_TIME_OVERLAP = 0 AND HAS_TIME_DISTANCE = 1 AND HAS_IN_SERVICE = 0 THEN ''Time Distance Only''
                        WHEN HAS_TIME_OVERLAP = 0 AND HAS_TIME_DISTANCE = 0 AND HAS_IN_SERVICE = 1 THEN ''In Service Only''
                        WHEN HAS_TIME_OVERLAP = 1 AND HAS_TIME_DISTANCE = 1 AND HAS_IN_SERVICE = 0 THEN ''Time Overlap and Time Distance''
                        WHEN HAS_TIME_OVERLAP = 1 AND HAS_TIME_DISTANCE = 0 AND HAS_IN_SERVICE = 1 THEN ''Time Overlap and In Service''
                        WHEN HAS_TIME_OVERLAP = 0 AND HAS_TIME_DISTANCE = 1 AND HAS_IN_SERVICE = 1 THEN ''Time Distance and In Service''
                        WHEN HAS_TIME_OVERLAP = 1 AND HAS_TIME_DISTANCE = 1 AND HAS_IN_SERVICE = 1 THEN ''All Three (Time Overlap, Time Distance, and In Service)''
                        ELSE NULL
                    END AS CONTYPEDESC,
                    -- Determine cost type
                    CASE WHEN "Billed" = ''yes'' THEN ''Recovery'' ELSE ''Avoidance'' END AS COSTTYPE,
                    -- Determine visit type
                    CASE 
                        WHEN "VisitStartTime" IS NULL THEN ''Scheduled''
                        WHEN "Billed" != ''yes'' THEN ''Confirmed''
                        WHEN "Billed" = ''yes'' THEN ''Billed''
                    END AS VISITTYPE,
                    -- Calculate overlap amount
                    CASE 
                        WHEN "BilledRateMinute" > 0 AND "ShVTSTTime" IS NOT NULL AND "ShVTENTime" IS NOT NULL 
                            AND "CShVTSTTime" IS NOT NULL AND "CShVTENTime" IS NOT NULL
                            THEN GREATEST(0, 
                                LEAST(
                                    TIMESTAMPDIFF(MINUTE, "ShVTSTTime", "ShVTENTime"),
                                    TIMESTAMPDIFF(MINUTE, "CShVTSTTime", "CShVTENTime"),
                                    TIMESTAMPDIFF(MINUTE, 
                                        GREATEST("ShVTSTTime", "CShVTSTTime"), 
                                        LEAST("ShVTENTime", "CShVTENTime")
                                    )
                                )
                            ) * "BilledRateMinute"
                        ELSE 0 
                    END AS OVERLAP_AMOUNT
                FROM (
                    -- Pre-filtered and deduplicated conflicts with all computations in one pass
                    SELECT 
                        V1."CONFLICTID",
                        V1."VisitID",
                        V1."ConVisitID",
                        V1."ShVTSTTime",
                        V1."ShVTENTime",
                        V1."CShVTSTTime",
                        V1."CShVTENTime",
                        V1."BilledRateMinute",
                        V1."StatusFlag",
                        V1."Billed",
                        V1."VisitStartTime",
                        V1."SameSchTimeFlag",
                        V1."SameVisitTimeFlag",
                        V1."SchAndVisitTimeSameFlag",
                        V1."SchOverAnotherSchTimeFlag",
                        V1."VisitTimeOverAnotherVisitTimeFlag",
                        V1."SchTimeOverVisitTimeFlag",
                        V1."DistanceFlag",
                        V1."InServiceFlag",
                        V1."PTOFlag",
                        -- Determine which PayerId this conflict belongs to (pre-computed for performance)
                        CASE 
                            WHEN V1."PayerID" IN (SELECT APID FROM PAYER_LIST) THEN V1."PayerID"
                            WHEN V1."ConPayerID" IN (SELECT APID FROM PAYER_LIST) THEN V1."ConPayerID"
                            ELSE NULL
                        END AS PROCESSING_PAYERID,
                        -- Create Boolean flag for PTO-only conflicts (modularized approach)
                        CASE 
                            WHEN V1."PTOFlag" = ''Y'' 
                                AND V1."SameSchTimeFlag" = ''N'' 
                                AND V1."SameVisitTimeFlag" = ''N'' 
                                AND V1."SchAndVisitTimeSameFlag" = ''N'' 
                                AND V1."SchOverAnotherSchTimeFlag" = ''N'' 
                                AND V1."VisitTimeOverAnotherVisitTimeFlag" = ''N'' 
                                AND V1."SchTimeOverVisitTimeFlag" = ''N'' 
                                AND V1."DistanceFlag" = ''N'' 
                                AND V1."InServiceFlag" = ''N'' THEN 1
                            ELSE 0
                        END AS IS_PTO_ONLY_CONFLICT,
                        -- Efficient deduplication using window function
                        ROW_NUMBER() OVER (
                            PARTITION BY 
                                CASE 
                                    WHEN V1."PayerID" IN (SELECT APID FROM PAYER_LIST) THEN V1."PayerID"
                                    WHEN V1."ConPayerID" IN (SELECT APID FROM PAYER_LIST) THEN V1."ConPayerID"
                                    ELSE NULL
                                END,
                                CASE 
                                    WHEN V1."VisitID" <= V1."ConVisitID" THEN V1."VisitID" || ''|'' || V1."ConVisitID"
                                    ELSE V1."ConVisitID" || ''|'' || V1."VisitID"
                                END
                            ORDER BY V1."CONFLICTID"
                        ) as rn
                    FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
                    INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2 
                        ON V2."CONFLICTID" = V1."CONFLICTID"
                    WHERE (V1."PayerID" IN (SELECT APID FROM PAYER_LIST) OR V1."ConPayerID" IN (SELECT APID FROM PAYER_LIST))
                        -- Pre-filter PTO-only conflicts for performance
                        AND NOT (V1."PTOFlag" = ''Y'' 
                            AND V1."SameSchTimeFlag" = ''N'' 
                            AND V1."SameVisitTimeFlag" = ''N'' 
                            AND V1."SchAndVisitTimeSameFlag" = ''N'' 
                            AND V1."SchOverAnotherSchTimeFlag" = ''N'' 
                            AND V1."VisitTimeOverAnotherVisitTimeFlag" = ''N'' 
                            AND V1."SchTimeOverVisitTimeFlag" = ''N'' 
                            AND V1."DistanceFlag" = ''N'' 
                            AND V1."InServiceFlag" = ''N'')
                ) AS PRE_FILTERED_CONFLICTS
                WHERE rn = 1  -- Keep only the first occurrence of each conflict pair
                    AND PROCESSING_PAYERID IS NOT NULL
            ),
            AGGREGATED_DATA AS (
                -- Aggregate the data by payer, conflict type, status, cost type, and visit type
                SELECT 
                    "PROCESSING_PAYERID" AS PAYERID,
                    CURRENT_DATE() AS CRDATEUNIQUE,
                    CONTYPE,
                    CONTYPEDESC,
                    "StatusFlag" AS STATUSFLAG,
                    COSTTYPE,
                    VISITTYPE,
                    COUNT(*) AS CO_TO,
                    0 AS CO_SP,
                    SUM(OVERLAP_AMOUNT) AS CO_OP,
                    SUM(CASE WHEN "StatusFlag" IN (''R'', ''D'') THEN OVERLAP_AMOUNT ELSE 0 END) AS CO_FP
                FROM CONFLICT_ANALYSIS
                WHERE CONTYPE IS NOT NULL
                GROUP BY 
                    "PROCESSING_PAYERID",
                    CONTYPE,
                    CONTYPEDESC,
                    "StatusFlag",
                    COSTTYPE,
                    VISITTYPE
            )
            SELECT 
                PAYERID,
                CRDATEUNIQUE,
                CONTYPE,
                CONTYPEDESC,
                STATUSFLAG,
                COSTTYPE,
                VISITTYPE,
                CO_TO,
                CO_SP,
                CO_OP,
                CO_FP
            FROM AGGREGATED_DATA
        `;
        
        // Execute the optimized query
        var result = snowflake.execute({sqlText: optimizedQuery});
        
        // Get the number of rows inserted
        var rowCountQuery = `SELECT COUNT(*) FROM CONFLICTREPORT_SANDBOX.PUBLIC.PAYER_DASHBOARD_CON_TYP_NEW_CALC`;
        var rowCountResult = snowflake.execute({sqlText: rowCountQuery});
        var rowCount = 0;
        if (rowCountResult.next()) {
            rowCount = rowCountResult.getColumnValue(1);
        }
        
        return `Successfully processed all payers using optimized SQL and inserted ${rowCount} records into PAYER_DASHBOARD_CON_TYP_NEW_CALC table.`;
        
    } catch (error) {
        return `Error: ${error.message}`;
    }
$$; 