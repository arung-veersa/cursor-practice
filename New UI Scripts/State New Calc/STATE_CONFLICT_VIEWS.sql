-- View definitions for aggegator conflict analytics

-- Base view: includes all records (with duplicates), computed flags, classifications, and amounts
CREATE OR REPLACE VIEW CONFLICTREPORT_SANDBOX.PUBLIC.VIEW_STATE_CONFLICT_BASE AS
WITH COMMON_FIELDS AS (
    SELECT 
        V1.ID,
        V1."Contract",
        V1."ConContract",
        V1."ProviderName",
        V1."SSN",
        V1."CRDATEUNIQUE",
        V1."GroupID",
        V1."CONFLICTID",
        V1."AppVisitID",
        V1."ConAppVisitID",
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
        V1."ConPayerID",
        V1."ProviderID",
        V1."ConProviderID",
        V1."ServiceCode",
        V1."ConServiceCode",
        V1."P_PCounty",
        V1."PA_PCounty",
        V1."ConP_PCounty",
        V1."ConPA_PCounty"
    FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
    INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2 
        ON V2."CONFLICTID" = V1."CONFLICTID"
    WHERE NOT (V1."PTOFlag" = 'Y'
        AND V1."SameSchTimeFlag" = 'N'
        AND V1."SameVisitTimeFlag" = 'N'
        AND V1."SchAndVisitTimeSameFlag" = 'N'
        AND V1."SchOverAnotherSchTimeFlag" = 'N'
        AND V1."VisitTimeOverAnotherVisitTimeFlag" = 'N'
        AND V1."SchTimeOverVisitTimeFlag" = 'N'
        AND V1."DistanceFlag" = 'N'
        AND V1."InServiceFlag" = 'N')
),
PAYER_LIST AS (
    SELECT DISTINCT V1."PayerID" AS APID
    FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
    INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2 
        ON V2."CONFLICTID" = V1."CONFLICTID"
    INNER JOIN ANALYTICS_SANDBOX.BI.DIMPAYER AS P 
        ON P."Payer Id" = V1."PayerID"
    WHERE P."Is Active" = TRUE 
      AND P."Is Demo" = FALSE
),
PAYER_RECORDS AS (
    SELECT 
        *,
        "PayerID" AS PROCESSING_PAYERID,
        1 AS priority_level
    FROM COMMON_FIELDS
    WHERE "PayerID" IN (SELECT APID FROM PAYER_LIST)
    
    UNION ALL
    
    SELECT 
        *,
        "ConPayerID" AS PROCESSING_PAYERID,
        2 AS priority_level
    FROM COMMON_FIELDS
    WHERE "ConPayerID" IN (SELECT APID FROM PAYER_LIST)
      AND "ConPayerID" != "PayerID"
),
DEDUPLICATED_SOURCE AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (
            PARTITION BY 
                CASE
                    WHEN "AppVisitID" <= "ConAppVisitID"
                        THEN "AppVisitID" || '|' || "ConAppVisitID"
                    ELSE "ConAppVisitID" || '|' || "AppVisitID"
                END
            ORDER BY 
                priority_level,
                "CONFLICTID" DESC
        ) AS rn
    FROM PAYER_RECORDS
),
ENRICHED AS (
    SELECT
        *,
        CASE 
            WHEN ("SameSchTimeFlag" = 'Y' OR "SameVisitTimeFlag" = 'Y' OR "SchAndVisitTimeSameFlag" = 'Y' 
                  OR "SchOverAnotherSchTimeFlag" = 'Y' OR "VisitTimeOverAnotherVisitTimeFlag" = 'Y' 
                  OR "SchTimeOverVisitTimeFlag" = 'Y') THEN 1
            ELSE 0
        END AS HAS_TIME_OVERLAP,
        CASE WHEN "DistanceFlag" = 'Y' THEN 1 ELSE 0 END AS HAS_TIME_DISTANCE,
        CASE WHEN "InServiceFlag" = 'Y' THEN 1 ELSE 0 END AS HAS_IN_SERVICE,
        CASE WHEN priority_level = 1 THEN "ProviderID" ELSE "ConProviderID" END AS PROCESSING_PROVIDERID,
        CASE WHEN priority_level = 1 THEN COALESCE("P_PCounty", "PA_PCounty") ELSE COALESCE("ConP_PCounty", "ConPA_PCounty") END AS PROCESSING_COUNTY,
        CASE WHEN priority_level = 1 THEN "ServiceCode" ELSE "ConServiceCode" END AS PROCESSING_SERVICECODE
    FROM DEDUPLICATED_SOURCE
),
CLASSIFIED AS (
    SELECT
        *,
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
        CASE 
            WHEN CONTYPE = 'only_to' THEN 'Time Overlap Only'
            WHEN CONTYPE = 'only_td' THEN 'Time Distance Only'
            WHEN CONTYPE = 'only_is' THEN 'In Service Only'
            WHEN CONTYPE = 'both_to_td' THEN 'Time Overlap and Time Distance'
            WHEN CONTYPE = 'both_to_is' THEN 'Time Overlap and In Service'
            WHEN CONTYPE = 'both_td_is' THEN 'Time Distance and In Service'
            WHEN CONTYPE = 'all_to_td_is' THEN 'All Three (Time Overlap, Time Distance, and In Service)'
            ELSE NULL
        END AS CONTYPEDESC,
        CASE 
            WHEN "BilledRateMinute" > 0 AND "ShVTSTTime" IS NOT NULL AND "ShVTENTime" IS NOT NULL 
            THEN TIMESTAMPDIFF(MINUTE, "ShVTSTTime", "ShVTENTime") * "BilledRateMinute"
            ELSE 0 
        END AS FULL_SHIFT_AMOUNT,
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
    FROM ENRICHED
)
SELECT
    ID,
    "Contract",
    "ConContract",
    "ProviderName",
    "SSN",
    "CRDATEUNIQUE",
    "GroupID",
    "CONFLICTID",
    "AppVisitID",
    "ConAppVisitID",
    "VisitID",
    "ConVisitID",
    "ShVTSTTime",
    "ShVTENTime",
    "CShVTSTTime",
    "CShVTENTime",
    "BilledRateMinute",
    CASE WHEN rn = 1 THEN '' ELSE 'DUPLICATE' END AS "Duplicate_Status",
    "StatusFlag",
    CASE WHEN "Billed" = 'yes' THEN 'Recovery' ELSE 'Avoidance' END AS COSTTYPE,
    CASE 
        WHEN "VisitStartTime" IS NULL THEN 'Scheduled'
        WHEN "Billed" != 'yes' THEN 'Confirmed'
        WHEN "Billed" = 'yes' THEN 'Billed'
    END AS VISITTYPE,
    CASE WHEN "VisitStartTime" IS NULL THEN 'NULL' ELSE 'NOT NULL' END AS "VisitStartTime_Status",
    HAS_TIME_OVERLAP,
    HAS_TIME_DISTANCE,
    HAS_IN_SERVICE,
    CONTYPE,
    CONTYPEDESC,
    rn AS "Row_Number",
    PROCESSING_PAYERID,
    PROCESSING_PROVIDERID,
    PROCESSING_COUNTY,
    PROCESSING_SERVICECODE,
    FULL_SHIFT_AMOUNT,
    OVERLAP_AMOUNT
