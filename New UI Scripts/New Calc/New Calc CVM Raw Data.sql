-- Set session variables for configurable payer ID
SET TARGET_PAYER_ID = '83828a9e-a1ad-4d29-bc4f-24be24db126f';  -- EverCare
-- SET TARGET_PAYER_ID = '042cb099-168b-4717-9bd0-936848b4fab1';  -- Able Homecare (uncomment to use)

SELECT
	-- Primary conflict identification
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
	-- Duplicate detection column
    CASE
			WHEN ROW_NUMBER() OVER (
            PARTITION BY 
			CASE
				WHEN V1."AppVisitID" <= V1."ConAppVisitID" THEN V1."AppVisitID" || '|' || V1."ConAppVisitID"
			ELSE V1."ConAppVisitID" || '|' || V1."AppVisitID"
		END
	ORDER BY 
                CASE 
                    WHEN V1."PayerID" = $TARGET_PAYER_ID THEN 1  -- Primary payer gets priority
                    WHEN V1."ConPayerID" = $TARGET_PAYER_ID THEN 2  -- Conflicting payer gets lower priority
                    ELSE 3  -- Other payers get lowest priority
                END,
                V1."CONFLICTID" DESC  -- Tie-breaker: higher CONFLICTID gets priority
        ) = 1 THEN ''
		ELSE 'DUPLICATE'
	END AS Duplicate_Status,
	-- Business logic fields
	V1."StatusFlag",
	-- Cost type determination
    CASE
		WHEN V1."Billed" = 'yes' THEN 'Recovery'
		ELSE 'Avoidance'
	END AS CALCULATED_COSTTYPE,
	-- Visit type determination
    CASE
		WHEN V1."VisitStartTime" IS NULL THEN 'Scheduled'
		WHEN V1."Billed" != 'yes' THEN 'Confirmed'
		WHEN V1."Billed" = 'yes' THEN 'Billed'
	END AS CALCULATED_VISITTYPE,
	-- New field to check if VisitStartTime is NULL or not
    CASE
		WHEN V1."VisitStartTime" IS NULL THEN 'NULL'
		ELSE 'NOT NULL'
	END AS VisitStartTime_Status,
	-- Conflict type determination (same logic as in the main query)
    CASE
		WHEN (V1."SameSchTimeFlag" = 'Y'
		OR V1."SameVisitTimeFlag" = 'Y'
		OR V1."SchAndVisitTimeSameFlag" = 'Y'
		OR V1."SchOverAnotherSchTimeFlag" = 'Y'
		OR V1."VisitTimeOverAnotherVisitTimeFlag" = 'Y'
		OR V1."SchTimeOverVisitTimeFlag" = 'Y')
		AND V1."DistanceFlag" = 'N'
		AND V1."InServiceFlag" = 'N' THEN 'only_to'
		WHEN (V1."SameSchTimeFlag" = 'N'
		AND V1."SameVisitTimeFlag" = 'N'
		AND V1."SchAndVisitTimeSameFlag" = 'N'
		AND V1."SchOverAnotherSchTimeFlag" = 'N'
		AND V1."VisitTimeOverAnotherVisitTimeFlag" = 'N'
		AND V1."SchTimeOverVisitTimeFlag" = 'N')
		AND V1."DistanceFlag" = 'Y'
		AND V1."InServiceFlag" = 'N' THEN 'only_td'
		WHEN (V1."SameSchTimeFlag" = 'N'
		AND V1."SameVisitTimeFlag" = 'N'
		AND V1."SchAndVisitTimeSameFlag" = 'N'
		AND V1."SchOverAnotherSchTimeFlag" = 'N'
		AND V1."VisitTimeOverAnotherVisitTimeFlag" = 'N'
		AND V1."SchTimeOverVisitTimeFlag" = 'N')
		AND V1."DistanceFlag" = 'N'
		AND V1."InServiceFlag" = 'Y' THEN 'only_is'
		WHEN (V1."SameSchTimeFlag" = 'Y'
		OR V1."SameVisitTimeFlag" = 'Y'
		OR V1."SchAndVisitTimeSameFlag" = 'Y'
		OR V1."SchOverAnotherSchTimeFlag" = 'Y'
		OR V1."VisitTimeOverAnotherVisitTimeFlag" = 'Y'
		OR V1."SchTimeOverVisitTimeFlag" = 'Y')
		AND V1."DistanceFlag" = 'Y'
		AND V1."InServiceFlag" = 'N' THEN 'both_to_td'
		WHEN (V1."SameSchTimeFlag" = 'Y'
		OR V1."SameVisitTimeFlag" = 'Y'
		OR V1."SchAndVisitTimeSameFlag" = 'Y'
		OR V1."SchOverAnotherSchTimeFlag" = 'Y'
		OR V1."VisitTimeOverAnotherVisitTimeFlag" = 'Y'
		OR V1."SchTimeOverVisitTimeFlag" = 'Y')
		AND V1."DistanceFlag" = 'N'
		AND V1."InServiceFlag" = 'Y' THEN 'both_to_is'
		WHEN (V1."SameSchTimeFlag" = 'N'
		AND V1."SameVisitTimeFlag" = 'N'
		AND V1."SchAndVisitTimeSameFlag" = 'N'
		AND V1."SchOverAnotherSchTimeFlag" = 'N'
		AND V1."VisitTimeOverAnotherVisitTimeFlag" = 'N'
		AND V1."SchTimeOverVisitTimeFlag" = 'N')
		AND V1."DistanceFlag" = 'Y'
		AND V1."InServiceFlag" = 'Y' THEN 'both_td_is'
		WHEN (V1."SameSchTimeFlag" = 'Y'
		OR V1."SameVisitTimeFlag" = 'Y'
		OR V1."SchAndVisitTimeSameFlag" = 'Y'
		OR V1."SchOverAnotherSchTimeFlag" = 'Y'
		OR V1."VisitTimeOverAnotherVisitTimeFlag" = 'Y'
		OR V1."SchTimeOverVisitTimeFlag" = 'Y')
		AND V1."DistanceFlag" = 'Y'
		AND V1."InServiceFlag" = 'Y' THEN 'all_to_td_is'
		ELSE 'NULL'
	END AS CALCULATED_CONTYPE,
	-- Calculated fields for manual verification
    CASE
		WHEN (V1."SameSchTimeFlag" = 'Y'
		OR V1."SameVisitTimeFlag" = 'Y'
		OR V1."SchAndVisitTimeSameFlag" = 'Y'
		OR V1."SchOverAnotherSchTimeFlag" = 'Y'
		OR V1."VisitTimeOverAnotherVisitTimeFlag" = 'Y'
		OR V1."SchTimeOverVisitTimeFlag" = 'Y') THEN 'YES'
		ELSE 'NO'
	END AS HAS_TIME_OVERLAP,
		CASE
			WHEN V1."DistanceFlag" = 'Y' THEN 'YES'
		ELSE 'NO'
	END AS HAS_TIME_DISTANCE,
		CASE
			WHEN V1."InServiceFlag" = 'Y' THEN 'YES'
		ELSE 'NO'
	END AS HAS_IN_SERVICE,
	-- Priority field for debugging and verification
	CASE 
		WHEN V1."PayerID" = $TARGET_PAYER_ID THEN 1  -- Primary payer
		WHEN V1."ConPayerID" = $TARGET_PAYER_ID THEN 2  -- Conflicting payer
		ELSE 3  -- Other payers
	END AS Priority_Level,
	-- Row number for debugging deduplication logic
	ROW_NUMBER() OVER (
		PARTITION BY 
			CASE
				WHEN V1."AppVisitID" <= V1."ConAppVisitID" THEN V1."AppVisitID" || '|' || V1."ConAppVisitID"
				ELSE V1."ConAppVisitID" || '|' || V1."AppVisitID"
			END
		ORDER BY 
			CASE 
				WHEN V1."PayerID" = $TARGET_PAYER_ID THEN 1  -- Primary payer gets priority
				WHEN V1."ConPayerID" = $TARGET_PAYER_ID THEN 2  -- Conflicting payer gets lower priority
				ELSE 3  -- Other payers get lowest priority
			END,
			V1."CONFLICTID" DESC  -- Tie-breaker: higher CONFLICTID gets priority
	) AS Row_Number
FROM
		CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTVISITMAPS AS V1
INNER JOIN CONFLICTREPORT_SANDBOX.PUBLIC.CONFLICTS AS V2 
    ON
		V2."CONFLICTID" = V1."CONFLICTID"
WHERE
		(V1."PayerID" = $TARGET_PAYER_ID
		OR V1."ConPayerID" = $TARGET_PAYER_ID)
	-- Exclude PTO-only conflicts (same logic as in main query)
	AND NOT (V1."PTOFlag" = 'Y'
		AND V1."SameSchTimeFlag" = 'N'
		AND V1."SameVisitTimeFlag" = 'N'
		AND V1."SchAndVisitTimeSameFlag" = 'N'
		AND V1."SchOverAnotherSchTimeFlag" = 'N'
		AND V1."VisitTimeOverAnotherVisitTimeFlag" = 'N'
		AND V1."SchTimeOverVisitTimeFlag" = 'N'
		AND V1."DistanceFlag" = 'N'
		AND V1."InServiceFlag" = 'N')
ORDER BY
		V1.SSN,
		V1."GroupID",
		V1."CONFLICTID",
		V1."AppVisitID";