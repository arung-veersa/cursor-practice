-- Manual verification query built on reusable views

-- Set session variable for payer under test (optional for ad-hoc runs)
-- Example: EverCare
SET TARGET_PAYER_ID = '83828a9e-a1ad-4d29-bc4f-24be24db126f';
-- SET TARGET_PAYER_ID = '042cb099-168b-4717-9bd0-936848b4fab1';

-- Match v02 semantics: include duplicates (flagged) and filter by CONTYPE
SELECT
    ID,
    "Contract" AS Payer,
    "ConContract" AS ConPayer,
    "ProviderName",
    "SSN",
    "CRDATEUNIQUE" AS "Date",
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
    "Duplicate_Status" AS Duplicate_Status,
    "StatusFlag",
    COSTTYPE AS CALCULATED_COSTTYPE,
    VISITTYPE AS CALCULATED_VISITTYPE,
    "VisitStartTime_Status" AS VisitStartTime_Status,
    CONTYPE,
    CASE WHEN HAS_TIME_OVERLAP = 1 THEN 'YES' ELSE 'NO' END AS HAS_TIME_OVERLAP,
    CASE WHEN HAS_TIME_DISTANCE = 1 THEN 'YES' ELSE 'NO' END AS HAS_TIME_DISTANCE,
    CASE WHEN HAS_IN_SERVICE = 1 THEN 'YES' ELSE 'NO' END AS HAS_IN_SERVICE,
    "Row_Number" AS Row_Number,
    PROCESSING_PAYERID
FROM CONFLICTREPORT_SANDBOX.PUBLIC.VIEW_PAYER_CONFLICT_BASE
WHERE PROCESSING_PAYERID = $TARGET_PAYER_ID
  AND CONTYPE IS NOT NULL
ORDER BY
    "SSN",
    "GroupID",
    "CONFLICTID",
    "AppVisitID";


