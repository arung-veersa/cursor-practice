-- Set session variables for configurable payer ID
SET TARGET_PAYER_ID = '83828a9e-a1ad-4d29-bc4f-24be24db126f';  -- EverCare
-- SET TARGET_PAYER_ID = '042cb099-168b-4717-9bd0-936848b4fab1';  -- Able Homecare

WITH COMMON_FIELDS AS (
    -- Common fields and joins
    SELECT 
        V1.ID,
        V1."Contract" AS "Payer",
        V1."ConContract" AS ConPayer,
        V1."ProviderName",
        V1."SSN",
        V1.CRDATEUNIQUE AS "Date",
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
        V1."ConPayerID"
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
    -- When PayerID is the target payer
    SELECT 
        *,
        V1."PayerID" AS PROCESSING_PAYERID,
        1 AS priority_level  -- Primary payer gets priority 1
    FROM COMMON_FIELDS V1
    WHERE V1."PayerID" IN (SELECT APID FROM PAYER_LIST)

    UNION ALL
    
    -- When ConPayerID is the target payer
    SELECT 
        *,
        V1."ConPayerID" AS PROCESSING_PAYERID,
        2 AS priority_level  -- Conflicting payer gets priority 2
    FROM COMMON_FIELDS V1
    WHERE V1."ConPayerID" IN (SELECT APID FROM PAYER_LIST)
      AND V1."ConPayerID" != V1."PayerID" -- Excluding self-conflicts because they are covered in above query
),
DEDUPLICATED_RECORDS AS (
    -- Apply ROW_NUMBER() across all records with priority
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
                priority_level,  -- Primary payer (1) gets priority over conflicting payer (2)
                "CONFLICTID" DESC  -- Tie-breaker: higher CONFLICTID gets priority, mostly for self-conflicts.
        ) as rn
    FROM PAYER_RECORDS
)
SELECT
    ID,
    "Payer",
    ConPayer,
    "ProviderName",
    SSN,
    "Date",
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
    CASE
        WHEN rn = 1 THEN ''
        ELSE 'DUPLICATE'
    END AS Duplicate_Status,
    "StatusFlag",
    CASE
        WHEN "Billed" = 'yes' THEN 'Recovery'
        ELSE 'Avoidance'
    END AS CALCULATED_COSTTYPE,
    CASE
        WHEN "VisitStartTime" IS NULL THEN 'Scheduled'
        WHEN "Billed" != 'yes' THEN 'Confirmed'
        WHEN "Billed" = 'yes' THEN 'Billed'
    END AS CALCULATED_VISITTYPE,
    CASE
        WHEN "VisitStartTime" IS NULL THEN 'NULL'
        ELSE 'NOT NULL'
    END AS VisitStartTime_Status,
	
	-- Conflict type determination
	CASE
		-- Time Overlap Only
		WHEN ("SameSchTimeFlag" = 'Y'
			OR "SameVisitTimeFlag" = 'Y'
			OR "SchAndVisitTimeSameFlag" = 'Y'
			OR "SchOverAnotherSchTimeFlag" = 'Y'
			OR "VisitTimeOverAnotherVisitTimeFlag" = 'Y'
			OR "SchTimeOverVisitTimeFlag" = 'Y')
			AND "DistanceFlag" = 'N'
			AND "InServiceFlag" = 'N' 
		THEN 'only_to'
		
		-- Time Distance Only
		WHEN ("SameSchTimeFlag" = 'N'
			AND "SameVisitTimeFlag" = 'N'
			AND "SchAndVisitTimeSameFlag" = 'N'
			AND "SchOverAnotherSchTimeFlag" = 'N'
			AND "VisitTimeOverAnotherVisitTimeFlag" = 'N'
			AND "SchTimeOverVisitTimeFlag" = 'N')
			AND "DistanceFlag" = 'Y'
			AND "InServiceFlag" = 'N' 
		THEN 'only_td'
		
		-- In Service Only
		WHEN ("SameSchTimeFlag" = 'N'
			AND "SameVisitTimeFlag" = 'N'
			AND "SchAndVisitTimeSameFlag" = 'N'
			AND "SchOverAnotherSchTimeFlag" = 'N'
			AND "VisitTimeOverAnotherVisitTimeFlag" = 'N'
			AND "SchTimeOverVisitTimeFlag" = 'N')
			AND "DistanceFlag" = 'N'
			AND "InServiceFlag" = 'Y' 
		THEN 'only_is'
		
		-- Time Overlap + Time Distance
		WHEN ("SameSchTimeFlag" = 'Y'
			OR "SameVisitTimeFlag" = 'Y'
			OR "SchAndVisitTimeSameFlag" = 'Y'
			OR "SchOverAnotherSchTimeFlag" = 'Y'
			OR "VisitTimeOverAnotherVisitTimeFlag" = 'Y'
			OR "SchTimeOverVisitTimeFlag" = 'Y')
			AND "DistanceFlag" = 'Y'
			AND "InServiceFlag" = 'N' 
		THEN 'both_to_td'
		
		-- Time Overlap + In Service
		WHEN ("SameSchTimeFlag" = 'Y'
			OR "SameVisitTimeFlag" = 'Y'
			OR "SchAndVisitTimeSameFlag" = 'Y'
			OR "SchOverAnotherSchTimeFlag" = 'Y'
			OR "VisitTimeOverAnotherVisitTimeFlag" = 'Y'
			OR "SchTimeOverVisitTimeFlag" = 'Y')
			AND "DistanceFlag" = 'N'
			AND "InServiceFlag" = 'Y' 
		THEN 'both_to_is'
		
		-- Time Distance + In Service
		WHEN ("SameSchTimeFlag" = 'N'
			AND "SameVisitTimeFlag" = 'N'
			AND "SchAndVisitTimeSameFlag" = 'N'
			AND "SchOverAnotherSchTimeFlag" = 'N'
			AND "VisitTimeOverAnotherVisitTimeFlag" = 'N'
			AND "SchTimeOverVisitTimeFlag" = 'N')
			AND "DistanceFlag" = 'Y'
			AND "InServiceFlag" = 'Y' 
		THEN 'both_td_is'
		
		-- All Three: Time Overlap + Time Distance + In Service
		WHEN ("SameSchTimeFlag" = 'Y'
			OR "SameVisitTimeFlag" = 'Y'
			OR "SchAndVisitTimeSameFlag" = 'Y'
			OR "SchOverAnotherSchTimeFlag" = 'Y'
			OR "VisitTimeOverAnotherVisitTimeFlag" = 'Y'
			OR "SchTimeOverVisitTimeFlag" = 'Y')
			AND "DistanceFlag" = 'Y'
			AND "InServiceFlag" = 'Y' 
		THEN 'all_to_td_is'
		
		ELSE NULL
	END AS CONTYPE,
    
	-- Calculated fields for manual verification
    CASE
        WHEN ("SameSchTimeFlag" = 'Y'
        OR "SameVisitTimeFlag" = 'Y'
        OR "SchAndVisitTimeSameFlag" = 'Y'
        OR "SchOverAnotherSchTimeFlag" = 'Y'
        OR "VisitTimeOverAnotherVisitTimeFlag" = 'Y'
        OR "SchTimeOverVisitTimeFlag" = 'Y') THEN 'YES'
        ELSE 'NO'
    END AS HAS_TIME_OVERLAP,
    CASE
        WHEN "DistanceFlag" = 'Y' THEN 'YES'
        ELSE 'NO'
    END AS HAS_TIME_DISTANCE,
    CASE
        WHEN "InServiceFlag" = 'Y' THEN 'YES'
        ELSE 'NO'
    END AS HAS_IN_SERVICE,
    rn AS Row_Number,
    PROCESSING_PAYERID
FROM DEDUPLICATED_RECORDS
WHERE PROCESSING_PAYERID = $TARGET_PAYER_ID
  AND CONTYPE IS NOT NULL
ORDER BY
    SSN,
    "GroupID",
    "CONFLICTID",
    "AppVisitID";