FROM CLASSIFIED;

-- Detail view: deduplicated events (rn = 1), ready for list pages
CREATE OR REPLACE VIEW CONFLICTREPORT_SANDBOX.PUBLIC.VIEW_STATE_CONFLICT_LIST AS
SELECT
    *
FROM CONFLICTREPORT_SANDBOX.PUBLIC.VIEW_STATE_CONFLICT_BASE
WHERE "Row_Number" = 1
  AND CONTYPE IS NOT NULL;

-- Aggregated view: rollups for dashboard KPIs
CREATE OR REPLACE VIEW CONFLICTREPORT_SANDBOX.PUBLIC.VIEW_STATE_CONFLICT_AGGREGATED AS
SELECT 
    PROCESSING_PAYERID AS PAYERID,
    PROCESSING_PROVIDERID AS PROVIDERID,
    CAST("CRDATEUNIQUE" AS DATE) AS CRDATEUNIQUE,
    CONTYPE,
    CASE 
        WHEN CONTYPE = 'only_to' THEN 'Time Overlap Only'
        WHEN CONTYPE = 'only_td' THEN 'Time Distance Only'
        WHEN CONTYPE = 'only_is' THEN 'In Service Only'
        WHEN CONTYPE = 'both_to_td' THEN 'Time Overlap and Time Distance'
        WHEN CONTYPE = 'both_to_is' THEN 'Time Overlap and In Service'
        WHEN CONTYPE = 'both_td_is' THEN 'Time Distance and In Service'
        WHEN CONTYPE = 'all_to_td_is' THEN 'All Three (Time Overlap, Time Distance, and In Service)'
        ELSE NULL
    END AS CONTYPEDESC,
    "StatusFlag" AS STATUSFLAG,
    COSTTYPE,
    VISITTYPE,
    PROCESSING_COUNTY AS COUNTY,
    PROCESSING_SERVICECODE AS SERVICECODE,
    COUNT(*) AS CO_TO,
    SUM(FULL_SHIFT_AMOUNT) AS CO_SP,
    SUM(OVERLAP_AMOUNT) AS CO_OP,
    SUM(CASE WHEN "StatusFlag" IN ('R', 'D') THEN OVERLAP_AMOUNT ELSE 0 END) AS CO_FP
FROM CONFLICTREPORT_SANDBOX.PUBLIC.VIEW_STATE_CONFLICT_LIST
GROUP BY 
    PROCESSING_PAYERID,
    PROCESSING_PROVIDERID,
    CAST("CRDATEUNIQUE" AS DATE),
    CONTYPE,
    "StatusFlag",
    COSTTYPE,
    VISITTYPE,
    PROCESSING_COUNTY,
    PROCESSING_SERVICECODE;