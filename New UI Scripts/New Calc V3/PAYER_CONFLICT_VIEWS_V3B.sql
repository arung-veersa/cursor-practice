
-- COMMON view: shared joins, filters, computed flags, classifications, and amounts
CREATE OR REPLACE VIEW CONFLICTREPORT_SANDBOX.PUBLIC.V_PAYER_CONFLICTS_COMMON AS
WITH PAYER_LIST AS (
    SELECT P."Payer Id" AS APID
    FROM ANALYTICS_SANDBOX.BI.DIMPAYER AS P 
    WHERE P."Is Active" = TRUE 
      AND P."Is Demo" = FALSE
),
BASE AS (
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
        V1.BILLABLEMINUTESFULLSHIFT,
        V1.BILLABLEMINUTESOVERLAP,
        GRP."GROUP_SIZE" AS "GROUP_SIZE",
        V1."ProviderID",
        V1."ServiceCode",
        V1."P_PCounty",
        V1."PA_PCounty"
    FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
    INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2 
        ON V2."CONFLICTID" = V1."CONFLICTID"
    INNER JOIN (
        SELECT "GroupID", COUNT(DISTINCT "CONFLICTID") AS "GROUP_SIZE" 
        FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS
        GROUP BY "GroupID"
    ) GRP ON GRP."GroupID" = V1."GroupID"
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
FEATURES AS (
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
        COALESCE("P_PCounty", "PA_PCounty") AS COUNTY
    FROM BASE
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
            WHEN "BilledRateMinute" > 0 THEN
                CASE
                    WHEN BILLABLEMINUTESFULLSHIFT IS NOT NULL THEN BILLABLEMINUTESFULLSHIFT * "BilledRateMinute"
                    WHEN "ShVTSTTime" IS NOT NULL AND "ShVTENTime" IS NOT NULL THEN TIMESTAMPDIFF(MINUTE, "ShVTSTTime", "ShVTENTime") * "BilledRateMinute"
                    ELSE 0
                END
            ELSE 0
        END AS FULL_SHIFT_AMOUNT,
        CASE
            WHEN "BilledRateMinute" > 0 THEN
                CASE
                    WHEN BILLABLEMINUTESOVERLAP IS NOT NULL AND ("GROUP_SIZE" <= 2 OR "DistanceFlag" = 'Y') THEN BILLABLEMINUTESOVERLAP * "BilledRateMinute"
                    WHEN "ShVTSTTime" IS NOT NULL AND "ShVTENTime" IS NOT NULL 
                         AND "CShVTSTTime" IS NOT NULL AND "CShVTENTime" IS NOT NULL THEN
                        GREATEST(0,
                            TIMESTAMPDIFF(
                                MINUTE,
                                GREATEST("ShVTSTTime", "CShVTSTTime"),
                                LEAST("ShVTENTime", "CShVTENTime")
                            )
                        ) * "BilledRateMinute"
                    ELSE 0
                END
            ELSE 0
        END AS OVERLAP_AMOUNT,
        CASE WHEN "Billed" = 'yes' THEN 'Recovery' ELSE 'Avoidance' END AS COSTTYPE,
        CASE 
            WHEN "VisitStartTime" IS NULL THEN 'Scheduled'
            WHEN "Billed" != 'yes' THEN 'Confirmed'
            WHEN "Billed" = 'yes' THEN 'Billed'
        END AS VISITTYPE,
        CASE WHEN "VisitStartTime" IS NULL THEN 'NULL' ELSE 'NOT NULL' END AS "VisitStartTime_Status",
        CASE WHEN "PayerID" IN (SELECT APID FROM PAYER_LIST) THEN TRUE ELSE FALSE END AS PAYER_ACTIVE,
        CASE WHEN "ConPayerID" IN (SELECT APID FROM PAYER_LIST) THEN TRUE ELSE FALSE END AS CONPAYER_ACTIVE
    FROM FEATURES
)
SELECT
    ID,
    "Contract",
    "ConContract",
    "PayerID",
    "ConPayerID",
    "ProviderID",
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
    "StatusFlag",
    "Billed",
    "VisitStartTime",
    "ServiceCode",
    HAS_TIME_OVERLAP,
    HAS_TIME_DISTANCE,
    HAS_IN_SERVICE,
    COUNTY,
    CONTYPE,
    FULL_SHIFT_AMOUNT,
    OVERLAP_AMOUNT,
    COSTTYPE,
    VISITTYPE,
    "VisitStartTime_Status",
    PAYER_ACTIVE,
    CONPAYER_ACTIVE
FROM CLASSIFIED
WHERE CONTYPE IS NOT NULL;


-- LIST view: includes conflicts where either side payer is active; no dedup
CREATE OR REPLACE VIEW CONFLICTREPORT_SANDBOX.PUBLIC.V_PAYER_CONFLICTS_LIST AS
SELECT
    *
FROM CONFLICTREPORT_SANDBOX.PUBLIC.V_PAYER_CONFLICTS_COMMON
WHERE (PAYER_ACTIVE OR CONPAYER_ACTIVE);


-- AGGREGATED view: limits to payer side and dedups reverse entries only when PayerID = ConPayerID
CREATE OR REPLACE VIEW CONFLICTREPORT_SANDBOX.PUBLIC.V_PAYER_CONFLICTS_AGGREGATED_COMMON AS
WITH SOURCE AS (
    SELECT *
    FROM CONFLICTREPORT_SANDBOX.PUBLIC.V_PAYER_CONFLICTS_COMMON
    WHERE PAYER_ACTIVE
),
DEDUP AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY 
                "PayerID",
                CASE
                    WHEN "PayerID" = "ConPayerID" THEN
                        CASE
                            WHEN "AppVisitID" <= "ConAppVisitID" THEN "AppVisitID" || '|' || "ConAppVisitID"
                            ELSE "ConAppVisitID" || '|' || "AppVisitID"
                        END
                    ELSE
                        "AppVisitID" || '|' || "ConAppVisitID"
                END
            ORDER BY "CONFLICTID" DESC
        ) AS rn
    FROM SOURCE
)
SELECT 
    *
FROM DEDUP