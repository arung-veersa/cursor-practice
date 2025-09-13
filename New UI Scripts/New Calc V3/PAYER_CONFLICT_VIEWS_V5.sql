-- CONFLICTREPORT_SANDBOX.PUBLIC.V_PAYER_CONFLICTS_COMMON source

create or replace view CONFLICTREPORT_SANDBOX.PUBLIC.TMP_AG_V_PAYER_CONFLICTS_COMMON AS
WITH PAYER_LIST AS (
    SELECT P."Payer Id" AS APID
    FROM ANALYTICS_SANDBOX.BI.DIMPAYER AS P 
    WHERE P."Is Active" = TRUE 
      AND P."Is Demo" = FALSE
),
FILTERED_BASE AS (
    -- Single WHERE condition + GROUP_SIZE window function
    SELECT 
        V1.*, 
        V2."NoResponseFlag", 
        V2."StatusFlag" AS "OrgParentStatusFlag",
        COUNT(DISTINCT V1."CONFLICTID") OVER (PARTITION BY V1."GroupID") AS "GROUP_SIZE"
    FROM CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
    INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2 
        ON V2."CONFLICTID" = V1."CONFLICTID"
    INNER JOIN PAYER_LIST PL ON PL.APID = V1."PayerID"
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
DEDUPLICATED AS (
    SELECT *,
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
    FROM FILTERED_BASE
),
BASE AS (
    SELECT 
        -- === PRIMARY IDENTIFIERS ===
        V1.ID,
        V1."CONFLICTID",
        V1."GroupID",
        
        -- === CONTRACT & PROVIDER INFORMATION ===
        V1."PayerID",
        V1."ConPayerID",
        V1."Contract",
        V1."ConContract",
        V1."ProviderID",
        V1."ProviderName",
        V1."AgencyContact",
        V1."AgencyPhone",
        
        -- === VISIT IDENTIFIERS ===
        V1."AppVisitID",
        V1."ConAppVisitID",
        V1."VisitID",
        V1."ConVisitID",
        
        -- === CAREGIVER INFORMATION ===
        V1."CaregiverID",
        V1."AppCaregiverID",
        V1."AideCode",
        V1."AideFName",
        V1."AideLName",
        V1."AideSSN",
        V1."SSN",
        
        -- === PATIENT INFORMATION ===
        V1."PA_PatientID",
        V1."PA_PName",
        V1."PA_PAdmissionID",
        V1."PA_PFName",
        V1."PA_PLName",
        V1."PA_PMedicaidNumber",
        V1."PA_PStatus",
        V1."PA_PCounty",
        V1."P_PCounty",
        
        -- === TIME INFORMATION ===
        V1."VisitDate",
        V1."VisitStartTime",
        V1."VisitEndTime",
        V1."SchStartTime",
        V1."SchEndTime",
        V1."EVVStartTime",
        V1."EVVEndTime",
        V1."ShVTSTTime",
        V1."ShVTENTime",
        V1."CShVTSTTime",
        V1."CShVTENTime",
        
        -- === BILLING INFORMATION ===
        V1."BilledRateMinute",
        V1."BilledHours",
        V1."BilledDate",
        V1."TotalBilledAmount",
        V1."Billed",
        V1.BILLABLEMINUTESFULLSHIFT,
        V1.BILLABLEMINUTESOVERLAP,
        
        -- === CONFLICT FLAGS ===
        V1."SameSchTimeFlag",
        V1."SameVisitTimeFlag",
        V1."SchAndVisitTimeSameFlag",
        V1."SchOverAnotherSchTimeFlag",
        V1."VisitTimeOverAnotherVisitTimeFlag",
        V1."SchTimeOverVisitTimeFlag",
        V1."DistanceFlag",
        V1."InServiceFlag",
        V1."PTOFlag",
        
        -- === STATUS & CONTROL FIELDS ===
        V1."StatusFlag",
        V1."OrgParentStatusFlag",
        V1."FlagForReview",
        V1."IsMissed",
        V1."MissedVisitReason",
        V1."NoResponseFlag",
        V1."ServiceCode",
        V1."EVVType",
        V1."DistanceMilesFromLatLng",
        V1."OfficeID",
        DO."Office Name" AS "Office",
        
        -- === AUDIT FIELDS ===
        V1."LastUpdatedBy",
        V1."LastUpdatedDate",
        V1."CRDATEUNIQUE",
        V1."G_CRDATEUNIQUE",
        
        -- === CALCULATED FIELDS ===
        V1."GROUP_SIZE" AS "GROUP_SIZE",
        V1.RN
				
    FROM DEDUPLICATED AS V1
    LEFT JOIN ANALYTICS_SANDBOX.BI.DIMOFFICE AS DO 
        ON DO."Office Id" = V1."OfficeID"
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
        DATEDIFF(day, G_CRDATEUNIQUE, CURRENT_DATE) AS "AgingDays"
    FROM FEATURES
)
SELECT
    *
FROM CLASSIFIED
WHERE CONTYPE IS NOT NULL;

-- CONFLICTREPORT_SANDBOX.PUBLIC.V_PAYER_CONFLICTS_LIST source

create or replace view CONFLICTREPORT_SANDBOX.PUBLIC.TMP_AG_V_PAYER_CONFLICTS_LIST AS
SELECT 
    -- === PRIMARY IDENTIFIERS ===
    "ID",
    "GroupID",
    "CONFLICTID",
    
    -- === PROVIDER & CONTRACT INFORMATION ===
    "PayerID",
    "PayerID" AS "APID",
    "Contract",
    "ProviderID",
    "ProviderName",
    "AgencyContact",
    "AgencyPhone",
    "OfficeID",
    "Office",

    -- === CAREGIVER INFORMATION ===
    "CaregiverID",
    "AppCaregiverID",
    "AideCode",
    "AideFName",
    "AideLName",
    COALESCE("AideSSN", "SSN") AS "AideSSN",
    "SSN",
    
    -- === PATIENT INFORMATION ===
    "PA_PatientID",
    "PA_PName",
    "PA_PAdmissionID",
    "PA_PFName",
    "PA_PLName",
    "PA_PMedicaidNumber",

    -- === VISIT INFORMATION ===
    "VisitID",
    "AppVisitID",
    "VisitDate",
    "VisitStartTime",
    "VisitEndTime",
    "ShVTSTTime",
    "ShVTENTime",
    
    -- === SCHEDULED TIME INFORMATION ===
    "SchStartTime",
    "SchEndTime",
    "EVVStartTime",
    "EVVEndTime",
    
    -- === CONFLICT CLASSIFICATION ===
    CONTYPEOLD,
    "SameSchTimeFlag",
    "SameVisitTimeFlag",
    "SchAndVisitTimeSameFlag",
    "SchOverAnotherSchTimeFlag",
    "VisitTimeOverAnotherVisitTimeFlag",
    "SchTimeOverVisitTimeFlag",
    "DistanceFlag",
    "PTOFlag",
    "InServiceFlag",
    
    -- === BILLING INFORMATION ===
    "BilledRateMinute" * 60 AS "BilledRate",
    "BilledHours",
    "BilledDate",
    FULL_SHIFT_MIN / 60 AS "sch_hours",
    FULL_SHIFT_MIN AS "TotalMinutes",
    OVERLAP_MIN AS "OverlapTime",
    FULL_SHIFT_AMOUNT as "ShiftPrice",
    OVERLAP_AMOUNT as "OverlapPrice",
    FINAL_AMOUNT as "FinalPrice",
    
    -- === STATUS & CONTROL FIELDS ===
    "StatusFlag",
    "FlagForReview",
    RN,
    
    -- === AUDIT FIELDS ===
    "LastUpdatedBy",
    "LastUpdatedDate",
    "G_CRDATEUNIQUE" AS "CRDATEUNIQUE",
    "AgingDays"
    
FROM CONFLICTREPORT_SANDBOX.PUBLIC.TMP_AG_V_PAYER_CONFLICTS_COMMON
WHERE RN = 1
ORDER BY "GroupID" DESC;

