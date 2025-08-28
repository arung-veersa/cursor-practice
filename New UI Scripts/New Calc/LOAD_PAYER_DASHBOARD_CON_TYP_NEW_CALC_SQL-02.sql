-- Set session variables for configurable payer ID
SET TARGET_PAYER_ID = '83828a9e-a1ad-4d29-bc4f-24be24db126f';  -- EverCare
-- SET TARGET_PAYER_ID = '042cb099-168b-4717-9bd0-936848b4fab1';  -- Able Homecare (uncomment to use)

-- Clear existing data
TRUNCATE TABLE CONFLICTREPORT_SANDBOX.PUBLIC.PAYER_DASHBOARD_CON_TYP_NEW_CALC;

-- Insert aggregated data for all payers in a single SQL statement
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
COMMON_FIELDS AS (
    -- Common fields and joins - defined once to avoid duplication
    SELECT 
        V1."CRDATEUNIQUE",
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
        V1."PayerID",
        V1."ConPayerID"
    FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
    INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2 
        ON V2."CONFLICTID" = V1."CONFLICTID"
    WHERE (V1."PayerID" IN (SELECT APID FROM PAYER_LIST) 
           OR V1."ConPayerID" IN (SELECT APID FROM PAYER_LIST))
        -- Pre-filter PTO-only conflicts for performance (defined once)
        AND NOT (V1."PTOFlag" = 'Y' 
            AND V1."SameSchTimeFlag" = 'N' 
            AND V1."SameVisitTimeFlag" = 'N' 
            AND V1."SchAndVisitTimeSameFlag" = 'N' 
            AND V1."SchOverAnotherSchTimeFlag" = 'N' 
            AND V1."VisitTimeOverAnotherVisitTimeFlag" = 'N' 
            AND V1."SchTimeOverVisitTimeFlag" = 'N' 
            AND V1."DistanceFlag" = 'N' 
            AND V1."InServiceFlag" = 'N')
),
PAYER_RECORDS AS (
    -- Create records for PayerID when PayerID is active
    SELECT 
        *,
        V1."PayerID" AS PROCESSING_PAYERID,
        -- This payer is the primary payer (owns the visit) - always priority 1
        1 AS payer_priority,
        ROW_NUMBER() OVER (
            PARTITION BY 
                CASE 
                    WHEN V1."VisitID" <= V1."ConVisitID" THEN V1."VisitID" || '|' || V1."ConVisitID"
                    ELSE V1."ConVisitID" || '|' || V1."VisitID"
                END
            ORDER BY 
                payer_priority,  -- Primary payer gets priority 1
                V1."CONFLICTID" DESC  -- Tie-breaker: higher CONFLICTID gets priority
        ) as rn
    FROM COMMON_FIELDS V1
    WHERE V1."PayerID" IN (SELECT APID FROM PAYER_LIST)
    
    UNION ALL
    
    -- Create records for ConPayerID when ConPayerID is active and different from PayerID
    SELECT 
        *,
        V1."ConPayerID" AS PROCESSING_PAYERID,
        -- This payer is the conflicting party (doesn't own the visit) - gets lower priority
        2 AS payer_priority,
        ROW_NUMBER() OVER (
            PARTITION BY 
                CASE 
                    WHEN V1."VisitID" <= V1."ConVisitID" THEN V1."VisitID" || '|' || V1."ConVisitID"
                    ELSE V1."ConVisitID" || '|' || V1."VisitID"
                END
            ORDER BY 
                payer_priority,  -- Primary payer (1) gets priority over conflicting payer (2)
                V1."CONFLICTID" DESC  -- Tie-breaker: higher CONFLICTID gets priority
        ) as rn
    FROM COMMON_FIELDS V1
    WHERE V1."ConPayerID" IN (SELECT APID FROM PAYER_LIST)
),
CONFLICT_ANALYSIS AS (
    -- Combined CTE: Pre-filter, deduplicate, and analyze conflicts in one pass
    SELECT 
        "CRDATEUNIQUE",
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
            WHEN ("SameSchTimeFlag" = 'Y' OR "SameVisitTimeFlag" = 'Y' OR "SchAndVisitTimeSameFlag" = 'Y' 
                  OR "SchOverAnotherSchTimeFlag" = 'Y' OR "VisitTimeOverAnotherVisitTimeFlag" = 'Y' 
                  OR "SchTimeOverVisitTimeFlag" = 'Y') THEN 1
            ELSE 0
        END AS HAS_TIME_OVERLAP,
        CASE WHEN "DistanceFlag" = 'Y' THEN 1 ELSE 0 END AS HAS_TIME_DISTANCE,
        CASE WHEN "InServiceFlag" = 'Y' THEN 1 ELSE 0 END AS HAS_IN_SERVICE,
        -- Determine conflict type using modular Boolean flags
        CASE 
            WHEN HAS_TIME_OVERLAP = 1 AND HAS_TIME_DISTANCE = 0 AND HAS_IN_SERVICE = 0 THEN 'only_to'
            WHEN HAS_TIME_OVERLAP = 0 AND HAS_TIME_DISTANCE = 1 AND HAS_IN_SERVICE = 0 THEN 'only_td'
            WHEN HAS_TIME_OVERLAP = 0 AND HAS_TIME_DISTANCE = 0 AND HAS_IN_SERVICE = 1 THEN 'only_is'
            WHEN HAS_TIME_OVERLAP = 1 AND HAS_TIME_DISTANCE = 1 AND HAS_IN_SERVICE = 0 THEN 'both_to_td'
            WHEN HAS_TIME_OVERLAP = 1 AND HAS_TIME_DISTANCE = 0 AND HAS_IN_SERVICE = 1 THEN 'both_to_is'
            WHEN HAS_TIME_OVERLAP = 0 AND HAS_TIME_DISTANCE = 1 AND HAS_IN_SERVICE = 1 THEN 'both_td_is'
            WHEN HAS_TIME_OVERLAP = 1 AND HAS_TIME_DISTANCE = 1 AND HAS_IN_SERVICE = 1 THEN 'all_to_td_is'
            ELSE NULL
        END AS CONTYPE,
        -- Determine conflict type description using the same Boolean flags
        CASE 
            WHEN HAS_TIME_OVERLAP = 1 AND HAS_TIME_DISTANCE = 0 AND HAS_IN_SERVICE = 0 THEN 'Time Overlap Only'
            WHEN HAS_TIME_OVERLAP = 0 AND HAS_TIME_DISTANCE = 1 AND HAS_IN_SERVICE = 0 THEN 'Time Distance Only'
            WHEN HAS_TIME_OVERLAP = 0 AND HAS_TIME_DISTANCE = 0 AND HAS_IN_SERVICE = 1 THEN 'In Service Only'
            WHEN HAS_TIME_OVERLAP = 1 AND HAS_TIME_DISTANCE = 1 AND HAS_IN_SERVICE = 0 THEN 'Time Overlap and Time Distance'
            WHEN HAS_TIME_OVERLAP = 1 AND HAS_TIME_DISTANCE = 0 AND HAS_IN_SERVICE = 1 THEN 'Time Overlap and In Service'
            WHEN HAS_TIME_OVERLAP = 0 AND HAS_TIME_DISTANCE = 1 AND HAS_IN_SERVICE = 1 THEN 'Time Distance and In Service'
            WHEN HAS_TIME_OVERLAP = 1 AND HAS_TIME_DISTANCE = 1 AND HAS_IN_SERVICE = 1 THEN 'All Three (Time Overlap, Time Distance, and In Service)'
            ELSE NULL
        END AS CONTYPEDESC,
        -- Determine cost type
        CASE WHEN "Billed" = 'yes' THEN 'Recovery' ELSE 'Avoidance' END AS COSTTYPE,
        -- Determine visit type
        CASE 
            WHEN "VisitStartTime" IS NULL THEN 'Scheduled'
            WHEN "Billed" != 'yes' THEN 'Confirmed'
            WHEN "Billed" = 'yes' THEN 'Billed'
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
    FROM PAYER_RECORDS
    WHERE rn = 1  -- Keep only the first occurrence of each conflict pair
        AND PROCESSING_PAYERID IS NOT NULL
),
AGGREGATED_DATA AS (
    -- Aggregate the data by payer, conflict type, status, cost type, and visit type
    SELECT 
        "PROCESSING_PAYERID" AS PAYERID,
        CRDATEUNIQUE,
        CONTYPE,
        CONTYPEDESC,
        "StatusFlag" AS STATUSFLAG,
        COSTTYPE,
        VISITTYPE,
        COUNT(*) AS CO_TO,
        0 AS CO_SP,
        SUM(OVERLAP_AMOUNT) AS CO_OP,
        SUM(CASE WHEN "StatusFlag" IN ('R', 'D') THEN OVERLAP_AMOUNT ELSE 0 END) AS CO_FP
    FROM CONFLICT_ANALYSIS
    WHERE CONTYPE IS NOT NULL
    GROUP BY 
        "PROCESSING_PAYERID",
        CRDATEUNIQUE,
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
FROM AGGREGATED_DATA;
