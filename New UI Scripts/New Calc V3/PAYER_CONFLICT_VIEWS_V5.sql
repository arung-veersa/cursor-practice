-- CONFLICTREPORT_SANDBOX.PUBLIC.V_PAYER_CONFLICTS_COMMON source

create or replace view CONFLICTREPORT_SANDBOX.PUBLIC.TMP_AG_V_PAYER_CONFLICTS_COMMON AS
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
        V1."VisitEndTime",
        V1."SchStartTime",
        V1."SchEndTime",
        V1."EVVStartTime",
        V1."EVVEndTime",
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
        V1."OfficeID",
        V1."BilledHours",
        V1."BilledDate",
        V1."LastUpdatedBy",
        V1."LastUpdatedDate",
        V1."PA_PAdmissionID",
        V1."PA_PFName",
        V1."PA_PLName",
        V1."PA_PMedicaidNumber",
        V1."AgencyContact",
        V1."AgencyPhone",
        GRP."GROUP_SIZE" AS "GROUP_SIZE",
        V1."ProviderID",
        V1."ServiceCode",
        V1."P_PCounty",
        V1."PA_PCounty",
        V1."CaregiverID",
        V1."AppCaregiverID",
        V1."VisitDate",
        V1."AideCode",
        V1."AideFName",
        V1."AideLName",
        V1."AideSSN",
        V1."G_CRDATEUNIQUE",
        V1."FlagForReview",
        V1."PA_PatientID",
        V1."PA_PName",
        DO."Office Name" AS "Office",
		--new added fields
		V1."EVVType",
		V1."DistanceMilesFromLatLng",
		V1."PA_PStatus",
		V1."IsMissed",
		V1."MissedVisitReason",
		V2."NoResponseFlag",
		V1."TotalBilledAmount",
		V2."StatusFlag" AS OrgParentStatusFlag
				
    FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
    INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2 
        ON V2."CONFLICTID" = V1."CONFLICTID"
    INNER JOIN (
        SELECT "GroupID", COUNT(DISTINCT "CONFLICTID") AS "GROUP_SIZE" 
        FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS
        GROUP BY "GroupID"
    ) GRP ON GRP."GroupID" = V1."GroupID"
    INNER JOIN PAYER_LIST PL ON PL.APID = V1."PayerID"
    LEFT JOIN ANALYTICS_SANDBOX.BI.DIMOFFICE AS DO 
        ON DO."Office Id" = V1."OfficeID"
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
		CASE
			WHEN BILLABLEMINUTESFULLSHIFT IS NOT NULL THEN BILLABLEMINUTESFULLSHIFT
			WHEN "ShVTSTTime" IS NOT NULL AND "ShVTENTime" IS NOT NULL THEN TIMESTAMPDIFF(MINUTE, "ShVTSTTime", "ShVTENTime")
			ELSE 0
		END AS FULL_SHIFT_MIN,
		CASE
			WHEN BILLABLEMINUTESOVERLAP IS NOT NULL AND ("GROUP_SIZE" <= 2 OR "DistanceFlag" = 'Y') THEN BILLABLEMINUTESOVERLAP
			WHEN "ShVTSTTime" IS NOT NULL AND "ShVTENTime" IS NOT NULL 
				AND "CShVTSTTime" IS NOT NULL AND "CShVTENTime" IS NOT NULL THEN
				GREATEST(0,
					TIMESTAMPDIFF(
						MINUTE,
						GREATEST("ShVTSTTime", "CShVTSTTime"),
						LEAST("ShVTENTime", "CShVTENTime")
					)
				)
			ELSE 0
		END AS OVERLAP_MIN
    FROM BASE
),
CLASSIFIED AS (
    SELECT
        *,
        COALESCE("P_PCounty", "PA_PCounty") AS COUNTY,
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
            WHEN HAS_TIME_OVERLAP = 1 THEN '100'
            WHEN HAS_TIME_DISTANCE = 1 THEN '7'
            WHEN HAS_IN_SERVICE = 1 THEN '8'
            ELSE NULL
        END AS CONTYPEOLD,

        CASE
            WHEN "BilledRateMinute" > 0 THEN
				FULL_SHIFT_MIN * "BilledRateMinute"
            ELSE 0
        END AS FULL_SHIFT_AMOUNT,
        CASE
            WHEN "BilledRateMinute" > 0 THEN
                OVERLAP_MIN * "BilledRateMinute"
            ELSE 0
        END AS OVERLAP_AMOUNT,
		CASE WHEN "StatusFlag" = 'R' THEN OVERLAP_AMOUNT ELSE 0 END AS FINAL_AMOUNT,
        CASE WHEN "Billed" = 'yes' THEN 'Recovery' ELSE 'Avoidance' END AS COSTTYPE,
        CASE 
            WHEN "VisitStartTime" IS NULL THEN 'Scheduled'
            WHEN "Billed" != 'yes' THEN 'Confirmed'
            WHEN "Billed" = 'yes' THEN 'Billed'
        END AS VISITTYPE,
        CASE WHEN "VisitStartTime" IS NULL THEN 'NULL' ELSE 'NOT NULL' END AS "VisitStartTime_Status",
        TRUE AS PAYER_ACTIVE,
        DATEDIFF(day, G_CRDATEUNIQUE, CURRENT_DATE) AS "AgingDays",
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
        ) AS RN
    FROM FEATURES
)
SELECT
    *
FROM CLASSIFIED
WHERE CONTYPE IS NOT NULL;

-- CONFLICTREPORT_SANDBOX.PUBLIC.V_PAYER_CONFLICTS_LIST source

create or replace view CONFLICTREPORT_SANDBOX.PUBLIC.TMP_AG_V_PAYER_CONFLICTS_LIST AS
SELECT 
    "ID",
    "GroupID",
    "SSN",
	"ProviderID",
    "CaregiverID",
    "AppCaregiverID",
    "VisitID",
    "AppVisitID",
    "VisitDate",
    "AideCode",
    "AideFName",
    "AideLName",
    COALESCE("AideSSN", "SSN") AS "AideSSN",
    "G_CRDATEUNIQUE" AS "CRDATEUNIQUE",
    "PayerID",
    "Contract",
    CONTYPEOLD,
    "FlagForReview",
    "PA_PatientID",
    "PA_PName",
    RN,
    "ProviderName",
    "Office",
    "AgingDays",
    "BilledHours",
    "BilledDate",
    FULL_SHIFT_AMOUNT as "ShiftPrice" ,
    OVERLAP_AMOUNT as "OverlapPrice",
    FINAL_AMOUNT as "FinalPrice",
    "StatusFlag",
    "VisitStartTime",
    "VisitEndTime",
    "ShVTSTTime",
    "ShVTENTime",
    "InServiceFlag",
    "LastUpdatedBy",
    "LastUpdatedDate",
    "PA_PAdmissionID",
    "PA_PFName",
    "PA_PLName",
    "PA_PMedicaidNumber",
    "AgencyContact",
    "AgencyPhone",
	"BilledRateMinute" * 60 AS "BilledRate",
    FULL_SHIFT_MIN / 60 AS "sch_hours",
    -- NEW FIELDS:
    "SchStartTime",
    "SchEndTime",
    "EVVStartTime",
    "EVVEndTime",
    FULL_SHIFT_MIN AS "TotalMinutes",
    OVERLAP_MIN AS "OverlapTime",
    "SameSchTimeFlag",
    "SameVisitTimeFlag",
    "SchAndVisitTimeSameFlag",
    "SchOverAnotherSchTimeFlag",
    "VisitTimeOverAnotherVisitTimeFlag",
    "SchTimeOverVisitTimeFlag",
    "DistanceFlag",
    "PTOFlag",
    "OfficeID",
    "CONFLICTID",
    "PayerID" AS "APID"
FROM CONFLICTREPORT_SANDBOX.PUBLIC.TMP_AG_V_PAYER_CONFLICTS_COMMON
WHERE RN = 1
ORDER BY "GroupID" DESC;

